"""Register editable art props and missing Bronze/Iron variants."""
from copy import deepcopy
import json
from pathlib import Path

DATA = Path(__file__).resolve().parents[1] / "data"
PROPS = {
    "householdJar": ["Säilitusnõu", 47, 47, "◉"],
    "saddleQuern": ["Jahvekivi", 55, 40, "◑"],
    "aegeanAmphoraRack": ["Amforariiul", 118, 50, "▤"],
    "romanTaberna": ["Rooma poelett", 126, 55, "▰"],
    "norseHearth": ["Pikamaja kolle", 132, 60, "♨"],
    "norseSleepingBench": ["Pikamaja lavats", 111, 58, "▰"],
    "norseLoom": ["Püstkangasteljed", 100, 55, "▥"],
    "navalBales": ["Sadamakaup", 150, 77, "▤"],
    "factoryLathe": ["Vabriku treipink", 126, 52, "▩"],
    "factorySwitchboard": ["Vabriku näidikupaneel", 76, 33, "▦"],
    "factoryDrive": ["Vabriku ülekanderihm", 61, 66, "▥"],
    "labStation": ["Labori töölaud", 133, 61, "▥"],
    "labCabinet": ["Labori hoiukapp", 103, 44, "▦"],
    "substation": ["Alajaama trafod", 154, 112, "▦"],
    "processVessels": ["Mahutid ja torn", 150, 122, "▤"],
    "siteShelter": ["Karjääri varjualune", 125, 102, "△"],
    "wheelLoader": ["Kopplaadur", 105, 176, "▣"],
    "loadingPallet": ["Kaubaalus", 77, 71, "▣"],
    "airfieldPlane": ["Lennuk platsil", 243, 228, "✈"],

    "civicClock": ["Kellatorni kell", 74, 74, "◷"],
    "medievalBelfry": ["Puidust kellatorn", 124, 124, "♜"],
    "romanBasin": ["Aatriumi veesilm", 129, 112, "◇"],
    "romanColumn": ["Rooma sammas", 28, 28, "◉"],
    "workerChimney": ["Telliskorsten", 43, 44, "▮"],
    "dockCrane": ["Sadamakraana", 103, 53, "⌝"],
    "canvasShelter": ["Presentvarjualune", 110, 160, "△"],
    "modernPlanter": ["Betoonist taimekast", 119, 50, "▱"],
}
CATEGORIES = {
    "householdJar": (1, {"house"}),
    "saddleQuern": (1, {"house"}),
    "aegeanAmphoraRack": (1, {"pottery_kiln","market","warehouse","bronze_town"}),
    "romanTaberna": (2, {"market","bakery","pottery_kiln","inn"}),
    "norseHearth": (3, {"house","hall","barracks","farm","stable"}),
    "norseSleepingBench": (3, {"house","hall","barracks","farm","stable"}),
    "norseLoom": (3, {"house","hall","weaver","silk_weaver"}),
    "navalBales": (4, {"harbor","warehouse","trade_yard"}),
    "factoryLathe": (5, {"steelworks","engineworks","powerplant","master_workshop","refinery","autofactory","electronics_factory"}),
    "factorySwitchboard": (5, {"steelworks","engineworks","powerplant","master_workshop","refinery","autofactory","electronics_factory"}),
    "factoryDrive": (5, {"steelworks","engineworks","powerplant","master_workshop","refinery","autofactory","electronics_factory"}),
    "labStation": (6, {"laboratory","polytechnic","infirmary","public_school","high_school","research"}),
    "labCabinet": (6, {"laboratory","polytechnic","infirmary","public_school","high_school","research"}),
    "substation": (6, {"powerplant"}),
    "processVessels": (6, {"refinery"}),
    "siteShelter": (5, {"claypit","quarry","coppermine","tinmine","mine","gem_mine","coal","nitrate"}),
    "wheelLoader": (6, {"claypit","quarry","coppermine","tinmine","mine","gem_mine","coal","nitrate"}),
    "loadingPallet": (6, {"warehouse","autofactory","airfield","harbor","electronics_factory","refinery"}),
    "airfieldPlane": (6, {"airfield"}),

    "civicClock": (4, {"academy","guildhall","university","public_school","railstation"}),
    "medievalBelfry": (3, {"chapel","monastery"}),
    "romanBasin": (2, {"house","hall","academy","market","library"}),
    "romanColumn": (2, {"house","hall","academy","market","library"}),
    "workerChimney": (5, {"house","inn","warehouse","steelworks","engineworks"}),
    "dockCrane": (4, {"harbor","warehouse","fisher","trade_yard"}),
    "canvasShelter": (5, {"barracks","archery","crossbow_range","road_depot"}),
    "modernPlanter": (6, {"house","inn","hall","market","public_school","laboratory"}),
}

