"""Build enhanced textures in a disposable Godot checkout before importing.

Source files stay in Git. This step works on both loose images and glTF images,
preserving colour space, alpha, UVs and the channels of existing data textures.
"""
import argparse
import base64
import hashlib
import io
import json
import os
from concurrent.futures import ProcessPoolExecutor
from pathlib import Path
import re
import struct
from urllib.parse import unquote

import numpy as np
from PIL import Image, ImageFilter

ASSETS = Path("assets")
GENERATED = ASSETS / "surface_detail"
RASTER = {".png", ".jpg", ".jpeg", ".webp"}
POST_IMPORT = 'import_script/path="res://tools/surface_detail_import.gd"'
DATA = re.compile(r"(?:^|[-_])(normal|rough|roughness|orm|height|ao|metallic|mask|occlusion|bump|alpha|specular|displacement)(?:[-_.]|$)", re.I)


def parse_glb(path):
    with path.open("rb") as stream:
        magic, version, _ = struct.unpack("<4sII", stream.read(12))
        if magic != b"glTF" or version != 2:
            raise ValueError(f"Unsupported GLB: {path}")
        chunks = []
        while header := stream.read(8):
            length, kind = struct.unpack("<I4s", header)
            chunks.append((kind, stream.read(length)))
    return json.loads(chunks[0][1]), chunks[1:]


def write_glb(path, header, chunks):
    data = json.dumps(header, separators=(",", ":")).encode()
    data += b" " * (-len(data) % 4)
    chunks = [(b"JSON", data), *chunks]
    with path.open("wb") as stream:
        stream.write(struct.pack("<4sII", b"glTF", 2, 12 + sum(8 + len(data) for _, data in chunks)))
        for kind, data in chunks:
            stream.write(struct.pack("<I4s", len(data), kind))
            stream.write(data)


def image_roles(header):
    roles = {}

    def record(info, role):
        if not info or "index" not in info:
            return
        texture = header["textures"][info["index"]]
        if "source" in texture:
            roles.setdefault(texture["source"], set()).add(role)

    for material in header.get("materials", []):
        pbr = material.get("pbrMetallicRoughness", {})
        record(pbr.get("baseColorTexture"), "unlit" if "KHR_materials_unlit" in material.get("extensions", {}) else "surface")
        record(pbr.get("metallicRoughnessTexture"), "data")
        record(material.get("normalTexture"), "normal")
        record(material.get("occlusionTexture"), "data")
        record(material.get("emissiveTexture"), "unlit")
    return roles


def relative_image(path, image):
    uri = image.get("uri", "")
    if uri and not uri.startswith("data:"):
        return Path(os.path.normpath(path.parent / unquote(uri)))
    return None


def source_bytes(image, header, binary):
    if "bufferView" in image:
        view = header["bufferViews"][image["bufferView"]]
        start = view.get("byteOffset", 0)
        return binary[start:start + view["byteLength"]]
    return base64.b64decode(image["uri"].split(",", 1)[1])


def resolution(size, role, profile):
    width, height = size
    cap = 8192 if profile == "desktop" else (4096 if role == "ui" else 1024)
    # Keep the original dimensions when a source already exceeds the budget.
    factor = max(1.0, min(2.0, cap / max(size)))
    return round(width * factor), round(height * factor)


def enhance(image, role, profile, seed):
    size = resolution(image.size, role, profile)
    alpha = image.convert("RGBA").getchannel("A") if "A" in image.getbands() or "transparency" in image.info else None
    if role in {"data", "normal"}:
        # Avoid inventing values in packed channels or sharpening encoded normals.
        return image.convert("RGBA" if alpha is not None else "RGB").resize(size, Image.Resampling.BILINEAR), None
    color = image.convert("RGB").resize(size, Image.Resampling.LANCZOS)
    color = color.filter(ImageFilter.UnsharpMask(radius=1.0, percent=65, threshold=3))
    height_map = None
    if role == "surface":
        luma = color.convert("L")
        medium = np.asarray(luma.filter(ImageFilter.GaussianBlur(2.3)), dtype=np.float32)
        broad = np.asarray(luma.filter(ImageFilter.GaussianBlur(10)), dtype=np.float32)
        luminance = np.asarray(luma, dtype=np.float32)
        rng = np.random.default_rng(seed)
        # Correlate detail with existing edges. Broad colour changes contribute
        # very little to relief so painted shadows do not turn into deep grooves.
        grain = rng.integers(0, 256, (size[1], size[0]), dtype=np.uint8)
        noise = np.asarray(Image.fromarray(grain).filter(ImageFilter.GaussianBlur(0.7)), dtype=np.float32) - 127.5
        fine = luminance - medium
        mid = medium - broad
        relief = 128 + 1.1 * fine + 0.44 * mid + noise * 0.32
        height_map = Image.fromarray(np.clip(relief, 24, 232).astype(np.uint8))
        detail = np.clip(0.20 * fine + 0.11 * mid + 0.10 * noise, -14, 14)
        rgb = np.asarray(color, dtype=np.float32)
        color = Image.fromarray(np.clip(rgb + detail[:, :, None], 0, 255).astype(np.uint8))
    if alpha is not None:
        color.putalpha(alpha.resize(size, Image.Resampling.LANCZOS))
    return color, height_map


