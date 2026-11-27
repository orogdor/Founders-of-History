from copy import deepcopy
import json
from pathlib import Path

DATA = Path(__file__).resolve().parents[1] / "data"

def read(name):
    return json.loads((DATA / f"{name}.json").read_text(encoding="utf-8-sig"))

def write(name, value):
    (DATA / f"{name}.json").write_text(json.dumps(value, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")

# Types introduced after the Iron Age start from the closest editable plan.
REFERENCES = {
    "dairy": "farm@2", "spice_garden": "vegetable_garden", "coffee_farm": "orchard",
    "silk_farm": "flax_farm", "dye_garden": "vegetable_garden", "cocoa_farm": "orchard",
    "rubber_farm": "orchard", "silk_weaver": "weaver", "perfumery": "pottery_kiln",
    "chocolatier": "bakery", "electronics_factory": "cartwright",
    "school": "study", "public_school": "library", "high_school": "academy",
    "university": "academy", "printer": "scriptorium", "observatory": "stonetower@2",
    "nitrate": "mine", "powdermill": "watermill", "steelworks": "smelter",
    "engineworks": "smith", "polytechnic": "academy", "railstation": "road_depot",
    "oilwell": "mine", "refinery": "smelter", "powerplant": "smelter",
    "autofactory": "cartwright", "laboratory": "academy", "airfield": "warehouse",
    "armor_workshop": "smith", "crossbow_range": "archery@2", "guildhall": "hall@2",
    "master_workshop": "smith", "windmill": "mill", "infirmary": "house@2",
    "trade_yard": "market", "inn": "house@2", "monastery": "hall@2",
    "chapel": "hall@2", "keep": "stonetower@2",
}
# Existing role-specific objects remain editable in the catalogue. New
# workshops and institutions also receive distinct equipment and layouts.
EQUIPMENT = {
    "dairy": ["trough", "manger", "barrel"], "perfumery": ["workbench", "jar", "shelf"],
    "chocolatier": ["oven", "workbench", "barrel"], "electronics_factory": ["workbench", "workbench", "crate", "shelf"],
    "school": ["desk", "bench", "bookshelf"], "public_school": ["desk", "desk", "bench", "bookshelf"],
    "high_school": ["desk", "desk", "bookshelf", "shelf"], "university": ["desk", "bookshelf", "bookshelf", "scrolls"],
    "printer": ["workbench", "desk", "shelf", "scrolls"], "observatory": ["desk", "scrolls", "bookshelf"],
    "steelworks": ["furnace", "anvil", "ingots", "coalPile"], "engineworks": ["workbench", "anvil", "wheelParts", "ingots"],
    "polytechnic": ["desk", "workbench", "bookshelf", "wheelParts"], "railstation": ["bench", "bench", "crate", "signpost"],
    "refinery": ["furnace", "barrel", "barrel", "crate"], "powerplant": ["furnace", "wheelParts", "coalPile", "workbench"],
    "autofactory": ["workbench", "workbench", "wheelParts", "ingots"], "laboratory": ["desk", "workbench", "jar", "shelf"],
    "airfield": ["workbench", "crate", "wheelParts", "barrel"],
    "armor_workshop": ["anvil", "forge", "workbench", "shelf"], "infirmary": ["bed", "bed", "shelf", "jar"],
    "inn": ["table", "bench", "bed", "barrel"], "chapel": ["bench", "bench", "table"],
}

FIXTURES = {
    "hearthStove": ["Malmahi", 54, 54, "▣"],
    "millSails": ["Veski tiivik", 82, 64, "+"],
    "factoryChimney": ["Telliskorsten", 69, 69, "▮"],
    "storageTank": ["Mahuti", 146, 146, "○"],
    "oilDerrick": ["Puurimistorn", 150, 150, "△"],
    "observatoryDome": ["Tähetorni kuppel", 146, 146, "◠"],
}

def add_fixtures(plan, kind):
    for floor in [plan, plan.get("upper")]:
        if not isinstance(floor, dict):
            continue
        for item in floor.get("items", []):
            if item["type"] == "fire":
                item["type"] = "hearthStove"
    if kind == "windmill":
        plan["items"].append({"type":"millSails","point":point(358,339)})
    if kind in {"steelworks", "powdermill", "engineworks", "refinery", "powerplant", "autofactory"}:
        plan["items"].append({"type":"factoryChimney","point":point(679,188)})
    if kind in {"refinery", "powerplant"}:
        plan["items"].append({"type":"storageTank","point":point(787,344)})
    if kind == "oilwell":
        plan["items"] = [{"type":"oilDerrick","point":point(385,237)},
                         {"type":"storageTank","point":point(654,300)},
                         {"type":"barrel","point":point(585,432)}]
    if kind == "observatory":
        plan.update(build="wall", roofForm="flat", columns="post", base="plinth")
        plan["items"] = [{"type":"observatoryDome","point":point(480,300)},
                         {"type":"desk","point":point(380,280)},
                         {"type":"bookshelf","point":point(611,192)}]

def point(x, y):
    return {"x": x, "y": y}

def room(left, top, right, bottom):
    return {"type": "rect", "a": point(left, top), "b": point(right, bottom)}

def opening(kind, x, y, style):
    return {"type": kind, "group": "outer", "point": point(x, y), "style": style}

def point_list(*coordinates):
    return [point(x, y) for x, y in coordinates]

def tailor(plan, kind, age):
    if plan["openSite"] or not plan["rooms"]:
        return
    if plan.get("pier") or kind in {"fisher", "harbor", "gatehouse", "woodgate"}:
        return
    if plan["build"] == "tower":
        plan.update(wallStyle="cutstone", wallScale=112 + age * 3)
        return
    profile = {
        3: ("halftimber", "shingle", "gable", 105, 110),
        4: ("plaster", "tile", "hip", 108, 95),
        5: ("brick", "tile", "gable", 116, 92),
        6: ("plaster", "tile", "hip", 114, 80),
    }
    wall, roof, shape, wall_height, roof_height = profile[age]
    plan.update(wallStyle=wall, roofMat=roof, roofForm=shape,
                wallScale=wall_height, roofHeight=roof_height, wallFinishes=[])
    if kind == "house" and age >= 5:
        plan.update(wallStyle="plaster", roofMat="shingle")
    if isinstance(plan.get("upper"), dict):
        plan["upper"].update(wallStyle=plan["wallStyle"], roofMat=plan["roofMat"], roofForm=shape,
                             wallScale=wall_height, roofHeight=roof_height, wallFinishes=[])
    if kind not in EQUIPMENT:
        return
    industrial = kind in {"steelworks", "engineworks", "refinery", "powerplant", "autofactory", "electronics_factory", "airfield"}
    public = kind in {"public_school", "high_school", "university", "polytechnic", "infirmary", "inn"}
    left, right = (203, 757) if industrial or kind == "railstation" else (246, 714)
    top, bottom = (192, 372) if kind == "railstation" else (151, 440) if industrial else (133, 449)
    plan.update(rooms=[room(left, top, right, bottom)], inner=[], wallRuns=[],
                yard=point_list((left-57,top-50),(right+57,top-50),(right+57,bottom+53),(left-57,bottom+53)),
                fences=[], columns="post", base="plinth", porch="none")
    plan.pop("upper", None)
    plan.pop("courtyardStyle", None)
    plan["openings"] = [
        opening("door", 480, bottom, "double" if industrial or public else "plank"),
        opening("window", left+98, bottom, "shutter"),
        opening("window", right-98, bottom, "shutter"),
        opening("window", 480, top, "shutter"),
    ]
    if public:
        # Add a side wing and an inside door rather than using a single box.
        plan["rooms"].append(room(left-88,top,left,top+166))
        plan["yard"][0]["x"] = plan["yard"][3]["x"] = left-114
        plan["inner"] = [{"a":point(left,top),"b":point(left,top+166)}]
        plan["openings"].append({"type":"door","group":"inner","point":point(left,top+91),"style":"plank"})
    if industrial:
        plan.update(wallStyle="brick", roofMat="shingle" if age == 3 else "tile", roofForm="gable", roofHeight=75)
        plan["openings"].append(opening("door", right, 294, "double"))
    if kind == "railstation":
        plan.update(wallStyle="cutstone", roofMat="shingle", roofForm="hip", roofHeight=64)
        plan["openings"][0]["style"] = "double"
    if kind == "chapel":
        plan.update(wallStyle="cutstone", roofForm="gable", roofHeight=138)
    positions = [(left+80,top+80),(right-80,top+80),(left+88,bottom-82),(right-88,bottom-82)]
    plan["items"] = [{"type":item,"point":point(*pos)} for item,pos in zip(EQUIPMENT[kind],positions)]

def adapt_windows(plan, age):
    if age < 5 or plan.get("build") in {"tower", "open"}:
        return
    style = "factoryWindow" if age == 5 else "glazed"
    for floor in [plan, plan.get("upper")]:
        if not isinstance(floor, dict):
            continue
        for opening in floor.get("openings", []):
            if opening["type"] == "window" and opening.get("style") in {"shutter", "lattice"}:
                opening["style"] = style

def main():
    designs = read("house_default_designs")
    catalog = read("house_editor_catalog")
    fits = read("building_fits")
    for fixture, definition in FIXTURES.items():
        catalog["items"][fixture] = definition
        catalog["itemSizes"][fixture] = definition[1:3]
    window_styles = {item[0]: item for item in catalog["WINDOW_STYLES"]}
    for style in [["factoryWindow","Ruudustikaken",5],["glazed","Lai klaasaken",6]]:
        if style[0] not in window_styles:
            catalog["WINDOW_STYLES"].append(style)
    rules = read("build_rules")["age"]
    types = read("economy")["buildings"]
    for age, (key, label) in enumerate(
        [("medieval","Keskaeg"),("renaissance","Renessanss"),("industrial","Tööstusajastu"),("modern","Moodne ajastu")], 3
    ):
        if len(catalog["ERAS"]) == age:
            catalog["ERAS"].append({"id":key,"name":label,"limit":12.3})
            catalog["ERA_WALLS"].append(catalog["ERA_WALLS"][2].copy())
        for kind in types:
            if kind == "bridge" or int(rules.get(kind, 0)) > age:
                continue
            key = f"{kind}@{age}"
            source = next((x for x in (kind+"@2",kind+"@1",kind,REFERENCES.get(kind)) if x in designs), None)
            if source is None:
                raise ValueError(f"No editable reference for {kind}")
            plan = deepcopy(designs[source])
            plan["id"] = key
            tailor(plan, kind, age)
            add_fixtures(plan, kind)
            adapt_windows(plan, age)
            designs[key] = plan
            definition = catalog["catalog"][source]
            catalog["catalog"][key] = {k:definition[k] for k in ("kind","coast") if k in definition}
            catalog["catalog"][key].update(base=kind, name=types[kind]["name"], era=age)
            catalog["choices"][key] = list(dict.fromkeys(
                catalog["choices"].get(source, []) + [item["type"] for item in plan["items"]]
            ))
            fits[key] = deepcopy(fits.get(source, {"scale":[1,1,1],"offset":[0,0,0]}))
    write("house_default_designs", designs)
    write("house_editor_catalog", catalog)
    write("building_fits", fits)

if __name__ == "__main__":
    main()