def load(name):
    return json.loads((DATA/f"{name}.json").read_text(encoding="utf-8-sig"))

def write(name,data):
    (DATA/f"{name}.json").write_text(json.dumps(data,ensure_ascii=False,separators=(",",":")),encoding="utf-8")

def main():
    plans=load("house_default_designs")
    catalog=load("house_editor_catalog")
    fits=load("building_fits")
    required=load("build_rules")["age"]
    types=load("economy")["buildings"]
    for age in (1,2):
        for kind in types:
            target=f"{kind}@{age}"
            if kind=="bridge" or target in plans or int(required.get(kind,0))>age:
                continue
            first_age=int(catalog["catalog"].get(kind,{}).get("era",0))
            if kind in plans and first_age==age:
                # This authored base name already belongs in the correct catalogue.
                continue
            sources=[f"{kind}@{n}" for n in range(age-1,0,-1)]+[kind]
            source=next((key for key in sources if key in plans),None)
            if source is None:
                raise ValueError(f"No source plan for {target}")
            plans[target]=deepcopy(plans[source])
            plans[target]["id"]=target
            entry=deepcopy(catalog["catalog"][source])
            entry.update(era=age,base=kind)
            catalog["catalog"][target]=entry
            catalog["choices"][target]=list(catalog["choices"].get(source,[]))
            if source in fits:
                fits[target]=deepcopy(fits[source])
    for name,value in PROPS.items():
        catalog["items"][name]=value
        catalog["itemSizes"][name]=value[1:3]
    if not any(entry[0]=="sash" for entry in catalog["WINDOW_STYLES"]):
        catalog["WINDOW_STYLES"].append(["sash","Tõstaken",4])
    catalog["WINDOW_STYLES"]=[entry for entry in catalog["WINDOW_STYLES"] if entry[0]!="pictureWindow"]
    catalog["WINDOW_STYLES"].append(["pictureWindow","Panoraamaken",6])
    if not any(entry[0]=="loadingDoor" for entry in catalog["DOOR_STYLES"]):
        catalog["DOOR_STYLES"].append(["loadingDoor","Tõstetav kaubauks",5])
    for key,entry in catalog["catalog"].items():
        age=int(entry.get("era",0))
        kind=key.split("@",1)[0]
        for prop,(prop_age,kinds) in CATEGORIES.items():
            if (age==prop_age or (prop=="civicClock" and age==5 and kind=="railstation")) and kind in kinds:
                options=catalog["choices"].setdefault(key,[])
                if prop not in options:
                    options.append(prop)
    bronze_recipes = load("bronze_building_plans")
    for key, definition in catalog["catalog"].items():
        kind = key.split("@", 1)[0]
        if definition.get("era") == 1 and kind in bronze_recipes:
            options = catalog["choices"].setdefault(key, [])
            for prop, _, _ in bronze_recipes[kind]["props"]:
                if prop not in options:
                    options.append(prop)
    write("house_default_designs",plans)
    write("house_editor_catalog",catalog)
    write("building_fits",fits)

if __name__=="__main__":
    main()