def make_normal(height):
    values = np.asarray(height, dtype=np.float32) / 255.0
    if min(values.shape) < 2:
        return Image.new("RGB", height.size, (128, 128, 255))
    dy, dx = np.gradient(values)
    inv = 1.0 / np.sqrt(1.0 + (dx * dx + dy * dy) * 6.25)
    normal = np.stack((-dx * 2.5 * inv, dy * 2.5 * inv, inv), axis=-1)
    return Image.fromarray(np.rint((normal + 1.0) * 127.5).astype(np.uint8))


def save_image(image, path, role):
    if path.suffix == ".webp":
        image.save(path, lossless=role in {"data", "normal"}, quality=89, method=1)
    elif path.suffix in {".jpg", ".jpeg"}:
        image.convert("RGB").save(path, quality=93, subsampling=0)
    else:
        image.save(path, compress_level=1)


def texture_import(path, role, profile):
    # Rendered surfaces use GPU block compression; HUD images retain crisp alpha.
    mode = 0 if role == "data" else 1 if role == "ui" else 2
    if profile == "desktop" and role in {"surface", "unlit"}:
        mode = 4
    params = {
        "compress/mode": mode,
        "compress/lossy_quality": 0.92,
        "compress/normal_map": 1 if role == "normal" else 0,
        "mipmaps/generate": "true",
        "detect_3d/compress_to": 0,
    }
    sidecar = Path(f"{path}.import")
    existing = sidecar.read_text() if sidecar.exists() else ""
    spec = existing.split("[params]", 1)
    metadata = spec[0] if len(spec) == 2 else (
        '[remap]\n\nimporter="texture"\ntype="CompressedTexture2D"\n\n'
    )
    config = spec[1].strip().splitlines() if len(spec) == 2 else []
    keys = set(params)
    lines = [line for line in config if line.split("=", 1)[0] not in keys]
    lines.extend(f"{key}={value}" for key, value in params.items())
    sidecar.write_text(metadata + "[params]\n\n" + "\n".join(lines) + "\n")


def role_for_file(path, roles):
    if roles & {"normal", "data"}:
        return "normal" if roles == {"normal"} else "data"
    match = DATA.search(path.stem)
    if match:
        return "normal" if match[1].lower() == "normal" else "data"
    if "surface" in roles or path.parts[1] == "ground":
        return "surface"
    if path.parts[1] == "house_designer" and path.stem.startswith(("proc-", "land-", "atlas-", "bronze-thatch", "forge-")):
        return "surface"
    return "ui"


def build_texture(task):
    original, source, output, role, key, profile, needs_normal = task
    image = Image.open(io.BytesIO(source)) if source is not None else Image.open(original)
    color, height = enhance(image, role, profile, int(key[:8], 16))
    output.parent.mkdir(parents=True, exist_ok=True)
    save_image(color, output, role)
    texture_import(output, role, profile)
    if height is not None and needs_normal is not None:
        # JPEG/WebP colour compression must not change the displacement data.
        displacement = height.copy()
        displacement.thumbnail((1024, 1024) if profile == "desktop" else (512, 512), Image.Resampling.LANCZOS)
        save_image(displacement, GENERATED / f"{key}-height.png", "data")
        texture_import(GENERATED / f"{key}-height.png", "data", profile)
        if needs_normal:
            height.thumbnail((1536, 1536) if profile == "desktop" else (768, 768), Image.Resampling.LANCZOS)
            save_image(make_normal(height), GENERATED / f"{key}-normal.png", "normal")
            texture_import(GENERATED / f"{key}-normal.png", "normal", profile)
    return color.size != image.size, height is not None and needs_normal is not None


