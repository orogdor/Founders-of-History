"""Genereerib data/human_outfits.json: esemed, 5 riietust ajastu ja soo kohta, 5 soengut, habemed, sõdurid.

Kasutus: python3 tools/outfits.py <projekt>   (seejärel tools/mpfb_bodies.py ... --clothes)
"""
import json, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import hair as HAIR

UNDYED="d9cdb1";BROWN="7a5a3a";MADDER="9c3b2e";WOAD="3f5a7a";WELD="c8a64a";LINEN="e8e1cf";LEATHER="6b4a2f";HIDE="8f6e4b";FUR="6e5640"
BLACK="2e2925";GREEN="4f5f3a";GREY="7d7a73";DENIM="3a4c66";KHAKI="8a8160";WHITE="f1efe8";NAVY="2c3448";OLIVE="5b5d3b";BRONZE="b08a4a";IRON="8e9196";STEEL="b9bcc2"
WOOL=[UNDYED,BROWN,MADDER,WOAD,WELD,GREEN,GREY]
I={}
def item(id,name,slot,hides,tints,mat,hair=False,**kw):
    d={"name":name,"slot":slot,"hides":hides,"tints":tints,"mat":mat}
    if hair:d["hides_hair"]=True
    d.update(kw);I[id]=d;return id
T=["torso"];UA=["upperarms"];FA=["forearms"];H=["hips"];TH=["thighs"];SH=["shins"];F=["feet"];N=["neck"]
ARMS=UA+FA;LEGS=H+TH+SH

# ---------------- juuksed ja habemed (tools/hair.py)
# päris soengud ja habemed: MakeHumani CC0 juuksekaardid (tools/mh_hair.py)
import mh_hair as MHH
for hid,(pack,rel,name,bulky) in MHH.HAIRS.items(): item(hid,name,"hair",[],[],"hair",hair_color=True,bulky=bulky)
for bid,(name,parts) in MHH.BEARDS.items(): item(bid,name,"beard",[],[],"hair",hair_color=True)
# päris riided ja jalanõud (MakeHuman CC0): värv tekstuurist, mäng ei tooni
for cid,(pack,rel,name,slot,hides) in MHH.CLOTHES.items(): item(cid,name,slot,hides,[],"mhc",hair=slot=="head")

