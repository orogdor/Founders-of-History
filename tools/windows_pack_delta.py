"""Build a Windows launcher transfer from the files already in an older PCK."""

import argparse
from contextlib import ExitStack
from mmap import ACCESS_READ, mmap
from pathlib import Path
from struct import Struct

PCK_HEADER = Struct("<4s5I2Q")
PCK_ENTRY = Struct("<QQ16sI")
INTEGER = Struct("<I")
DELTA_HEADER = Struct("<4sIII")
RUN = Struct("<II")
LITERAL = 0xFFFFFFFF
MAX_SIZE = 1_610_612_736
CHUNK = 1024 * 1024
MATCH_BLOCK = 16 * 1024


def resources(pack):
    magic, version, _, _, _, flags, base, directory = PCK_HEADER.unpack_from(pack)
    if magic != b"GDPC" or version not in (3, 4) or flags & ~2:
        raise ValueError("Expected an unencrypted standalone Godot 4 PCK")
    if not PCK_HEADER.size <= base <= directory <= len(pack) - INTEGER.size:
        raise ValueError("Invalid PCK directory offset")
    count, = INTEGER.unpack_from(pack, directory)
    cursor = directory + INTEGER.size
    for _ in range(count):
        name_size, = INTEGER.unpack_from(pack, cursor)
        cursor += INTEGER.size
        name = pack[cursor:cursor + name_size].rstrip(b"\0")
        cursor += name_size
        offset, size, digest, flags = PCK_ENTRY.unpack_from(pack, cursor)
        cursor += PCK_ENTRY.size
        if flags != 0 or not size:
            continue  # Tombstones and encoded resources stay in the literal data.
        start = base + offset
        if not base <= start <= start + size <= directory:
            raise ValueError("PCK resource outside data area")
        yield start, size, digest, name


def same_bytes(old, old_offset, new, new_offset, size):
    for step in range(0, size, CHUNK):
        size_now = min(CHUNK, size - step)
        if old[old_offset + step:old_offset + step + size_now] != new[new_offset + step:new_offset + step + size_now]:
            return False
    return True


def shared_prefix(left, right):
    low, high = 0, min(len(left), len(right))
    while low < high:
        middle = (low + high + 1) // 2
        if left[:middle] == right[:middle]:
            low = middle
        else:
            high = middle - 1
    return low


def reusable_ranges(old, new):
    originals = list(resources(old))
    copies = {(size, digest): offset for offset, size, digest, _ in originals}
    by_path = {name: (offset, size) for offset, size, _, name in originals}
    for start, size, digest, name in sorted(resources(new)):
        source = copies.get((size, digest))
        if source is not None and same_bytes(old, source, new, start, size):
            yield source, start, size
            continue
        if name not in by_path:
            continue
        source, old_size = by_path[name]
        overlap = min(old_size, size)
        # Reimported assets can change a few header bytes while their resource
        # data stays identical. Reuse the unchanged parts of those files too.
        for step in range(0, overlap, MATCH_BLOCK):
            length = min(MATCH_BLOCK, overlap - step)
            left = old[source + step:source + step + length]
            right = new[start + step:start + step + length]
            if left == right:
                yield source + step, start + step, length
                continue
            prefix = shared_prefix(left, right)
            suffix = shared_prefix(left[prefix:][::-1], right[prefix:][::-1])
            if prefix >= 64:
                yield source + step, start + step, prefix
            if suffix >= 64:
                tail = step + length - suffix
                yield source + tail, start + tail, suffix


def transfer_runs(old, new):
    runs = []

    def append(source, start, size):
        if not size:
            return
        if runs:
            last_source, last_start, last_size = runs[-1]
            if (source == last_source == LITERAL) or (
                source != LITERAL and last_source != LITERAL and last_source + last_size == source
            ):
                runs[-1] = (last_source, last_start, last_size + size)
                return
        runs.append((source, start, size))

    cursor = 0
    for source, start, size in reusable_ranges(old, new):
        if start < cursor:
            continue
        append(LITERAL, cursor, start - cursor)
        append(source, start, size)
        cursor = start + size
    append(LITERAL, cursor, len(new) - cursor)
    return runs


def build_delta(old_path, new_path, destination):
    with ExitStack() as stack:
        old_file = stack.enter_context(old_path.open("rb"))
        new_file = stack.enter_context(new_path.open("rb"))
        if any(not PCK_HEADER.size <= path.stat().st_size <= MAX_SIZE for path in (old_path, new_path)):
            raise ValueError("Unsupported Windows PCK size")
        old = stack.enter_context(mmap(old_file.fileno(), 0, access=ACCESS_READ))
        new = stack.enter_context(mmap(new_file.fileno(), 0, access=ACCESS_READ))
        runs = transfer_runs(old, new)
        size = DELTA_HEADER.size + len(runs) * RUN.size + sum(length for source, _, length in runs if source == LITERAL)
        if size >= len(new) * 0.875:
            print(f"Skip delta: {size:,} of {len(new):,} bytes")
            return
        with destination.open("xb") as delta:
            delta.write(DELTA_HEADER.pack(b"FHD1", len(old), len(new), len(runs)))
            for source, start, length in runs:
                delta.write(RUN.pack(source, length))
                if source == LITERAL:
                    for step in range(start, start + length, CHUNK):
                        delta.write(new[step:min(step + CHUNK, start + length)])
        print(f"{size:,} of {len(new):,} bytes ({size / len(new):.2%})")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("previous_pack", type=Path)
    parser.add_argument("target_pack", type=Path)
    parser.add_argument("transfer", type=Path)
    args = parser.parse_args()
    build_delta(args.previous_pack, args.target_pack, args.transfer)