def build(profile, jobs):
    if GENERATED.exists():
        raise SystemExit(f"{GENERATED} already exists. Run in a clean disposable checkout.")
    GENERATED.mkdir()
    models = sorted(ASSETS.rglob("*.glb"))
    file_roles = {}
    missing_normals = set()
    embedded = {}
    relief = {}
    for path in models:
        header, chunks = parse_glb(path)
        images = header.get("images", [])
        if not images:
            continue
        roles = image_roles(header)
        for material in header.get("materials", []):
            info = material.get("pbrMetallicRoughness", {}).get("baseColorTexture")
            if info and not material.get("normalTexture"):
                source = header["textures"][info["index"]].get("source")
                if source is not None and "surface" in roles.get(source, set()):
                    external = relative_image(path, images[source])
                    if external:
                        missing_normals.add(external)
        generated_for_model = {}
        for index, image in enumerate(images):
            tags = roles.get(index, set())
            external = relative_image(path, image)
            if external:
                file_roles.setdefault(external, set()).update(tags)
                continue
            data = source_bytes(image, header, chunks[0][1] if chunks else b"")
            role = "data" if tags & {"normal", "data"} else ("surface" if "surface" in tags else "unlit")
            if tags == {"normal"}:
                role = "normal"
            key = hashlib.sha256(role.encode() + data).hexdigest()[:20]
            output = GENERATED / f"{key}.webp"
            embedded.setdefault(key, (None, data, output, role, key, profile, True if role == "surface" else None))
            generated_for_model[index] = output
            if role == "surface":
                relief[str(output)] = key
        if generated_for_model:
            for index, output in generated_for_model.items():
                image = images[index]
                image.pop("bufferView", None)
                image.pop("mimeType", None)
                image["uri"] = os.path.relpath(output, path.parent).replace(os.sep, "/")
            write_glb(path, header, chunks)
        sidecar = Path(f"{path}.import")
        if sidecar.exists():
            sidecar.write_text(sidecar.read_text().replace('import_script/path=""', POST_IMPORT))
    # Godot extracted these copies from the same embedded images in older
    # imports. Our rewritten models use the shared improved image instead.
    references = "\n".join(
        path.read_text(errors="ignore")
        for folder in ("scripts", "data", "tests")
        for path in Path(folder).glob("*")
        if path.suffix in {".gd", ".tscn", ".json"}
    )
    duplicates = 0
    loose = []
    for path in sorted(ASSETS.rglob("*")):
        # These authored material sets already have matching color, normal and height maps.
        if path.is_relative_to(ASSETS / "house_designer" / "walls"):
            continue
        if path.suffix.lower() not in RASTER:
            continue
        sidecar = Path(f"{path}.import")
        if (path not in file_roles and path.name not in references and sidecar.exists()
                and "generator_parameters=" in sidecar.read_text()):
            path.unlink()
            sidecar.unlink()
            duplicates += 1
            continue
        roles = file_roles.get(path, set())
        role = role_for_file(path, roles)
        key = hashlib.sha256(path.as_posix().encode()).hexdigest()[:20]
        use_relief = role == "surface" and path.parts[1] != "ground"
        if use_relief:
            relief[str(path)] = key
        loose.append((path, None, path, role, key, profile, (path in missing_normals or not roles) if use_relief else None))
    with ProcessPoolExecutor(jobs) as pool:
        results = list(pool.map(build_texture, (*loose, *embedded.values()), chunksize=4))
    (GENERATED / "materials.json").write_text(json.dumps(relief, sort_keys=True))
    print(f"{profile}: {len(loose)} loose and {len(embedded)} unique embedded textures, "
          f"{sum(scaled for scaled, _ in results)} enlarged, "
          f"{sum(height for _, height in results)} height maps, {duplicates} redundant extracts removed", flush=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("profile", choices=["desktop", "mobile"])
    parser.add_argument("--jobs", type=int, default=min(4, os.cpu_count() or 1))
    args = parser.parse_args()
    build(args.profile, args.jobs)