# ---------------- 0 kiviaeg
item("stone_hide_loincloth","Nahkne niudevöö","underwear",H,[HIDE],"hide")
item("stone_hide_tunic","Nahkne kuub","torso",T+H,[HIDE,BROWN],"hide")
item("stone_hide_leggings","Nahksäärised","socks",TH+SH,[HIDE,BROWN],"hide")
item("stone_moccasins","Nahkkingad (mokassiinid)","feet",F,[LEATHER],"leather")
item("stone_fur_boots","Karusnahksed säärsaapad","feet",F,[FUR],"fur")
item("stone_fur_cloak","Karusnahkne keep","outer",T+UA,[FUR],"fur")
item("stone_fur_cape","Karusnahkne õlakate","outer",[],[FUR,"8a7258"],"fur")
item("stone_fur_vest","Karusnahkne vest","torso",T,[FUR,"8a7258"],"fur")
item("stone_fur_hood","Karusnahkne kapuuts","head",N,[FUR],"fur",hair=True)
item("stone_hide_kilt","Nahkne põll-seelik","legs",H+TH,[HIDE],"hide")
item("stone_hide_dress","Pikk nahkkleit","torso",T+H+TH,[HIDE,BROWN],"hide")
item("stone_hide_skirt","Pikk nahkseelik","legs",H+TH+SH,[HIDE,BROWN],"hide")
item("stone_hide_top","Nahkne pluus","torso",T,[HIDE],"hide")
item("stone_bast_skirt","Niinest seelik","legs",H+TH,["b59a6a"],"straw")
item("stone_amber_necklace","Merevaigust ja hambaripatsitega kaelakee","jewelry",[],[WELD],"metal")
# ---------------- 1 pronksiaeg
item("bronze_wool_wrap","Villane mähisrõivas","torso",T+H+TH,WOOL[:3],"wool")
item("bronze_wool_tunic","Lühike villane kuub","torso",T+H+UA,WOOL[:4],"wool")
item("bronze_kilt","Villane põlvseelik","legs",H+TH,[BROWN,UNDYED],"wool")
item("bronze_wool_cape","Ümar villane keep","outer",T+UA,[BROWN,UNDYED],"wool")
item("bronze_felt_cap","Villane vildikübar","head",[],[BLACK,BROWN],"felt",hair=True)
item("bronze_leather_shoes","Nahkkingad","feet",F,[LEATHER],"leather")
item("bronze_belt","Nahkvöö pronkspandlaga","belt",[],[LEATHER],"leather")
item("bronze_wool_blouse","Lühikeste varrukatega villane pluus","torso",T+UA,[BROWN,UNDYED],"wool")
item("bronze_cord_skirt","Nööriseelik","legs",H,[UNDYED,BROWN],"linen")
item("bronze_long_skirt","Pikk villane seelik","legs",LEGS,[BROWN,UNDYED,MADDER],"wool")
item("bronze_wool_dress","Pikk villane kleit","torso",T+LEGS+UA,[BROWN,UNDYED,WOAD],"wool")
item("bronze_wool_shawl","Villane õlarätt","outer",[],[UNDYED,MADDER],"wool")
item("bronze_belt_disc","Pronksist vööketas","belt",[],[WELD],"metal")
item("bronze_hairnet","Juuksevõrk","head",[],[UNDYED],"hair",hair=True)
item("bronze_neck_ring","Pronksist kaelavõru","jewelry",[],[WELD],"metal")
# ---------------- 2 rauaaeg
item("iron_linen_shirt","Linane särk","shirt",T+ARMS,[LINEN],"linen")
item("iron_wool_trousers","Villased püksid","legs",LEGS,[BROWN,UNDYED,GREY],"wool")
item("iron_trousers_herringbone","Kalasabakoes püksid","legs",LEGS,[UNDYED,BROWN,GREY],"herringbone")
item("iron_wool_tunic","Villane kuub","torso",T+H+UA,WOOL,"wool")
item("iron_tunic_plaid","Ruuduline villane kuub","torso",T+H+UA,[MADDER,GREEN,WOAD,BROWN],"plaid")
item("iron_cloak_brooch","Mantel hoburaudsõlega","outer",T+UA,[BROWN,WOAD,GREY],"wool")
item("iron_wool_cap","Villane müts","head",[],[BROWN,GREY],"wool",hair=True)
item("iron_pastlad","Pastlad ja säärepaelad","feet",F,[LEATHER],"leather")
item("iron_belt_knife","Vöö ja nuga","belt",[],[LEATHER],"leather")
item("iron_torc","Keerdkaelavõru","jewelry",[],[WELD],"metal")
item("iron_linen_shift","Pikk linane särk","shirt",T+H+TH+ARMS,[LINEN],"linen")
item("iron_wool_skirt","Villane vaipseelik","legs",LEGS,[WOAD,BROWN,UNDYED],"wool")
item("iron_skirt_striped","Triibuline villane seelik","legs",LEGS,[MADDER,WOAD,GREEN],"stripe")
item("iron_skirt_plaid","Ruuduline vaipseelik","legs",LEGS,[WOAD,GREEN,MADDER],"plaid")
item("iron_peplos","Villane peplos-kleit","torso",T+LEGS,[WOAD,BROWN,MADDER],"wool")
item("iron_apron","Linane põll","apron",[],[LINEN,UNDYED],"linen")
item("iron_soba","Õlarätt (sõba)","outer",[],[WOAD,UNDYED],"wool")
item("iron_spiral_headband","Pronksspiraalidega peapael","head",[],[WELD],"metal")
item("iron_breast_ornaments","Kaelavõru ja rinnalehed","jewelry",[],[WELD],"metal")
# ---------------- 3 keskaeg
item("med_linen_shirt","Linane särk","shirt",T+ARMS,[LINEN],"linen")
item("med_wool_hose","Villased sukkpüksid","legs",LEGS,[BROWN,MADDER,WOAD,GREY],"wool")
item("med_wool_cote","Põlvini villane kuub","torso",T+H+TH+ARMS,WOOL,"wool")
item("med_short_cote","Lühike villane kuub","torso",T+H+ARMS,WOOL,"wool")
item("med_long_robe","Pikk villane rüü","torso",T+LEGS+ARMS,[BROWN,GREY,BLACK,UNDYED],"wool")
item("med_surcoat","Varrukateta pealiskuub","outer",T+H+TH,[MADDER,WOAD,GREEN],"wool")
item("med_hood","Kapuuts õlakattega","head",N,[MADDER,WOAD,GREEN,BROWN],"wool",hair=True)
item("med_turnshoes","Pöördkingad","feet",F,[LEATHER],"leather")
item("med_boots","Nahksaapad","feet",F,[LEATHER,BLACK],"leather")
item("med_belt_pouch","Vöö ja kukkur","belt",[],[LEATHER],"leather")
item("med_linen_chemise","Linane alussärk","shirt",T+H+TH+ARMS,[LINEN],"linen")
item("med_wool_kirtle","Pikk villane kleit","torso",T+LEGS+ARMS,WOOL,"wool")
item("med_kirtle_striped","Triibuline villane kleit","torso",T+LEGS+ARMS,[MADDER,WOAD,GREEN],"stripe")
item("med_sideless_gown","Varrukateta pealiskleit","outer",T+LEGS,[MADDER,WOAD,GREEN,BROWN],"wool")
item("med_apron","Põll","apron",[],[LINEN,UNDYED],"linen")
item("med_headcloth","Linane peakate","head",N,[LINEN],"linen",hair=True)
item("med_wool_mantle","Villane mantel","outer",T+UA,[BROWN,WOAD,GREEN],"wool")
# ---------------- 4 renessanss
item("ren_shirt","Krae ja kurrutatud kätistega särk","shirt",T+ARMS,[WHITE,LINEN],"linen")
item("ren_doublet","Vamss","torso",T+ARMS,[BLACK,BROWN,MADDER,GREEN],"wool")
item("ren_doublet_brocade","Brokaatvamss","torso",T+ARMS,[MADDER,GREEN,NAVY,WELD],"brocade")
item("ren_jerkin","Nahkvest","outer",T,[LEATHER,BROWN],"leather")
item("ren_coat","Põlvini kuub","outer",T+H+TH+ARMS,[BLACK,BROWN,GREEN],"wool")
item("ren_breeches","Pluuderpüksid","legs",H+TH,[BLACK,BROWN,GREY],"wool")
item("ren_trousers","Laiad püksid","legs",LEGS,[BROWN,GREY,UNDYED],"wool")
item("ren_stockings","Villased sukad","socks",SH,[UNDYED,GREY,MADDER],"knit")
item("ren_shoes","Nahkkingad","feet",F,[LEATHER,BLACK],"leather")
item("ren_boots","Säärsaapad","feet",F,[LEATHER,BLACK],"leather")
item("ren_flat_cap","Barett","head",[],[BLACK,BROWN],"felt",hair=True)
item("ren_smock","Linane särk","shirt",T+ARMS,[WHITE,LINEN],"linen")
item("ren_bodice_gown","Liibuga kleit","torso",T+LEGS,[MADDER,GREEN,BROWN,WOAD],"wool")
item("ren_gown_brocade","Brokaatkleit","torso",T+LEGS,[MADDER,GREEN,NAVY,WELD],"brocade")
item("ren_bodice","Liivik","torso",T,[BLACK,MADDER,GREEN],"wool")
item("ren_skirt","Pikk seelik","legs",LEGS,[BROWN,WOAD,GREEN],"wool")
item("ren_skirt_striped","Triibuline seelik","legs",LEGS,[MADDER,WOAD,GREEN],"stripe")
item("ren_apron","Põll","apron",[],[WHITE,LINEN],"linen")
item("ren_coif","Tanu","head",[],[WHITE],"linen",hair=True)
item("ren_shawl","Õlarätt","outer",[],[UNDYED,MADDER],"wool")
# ---------------- 5 tööstusajastu
item("ind_cotton_shirt","Puuvillane särk","shirt",T+ARMS,[WHITE,LINEN,"b8c4cc"],"linen")
item("ind_trousers_braces","Villased püksid traksidega","legs",LEGS,[GREY,BROWN,BLACK],"wool")
item("ind_waistcoat","Vest","torso",T,[BLACK,GREY,BROWN],"wool")
item("ind_sweater","Kootud kampsun","torso",T+ARMS,["8a8f7a",GREY,NAVY,BROWN],"knit")
item("ind_wool_jacket","Villane pintsak","outer",T+ARMS,[GREY,BROWN,NAVY],"herringbone")
item("ind_greatcoat","Pikk mantel","outer",T+H+TH+ARMS,[BLACK,GREY,BROWN],"wool")
item("ind_boots","Säärsaapad","feet",F,[BLACK,LEATHER],"leather")
item("ind_flat_cap","Nokamüts","head",[],[GREY,BROWN],"herringbone",hair=True)
item("ind_bowler","Kõvakübar","head",[],[BLACK,BROWN],"felt",hair=True)
item("ind_blouse","Pikkade varrukatega pluus","shirt",T+ARMS,[WHITE,"c9d3dc","b7c2cc"],"linen")
item("ind_long_skirt","Pikk seelik","legs",LEGS,[NAVY,BROWN,BLACK,GREY],"wool")
item("ind_skirt_striped","Triibuline rahvaseelik","legs",LEGS,[MADDER,WELD,GREEN,WOAD],"stripe")
item("ind_skirt_plaid","Ruuduline seelik","legs",LEGS,[GREEN,MADDER,NAVY],"plaid")
item("ind_dress","Pikk kleit","torso",T+LEGS+ARMS,[NAVY,BLACK,BROWN,GREEN],"wool")
item("ind_cardigan","Kootud jakk","outer",T+ARMS,["6f7d6a",GREY,MADDER],"knit")
item("ind_apron","Põll","apron",[],[WHITE,"c9d3dc"],"linen")
item("ind_headscarf","Pearätt","head",[],[MADDER,WOAD,UNDYED],"linen",hair=True)
item("ind_wool_shawl","Villane suurrätt","outer",[],[GREY,BROWN,MADDER],"plaid")
# ---------------- 6 moodne
item("mod_tshirt","T-särk","shirt",T+UA,[WHITE,GREY,NAVY,GREEN,MADDER],"jersey")
item("mod_shirt","Nööpidega särk","shirt",T+ARMS,[WHITE,"b8c4cc","9fb0c4"],"linen")
item("mod_sweater","Kootud kampsun","torso",T+ARMS,[GREY,NAVY,GREEN,"8c6f5a"],"knit")
item("mod_hoodie","Kapuutsiga dressipluus","outer",T+ARMS,[GREY,BLACK,NAVY,MADDER],"jersey")
item("mod_jeans","Teksapüksid","legs",LEGS,[DENIM,NAVY,BLACK],"denim")
item("mod_chinos","Riidest püksid","legs",LEGS,[KHAKI,"6b6355",NAVY],"twill")
item("mod_work_jacket","Jope","outer",T+ARMS,[KHAKI,NAVY,BLACK,GREEN],"denim")
item("mod_sneakers","Spordijalatsid","feet",F,[WHITE,GREY,BLACK],"jersey")
item("mod_shoes","Kingad","feet",F,[BLACK,BROWN],"leather")
item("mod_cap","Nokkmüts","head",[],[NAVY,BLACK,MADDER],"twill",hair=True)
item("mod_blouse","Pluus","shirt",T+UA,[WHITE,"c9d3dc",MADDER,GREEN],"jersey")
item("mod_skirt","Põlvepikkune seelik","legs",H+TH,[NAVY,BLACK,GREY],"wool")
item("mod_dress","Põlvini kleit","torso",T+H+TH+UA,[NAVY,MADDER,GREEN,BLACK],"jersey")
# ---------------- tööde lisad
item("work_leather_apron","Nahkpõll","apron",[],[LEATHER],"leather")
item("work_straw_hat","Õlgkübar","head",[],[WELD],"straw",hair=True)
item("work_oilskin_coat","Õlirõivast vihmamantel","outer",T+ARMS+H+TH,[WELD,KHAKI],"oilcloth")
item("work_overall","Tunked","torso",T+LEGS,[NAVY,KHAKI],"denim")
item("work_hard_hat","Kiiver","head",[],["e0b030",WHITE],"jersey",hair=True)
item("work_hi_vis_vest","Helkurvest","outer",T,["d8e030","e07030"],"jersey")
# ---------------- sõjavarustus (team=True: vägede värv)
item("mil_hide_armor","Paksust nahast rüü","armor",T+H,[HIDE],"hide")
item("mil_team_sash","Vägede värvi vööpael","belt",[],[],"wool",team=True)
item("mil_team_tunic","Vägede värvi kuub","torso",T+H+UA,[],"wool",team=True)
item("mil_bronze_helmet","Pronkskiiver","head",[],[BRONZE],"plate",hair=True)
item("mil_bronze_cuirass","Pronksist rinnaturvis","cuirass",T,[BRONZE],"plate")
item("mil_leather_cuirass","Nahkrinnaturvis","cuirass",T+H,[LEATHER],"leather")
item("mil_spangenhelm","Spangenhelm","head",[],[IRON],"plate",hair=True)
item("mil_mail_shirt","Rõngassärk","armor",T+H+UA,[IRON],"mail")
item("mil_mail_hauberk","Pikk rõngasrüü","armor",T+H+TH+ARMS,[IRON],"mail")
item("mil_mail_coif","Rõngaskapuuts","head",N,[IRON],"mail",hair=True)
item("mil_great_helm","Suurkiiver","head",N,[STEEL],"plate",hair=True)
item("mil_kettle_hat","Rauast kübarkiiver","head",[],[IRON],"plate",hair=True)
item("mil_team_surcoat","Vapikuub","outer",T+H+TH,[],"wool",team=True)
item("mil_gambeson","Vatitikkimisega kuub","torso",T+H+TH+ARMS,[UNDYED,"b9a888"],"quilted")
item("mil_plate_cuirass","Plaatrinnaturvis","cuirass",T,[STEEL],"plate")
item("mil_plate_legs","Jalasoomus","socks",TH+SH,[STEEL],"plate")
item("mil_plate_arms","Käesoomus","armarm",ARMS,[STEEL],"plate")
item("mil_morion","Morion-kiiver","head",[],[STEEL],"plate",hair=True)
item("mil_felt_hat","Laia äärega viltkübar","head",[],[BLACK,BROWN],"felt",hair=True)
item("mil_team_doublet","Vägede värvi vamss","torso",T+ARMS,[],"wool",team=True)
item("mil_team_coat","Vormikuub","outer",T+H+TH+ARMS,[],"wool",team=True)
item("mil_white_trousers","Valged vormipüksid","legs",LEGS,[WHITE,"d9d4c4"],"twill")
item("mil_shako","Šako","head",[],[BLACK],"felt",hair=True)
item("mil_kepi","Vormimüts","head",[],[],"felt",hair=True,team=True)
item("mil_crossbelts","Ristirihmad","belt",[],[WHITE],"leather")
item("mil_army_boots","Sõjaväesaapad","feet",F,[BLACK],"leather")
item("mil_camo_jacket","Laigulise mustriga välivormi jope","outer",T+ARMS+H,["ffffff"],"camo")
item("mil_camo_trousers","Laigulise mustriga välivormi püksid","legs",LEGS,["ffffff"],"camo")
item("mil_combat_helmet","Lahingukiiver","head",[],[OLIVE],"jersey",hair=True)
item("mil_plate_carrier","Kuulivest","cuirass",T,[OLIVE,"6e6a4e"],"twill")
item("mil_team_armband","Vägede värvi käepael","jewelry",[],[],"wool",team=True)

def o(name,*items):return {"name":name,"items":list(items)}
eras=[
 {"id":"stone","name":"Kiviaeg",
  "man":[o("Nahkriided","stone_hide_loincloth","stone_hide_tunic","stone_hide_leggings","stone_moccasins"),
         o("Talveriided","stone_hide_loincloth","stone_hide_tunic","stone_hide_leggings","stone_moccasins","stone_fur_cloak"),
         o("Karusnahkne vest","stone_hide_loincloth","stone_fur_vest","stone_hide_leggings","stone_moccasins","stone_amber_necklace"),
         o("Säärsaabastega","stone_hide_loincloth","stone_hide_tunic","stone_hide_leggings","stone_fur_boots","stone_fur_cape"),
         o("Suveriided","stone_hide_loincloth","stone_hide_kilt","stone_fur_cape","stone_moccasins")],
  "woman":[o("Nahkkleit","stone_hide_dress","stone_hide_leggings","stone_moccasins","stone_amber_necklace"),
           o("Talvekleit","stone_hide_dress","stone_hide_leggings","stone_moccasins","stone_fur_cloak"),
           o("Seelik ja vest","stone_hide_skirt","stone_fur_vest","stone_moccasins","stone_amber_necklace"),
           o("Karusnahaga","stone_hide_dress","stone_fur_boots","stone_fur_cape"),
           o("Niinseelik","stone_bast_skirt","stone_hide_top","stone_hide_leggings","stone_moccasins","stone_amber_necklace")],
  "hair":{"man":["mh_shaggy", "mh_long", "mh_messy", "mh_short_messy", "mh_short03"],
          "woman":["mh_long", "mh_shaggy", "mh_braid", "mh_curly_long", "mh_braid_french"]},
  "beards":["mh_beard_long", "mh_beard_long", "", "mh_beard_goatee", ""],
  "jobs":{"hunter":{"all":["stone_fur_hood","stone_fur_cloak"]}},"tools":{}},
 {"id":"bronze","name":"Pronksiaeg",
  "man":[o("Mähisrõivas","bronze_wool_wrap","bronze_wool_cape","bronze_felt_cap","bronze_leather_shoes"),
         o("Lühike kuub","bronze_wool_tunic","bronze_belt","bronze_leather_shoes"),
         o("Mähis ja kaelavõru","bronze_wool_wrap","bronze_leather_shoes","bronze_neck_ring"),
         o("Põlvseelik ja keep","bronze_kilt","bronze_wool_cape","bronze_belt","bronze_leather_shoes"),
         o("Kuub ja keep","bronze_wool_tunic","bronze_wool_cape","bronze_felt_cap","bronze_leather_shoes")],
  "woman":[o("Nööriseelik","bronze_wool_blouse","bronze_cord_skirt","bronze_belt_disc","bronze_leather_shoes","bronze_neck_ring"),
           o("Pikk seelik","bronze_wool_blouse","bronze_long_skirt","bronze_belt_disc","bronze_leather_shoes"),
           o("Õlarätiga","bronze_wool_blouse","bronze_long_skirt","bronze_wool_shawl","bronze_leather_shoes","bronze_hairnet"),
           o("Villane kleit","bronze_wool_dress","bronze_belt_disc","bronze_wool_cape","bronze_leather_shoes"),
           o("Nööriseelik ja keep","bronze_wool_blouse","bronze_cord_skirt","bronze_wool_cape","bronze_leather_shoes")],
  "hair":{"man":["mh_long", "mh_short_messy", "mh_messy", "mh_short03", "mh_ponytail"],
          "woman":["mh_braid", "mh_braid_french", "mh_long", "mh_bun_messy", "mh_bun_braid"]},
  "beards":["mh_beard_long", "mh_beard_goatee", "mh_moustache", "", ""],
  "jobs":{"bronze_foundry":{"all":["work_leather_apron"]}},
  "tools":{"lumber":"bronze_axe","forester":"bronze_axe","builder":"bronze_hammer","mason":"bronze_chisel","quarry":"bronze_pick","mine":"bronze_pick","coppermine":"bronze_pick","tinmine":"bronze_pick","farm":"bronze_sickle","hunter":"bronze_spear","fisher":"bronze_fishing_spear","bronze_foundry":"bronze_tongs"}},
 {"id":"iron","name":"Rauaaeg",
  "man":[o("Kuub ja püksid","iron_linen_shirt","iron_wool_trousers","iron_wool_tunic","iron_pastlad","iron_belt_knife"),
         o("Mantliga","iron_linen_shirt","iron_wool_trousers","iron_wool_tunic","iron_pastlad","iron_belt_knife","iron_cloak_brooch"),
         o("Ruuduline kuub","iron_linen_shirt","iron_trousers_herringbone","iron_tunic_plaid","iron_pastlad","iron_belt_knife"),
         o("Viikingi riided","mhc_viking_tunic","mhc_viking_pants","mhc_viking_boots","iron_cloak_brooch"),
         o("Pidulik","iron_linen_shirt","iron_trousers_herringbone","iron_wool_tunic","iron_pastlad","iron_belt_knife","iron_torc")],
  "woman":[o("Vaipseelik","iron_linen_shift","iron_wool_skirt","iron_pastlad","iron_breast_ornaments"),
           o("Sõbaga","iron_linen_shift","iron_wool_skirt","iron_soba","iron_pastlad","iron_breast_ornaments"),
           o("Peplos","iron_linen_shift","iron_peplos","iron_pastlad","iron_breast_ornaments"),
           o("Triibuline seelik","iron_linen_shift","iron_skirt_striped","iron_soba","iron_pastlad"),
           o("Ruuduline seelik ja põll","iron_linen_shift","iron_skirt_plaid","iron_apron","iron_pastlad","iron_spiral_headband")],
  "hair":{"man":["mh_viking", "mh_long", "mh_short03", "mh_messy", "mh_ponytail"],
          "woman":["mh_braid", "mh_braid_french", "mh_bun_braid", "mh_long", "mh_bun_messy"]},
  "beards":["mh_beard_long", "", "mh_moustache", "", "mh_beard_goatee"],
  "jobs":{"smith":{"all":["work_leather_apron"]},"smelter":{"all":["work_leather_apron"]}},
  "tools":{"lumber":"iron_axe","forester":"iron_axe","builder":"iron_hammer","mason":"iron_chisel","quarry":"iron_pick","mine":"iron_pick","farm":"iron_sickle","hunter":"iron_spear","fisher":"iron_fishing_net","smith":"iron_smith_hammer"}},
 {"id":"medieval","name":"Keskaeg",
  "man":[o("Põlvini kuub","med_linen_shirt","med_wool_hose","med_wool_cote","med_turnshoes","med_belt_pouch"),
         o("Kapuutsiga","med_linen_shirt","med_wool_hose","med_wool_cote","med_turnshoes","med_belt_pouch","med_hood"),
         o("Pealiskuub","med_linen_shirt","med_wool_hose","med_wool_cote","med_surcoat","med_turnshoes"),
         o("Lühike kuub ja saapad","med_linen_shirt","med_wool_hose","med_short_cote","med_wool_mantle","mhc_viking_boots","med_belt_pouch"),
         o("Pikk rüü","med_linen_shirt","med_long_robe","med_belt_pouch","med_turnshoes")],
  "woman":[o("Villane kleit","med_linen_chemise","med_wool_kirtle","med_turnshoes"),
           o("Põll ja peakate","med_linen_chemise","med_wool_kirtle","med_apron","med_headcloth","med_turnshoes"),
           o("Pealiskleit","med_linen_chemise","med_wool_kirtle","med_sideless_gown","med_turnshoes"),
           o("Mantliga","med_linen_chemise","med_wool_kirtle","med_wool_mantle","med_headcloth","med_turnshoes"),
           o("Triibuline kleit","med_linen_chemise","med_kirtle_striped","med_apron","med_turnshoes")],
  "hair":{"man":["mh_bob_page", "mh_short03", "mh_short01", "mh_messy", "mh_bob_curled"],
          "woman":["mh_braid", "mh_bun_braid", "mh_bun_messy", "mh_braid_french", "mh_long"]},
  "beards":["", "", "mh_beard_goatee", "mh_beard_long", "", ""],
  "jobs":{"farm":{"all":["work_straw_hat"]},"smith":{"all":["work_leather_apron"]}},
  "tools":{"lumber":"iron_axe","forester":"iron_axe","builder":"iron_hammer","mason":"iron_chisel","quarry":"iron_pick","mine":"iron_pick","farm":"scythe","fisher":"iron_fishing_net","smith":"iron_smith_hammer"}},
 {"id":"renaissance","name":"Renessanss",
  "man":[o("Vamss ja barett","ren_shirt","ren_doublet","ren_breeches","ren_stockings","ren_shoes","ren_flat_cap"),
         o("Brokaatvamss","ren_shirt","ren_doublet_brocade","ren_breeches","ren_stockings","ren_shoes"),
         o("Nahkvest","ren_shirt","ren_doublet","ren_jerkin","ren_breeches","ren_stockings","ren_shoes"),
         o("Pikk kuub","ren_shirt","ren_doublet","ren_coat","ren_breeches","ren_stockings","ren_shoes","ren_flat_cap"),
         o("Tööriided","ren_shirt","ren_jerkin","ren_trousers","ren_boots")],
  "woman":[o("Liibuga kleit ja tanu","ren_smock","ren_bodice_gown","ren_apron","ren_coif","ren_shoes"),
           o("Brokaatkleit","ren_smock","ren_gown_brocade","ren_shoes"),
           o("Triibuline seelik","ren_smock","ren_bodice","ren_skirt_striped","ren_apron","ren_shoes"),
           o("Õlarätiga","ren_smock","ren_bodice_gown","ren_shawl","ren_coif","ren_shoes"),
           o("Liivik ja seelik","ren_smock","ren_bodice","ren_skirt","ren_shawl","ren_shoes")],
  "hair":{"man":["mh_bob_curled", "mh_bob_page", "mh_short01", "mh_short04", "mh_short03"],
          "woman":["mh_bun_braid", "mh_bun_messy", "mh_braid", "mh_long", "mh_bob_curled"]},
  "beards":["mh_beard_goatee", "", "mh_moustache", "", "mh_beard_long"],
  "jobs":{"farm":{"all":["work_straw_hat"]},"smith":{"all":["work_leather_apron"]},"printer":{"all":["work_leather_apron"]}},
  "tools":{"lumber":"steel_axe","builder":"steel_hammer","mason":"steel_chisel","mine":"steel_pick","farm":"scythe","smith":"iron_smith_hammer"}},
 {"id":"industrial","name":"Tööstusajastu",
  "man":[o("Traksidega","ind_cotton_shirt","ind_trousers_braces","ind_boots","ind_flat_cap"),
         o("Vest, pintsak ja kaabu","ind_cotton_shirt","ind_waistcoat","ind_trousers_braces","ind_wool_jacket","mhc_shoes_black","mhc_fedora"),
         o("Kampsun","ind_cotton_shirt","ind_sweater","ind_trousers_braces","ind_boots","ind_flat_cap"),
         o("Mantel ja kõvakübar","ind_cotton_shirt","ind_waistcoat","ind_greatcoat","ind_trousers_braces","mhc_shoes_black","ind_bowler"),
         o("Tööpõll","ind_cotton_shirt","ind_trousers_braces","work_leather_apron","mhc_boots_black")],
  "woman":[o("Pearätt ja põll","ind_blouse","ind_long_skirt","ind_apron","ind_headscarf","ind_boots"),
           o("Triibuline rahvaseelik","ind_blouse","ind_skirt_striped","ind_apron","ind_headscarf","ind_boots"),
           o("Suurrätiga","ind_blouse","ind_long_skirt","ind_wool_shawl","ind_boots"),
           o("Pikk kleit","ind_dress","ind_apron","mhc_boots_black"),
           o("Ruuduline seelik ja jakk","ind_blouse","ind_skirt_plaid","ind_cardigan","ind_boots")],
  "hair":{"man":["mh_short01", "mh_short02", "mh_short04", "mh_messy", "mh_short03"],
          "woman":["mh_bun_messy", "mh_bun_braid", "mh_ponytail", "mh_braid", "mh_braid_french"]},
  "beards":["mh_moustache", "mh_beard_long", "", "mh_moustache", ""],
  "jobs":{"fisher":{"all":["work_oilskin_coat"]},"farm":{"all":["work_straw_hat"]},"steelworks":{"all":["work_leather_apron"]}},
  "tools":{"lumber":"saw_two_man","builder":"steel_hammer","mine":"steel_pick","farm":"pitchfork","steelworks":"steel_tongs"}},
 {"id":"modern","name":"Moodne ajastu",
  "man":[o("Teksasärk ja teksased","mhc_shirt_jeans","mhc_shoes_brown"),
         o("Jope ja teksased","mhc_jacket_jeans","mhc_boots_black"),
         o("Triibuline särk","mhc_striped_jeans","mhc_sneakers_white"),
         o("Ülikond","mhc_suit","mhc_shoes_black"),
         o("Dressipluus","mod_tshirt","mod_hoodie","mod_jeans","mhc_sneakers_blue","mod_cap")],
  "woman":[o("Pluus ja seelik","mhc_blouse_skirt","mhc_shoes_black"),
           o("T-särk ja seelik","mod_tshirt","mod_skirt","mhc_sneakers_white"),
           o("Kampsun","mod_sweater","mod_jeans","mhc_shoes_brown"),
           o("Kleit","mod_dress","mhc_shoes_black"),
           o("Jopega","mod_tshirt","mod_jeans","mod_work_jacket","mhc_sneakers_blue")],
  "hair":{"man":["mh_short02", "mh_short04", "mh_short_messy", "mh_short01", "mh_messy"],
          "woman":["mh_bob01", "mh_bob_blunt_bangs", "mh_ponytail", "mh_pixie", "mh_long_bangs"]},
  "beards":["", "", "mh_moustache", "mh_beard_goatee", "", ""],
  "jobs":{"builder":{"all":["work_hard_hat","work_hi_vis_vest"]},"mine":{"all":["work_hard_hat"]},"autofactory":{"all":["work_overall"]},"refinery":{"all":["work_overall","work_hard_hat"]}},
  "tools":{"lumber":"chainsaw","builder":"power_drill"}},
]
for e in eras:
    e["boy"]={"from":"man","drop":["jewelry","belt","apron"]}
    e["girl"]={"from":"woman","drop":["jewelry","belt","apron"]}

# ---------------- sõdurid: väeliik -> ajastu ja varustus (relvad tulevad sõdurimudelist)
U=lambda era,*items:{"era":era,"items":list(items)}
units={
 "scout":U(0,"stone_hide_loincloth","stone_hide_tunic","stone_hide_leggings","stone_moccasins","stone_fur_hood","mil_team_sash"),
 "militia":U(0,"stone_hide_loincloth","stone_hide_tunic","stone_hide_leggings","stone_moccasins","mil_team_sash"),
 "stone_guard":U(0,"stone_hide_loincloth","mil_hide_armor","stone_hide_leggings","stone_fur_boots","mil_team_sash"),
 "slinger":U(0,"stone_hide_loincloth","stone_hide_tunic","stone_hide_leggings","stone_moccasins","mil_team_sash"),
 "spearman":U(0,"stone_hide_loincloth","stone_fur_vest","stone_hide_leggings","stone_moccasins","stone_fur_cape","mil_team_sash"),
 "axeman":U(0,"stone_hide_loincloth","mil_hide_armor","stone_hide_leggings","stone_fur_boots","mil_team_sash"),
 "archer":U(0,"stone_hide_loincloth","stone_hide_tunic","stone_hide_leggings","stone_moccasins","mil_team_sash"),
 "bronze_spearman":U(1,"mil_team_tunic","mil_bronze_cuirass","bronze_kilt","bronze_leather_shoes","mil_bronze_helmet"),
 "bronze_axeman":U(1,"mil_team_tunic","mil_leather_cuirass","bronze_leather_shoes","mil_bronze_helmet"),
 "bronze_archer":U(1,"mil_team_tunic","bronze_leather_shoes","bronze_belt","bronze_felt_cap"),
 "chariot":U(1,"mil_team_tunic","mil_bronze_cuirass","bronze_leather_shoes","mil_bronze_helmet"),
 "bronze_cavalry":U(2,"mil_team_tunic","mil_leather_cuirass","iron_wool_trousers","iron_pastlad","mil_bronze_helmet"),
 "infantry":U(2,"mhc_viking_tunic","mhc_viking_pants","mhc_viking_boots","mil_spangenhelm","mil_team_sash"),
 "cavalry":U(2,"iron_linen_shirt","mil_team_tunic","mil_mail_shirt","iron_wool_trousers","iron_pastlad","mil_spangenhelm","iron_cloak_brooch"),
 "iron_archer":U(2,"iron_linen_shirt","mil_team_tunic","iron_wool_trousers","iron_pastlad","iron_belt_knife","iron_wool_cap"),
 "javelinman":U(2,"iron_linen_shirt","mil_team_tunic","iron_wool_trousers","iron_pastlad","mil_leather_cuirass"),
 "battering_ram":U(2,"iron_linen_shirt","mil_team_tunic","iron_wool_trousers","iron_pastlad"),
 "siege_tower":U(2,"iron_linen_shirt","mil_team_tunic","iron_wool_trousers","iron_pastlad"),
 "knight":U(3,"med_linen_shirt","mil_mail_hauberk","mil_team_surcoat","mil_plate_legs","med_boots","mil_great_helm"),
 "heavy_cavalry":U(3,"med_linen_shirt","mil_mail_hauberk","mil_plate_cuirass","mil_team_surcoat","mil_plate_legs","med_boots","mil_great_helm"),
 "man_at_arms":U(3,"med_linen_shirt","mil_gambeson","mil_mail_shirt","mil_team_surcoat","med_wool_hose","med_boots","mil_kettle_hat"),
 "halberdier":U(3,"med_linen_shirt","mil_gambeson","mil_team_surcoat","med_wool_hose","med_boots","mil_kettle_hat"),
 "crossbowman":U(3,"med_linen_shirt","mil_gambeson","mil_team_surcoat","med_wool_hose","med_boots","mil_kettle_hat"),
 "catapult":U(3,"med_linen_shirt","med_short_cote","mil_team_sash","med_wool_hose","med_boots"),
 "pikeman":U(4,"ren_shirt","mil_team_doublet","mil_plate_cuirass","ren_breeches","ren_stockings","ren_shoes","mil_morion"),
 "musketeer":U(4,"ren_shirt","mil_team_doublet","ren_breeches","ren_stockings","ren_boots","mil_felt_hat","mil_crossbelts"),
 "arquebusier":U(4,"ren_shirt","mil_team_doublet","ren_breeches","ren_stockings","ren_shoes","mil_morion"),
 "cuirassier":U(4,"ren_shirt","mil_team_doublet","mil_plate_cuirass","mil_plate_arms","ren_breeches","ren_boots","mil_morion"),
 "field_cannon":U(4,"ren_shirt","mil_team_doublet","ren_breeches","ren_stockings","ren_shoes","mil_felt_hat"),
 "rifleman":U(5,"ind_cotton_shirt","mil_team_coat","mil_white_trousers","mil_army_boots","mil_shako","mil_crossbelts"),
 "line_infantry":U(5,"ind_cotton_shirt","mil_team_coat","mil_white_trousers","mil_army_boots","mil_shako","mil_crossbelts"),
 "dragoon":U(5,"ind_cotton_shirt","mil_team_coat","mil_white_trousers","mil_army_boots","mil_kepi"),
 "industrial_artillery":U(5,"ind_cotton_shirt","mil_team_coat","ind_trousers_braces","mil_army_boots","mil_kepi"),
 "modern_infantry":U(6,"mod_tshirt","mil_camo_jacket","mil_camo_trousers","mil_army_boots","mil_combat_helmet","mil_plate_carrier","mil_team_armband"),
 "machinegun_team":U(6,"mod_tshirt","mil_camo_jacket","mil_camo_trousers","mil_army_boots","mil_combat_helmet","mil_plate_carrier","mil_team_armband"),
 "rocket_team":U(6,"mod_tshirt","mil_camo_jacket","mil_camo_trousers","mil_army_boots","mil_combat_helmet","mil_plate_carrier","mil_team_armband"),
 "motorized":U(6,"mod_tshirt","mil_camo_jacket","mil_camo_trousers","mil_army_boots","mil_combat_helmet","mil_team_armband"),
}
data={
 "_info":"Inimeste kehad, riided, soengud ja ajastute riidekomplektid. Riidefail: res://assets/people/clothes/<ese>/<keha>.glb. Tööriist: res://assets/people/equipment/<nimi>.glb. Sõdurite relvad ja hobused tulevad res://assets/soldiers/split/<väeliik>.glb failist. Puuduva faili korral jäetakse ese vahele ja kehaosa ei peideta.",
 "zones":["head","neck","torso","hips","upperarms","forearms","hands","thighs","shins","feet"],
 "slots":["hair","beard","underwear","shirt","socks","legs","torso","armor","feet","armarm","cuirass","apron","belt","outer","head","jewelry"],
 "hair_colors":["e0c898","c9a46e","a07a4e","7a5838","5a4030","3b2a1e","241c17","9a5a32","8a4426"],
 "team_colors":["276bd1","c43d43","9271ce","d2a12e"],
 "bodies":{
  "man":{"scene":"res://assets/people/bodies/man.glb","outfit":"man"},
  "woman":{"scene":"res://assets/people/bodies/woman.glb","outfit":"woman"},
  "boy":{"scene":"res://assets/people/bodies/boy.glb","outfit":"man","child":True},
  "girl":{"scene":"res://assets/people/bodies/girl.glb","outfit":"woman","child":True}
 },
 "items":I,"eras":eras,"units":units}
PROJECT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
json.dump(data,open(os.path.join(PROJECT,'data','human_outfits.json'),'w'),ensure_ascii=False,indent=1)
# kontroll
for e in eras:
    for b in ["man","woman"]:
        assert len(e[b])==5,(e["id"],b)
        for out in e[b]:
            slots={}
            for id in out["items"]:
                assert id in I,(e["id"],id); assert I[id]["slot"] not in slots,(e["id"],out["name"],id); slots[I[id]["slot"]]=1
        assert len(e["hair"][b])==5 and all(x in I for x in e["hair"][b])
    for x in e["beards"]: assert x=="" or x in I
    for j in e["jobs"].values():
        for id in j["all"]: assert id in I,id
for k,u in units.items():
    slots={}
    for id in u["items"]:
        assert id in I,(k,id); assert I[id]["slot"] not in slots,(k,id); slots[I[id]["slot"]]=1
print(len(I),"eset,",len(units),"väeliiki")
