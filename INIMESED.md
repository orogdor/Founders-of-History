# Inimesed: kehad, riided ja ajastud

Süsteem asub failides `scripts/human_factory.gd` (kehad, riided, tööriistad), `scripts/human_rig.gd` (luustiku sobitus) ja `data/human_outfits.json` (riidekomplektid). Kuni MPFB2 kehasid pole, kasutab mäng edasi vana mudelit `human_far.glb`; uued failid hakkavad kehtima kohe, kui need on õiges kohas.

## Failide asukohad

- Kehad: `assets/people/bodies/man.glb`, `woman.glb`, `boy.glb`, `girl.glb`
- Riided: `assets/people/clothes/<eseme_id>/<keha>.glb`, näiteks `clothes/iron_wool_tunic/woman.glb`
- Juuksed ja habe on samuti riided: `clothes/hair_braids/girl.glb`
- Tööriistad: `assets/people/equipment/<nimi>.glb` (nimed on JSON-i `tools` all, nt `bronze_axe`)

Kui mõne keha jaoks riidefail puudub, jäetakse see ese vahele ega peideta selle all olevat kehaosa.

## Keha eksport MPFB2-st (Blender)

1. Loo inimene MPFB2-ga. Laste jaoks vähenda vanust, nii et keha proportsioonid muutuvad.
2. Lisa luustik **Game engine**. Sama luustikutüüp peab olema kõigil neljal kehal.
3. Lõika kehavõrk tsoonideks ja anna objektidele nimed `body_head`, `body_neck`, `body_torso`, `body_hips`, `body_upperarms`, `body_forearms`, `body_hands`, `body_thighs`, `body_shins`, `body_feet`. Riided peidavad katvaid tsoone; ilma tükeldamiseta keha toimib ka, aga võib riietest läbi paista.
4. Ekspordi glTF Binary (.glb), +Y üles, meetrites, ainult keha ja luustik. Animatsioone pole vaja: mäng liigutab luid ise.

Mäng leiab luud levinud nimede järgi (MPFB/Unreal, Godoti humanoid, Mixamo, MakeHumani vaikeluustik). Kui mõni luu ei leia vastet, lisa JSON-is kehale `"bones": {"hand_R": "tegelik_nimi"}`. T- või A-asend pööratakse automaatselt käed-all asendiks.

## Riide eksport

1. Modelleeri riie MakeHumani baaskeha peal ja tee sellest MPFB2 riie (MakeClothes). Siis sobib see kõigile neljale kehale.
2. Pane riie igale kehale selga, kontrolli läbivust ja ekspordi iga keha kohta eraldi: ainult riidevõrk koos luustikuga, nahastatult.
3. Tekstuurid tee heledad või hallid: mäng värvib riiet JSON-i `tints` värvidega (looduslikud värvid: värvimata vill, madar, sinerõigas, ristirohi jne).
4. Kihid: aluspesu < särk < püksid < kuub < põll < vöö < keep < peakate. Ülemine kiht peab olema Blenderis kehast veidi kaugemal.

## Mängus kasutamine

```gdscript
const Humans=preload("res://scripts/human_factory.gd")
var person:=Humans.create("woman",era,"farm",seed)  # mees/naine/poiss/tüdruk
person.scale=Vector3.ONE*1.66
Humans.equip_job(person,"farm",era)   # ajastu tööriist kätte
Humans.set_era(person,era)            # igal kaadril; vahetab riided, kui ajastu muutus
```

Ühendatud on detailvaate töölised, ehitajad, õpetaja, kaubakandjad, asunik, asula elanikud (üks neist on laps) ning maailmal liikuvad asunikud (mees, naine ja laps) ja kaupmehed. Sõdurid kasutavad veel oma senist mudelit.

Test: `godot --headless --path . -s tests/human_outfits.gd`

## Proovivarad, tekstuurid ja näidispildid

`assets/people/bodies` sisaldab MPFB2 andmetest tehtud kehasid (mees 1,80 m, naine 1,61 m, poiss 1,30 m, tüdruk 1,21 m) ja `assets/people/clothes` automaatseid proovirõivaid kõigi ajastute riietele. Mõlemad tehakse skriptiga `tools/mpfb_bodies.py` (allikad: `assets/people/ALLIKAD.md`). Proovirõivas asendub päris riidega, kui sama nimega fail üle kirjutada.

Tekstuurid on kaustas `assets/people/textures` ja glb-failid viitavad neile (neid ei korrata igas failis):
- `skin_<keha>_albedo/normal/orm.png`: küpsetatud nahk MPFB2 maskidega (huuled, silmalaud, kõrvad, küüned), põsepuna, joonistatud kulmud, mehel habemetüü, poorid normaalkaardis.
- `<kangas>_albedo/normal/orm.png`: korduvad kangad (linane, villane, teksariie, trikoo, nahk, toornahk, õliriie, karusnahk, õled, juuksed, metall). Albedo on hall, mäng värvib riided JSON-i `tints` värvidega.
- Riietel on tipuvärvides varjud: voldid, kaenlaalused, jalgevahe ning vanematel ajastutel äärte mustus. `HumanFactory.tint()` lülitab tipuvärvid sisse.
- Importimisel on mipmapid ja VRAM-tihendus (ETC2/ASTC Androidile), normaalkaardid normaalkaardi režiimis.

## Animatsioonid

Liigutused tulevad mängu senisest protseduursest `HumanMotion`-ist; `HumanRig` kannab need 17 luu kaudu MPFB2 luustikule (kontrollitud: luude suunad ühtivad vana mudeliga täpsusega 0,01). Kõik mängus kasutatavad liigutused töötavad: seisab, kõnnib, kannab, raiub, kaevandab, ehitab, korjab, harib, püüab kala, jahib, hiilib, kannab vett, õpib, karjatab, istub, sööb, mängib, valvab, räägib, kaevab.

Pildid ja testid:
- `godot --path . --resolution 1600x900 -s tests/human_showcase.gd -- <kaust>` (üldvaade majaga; lisa `lähivaade` või `nägu`)
- `godot --path . --resolution 1600x900 -s tests/human_detail_workers.gd -- <kaust>` (detailvaate töölised, ajastu vahetus)
- `godot --path . --resolution 1600x900 -s tests/human_animations.gd -- <kaust>` (kõik liigutused)

Ilma graafikata (`--headless`) testid kontrollivad sama, kuid pilte ei salvesta.

## Ajastute riidekomplektid

Poiss kannab mehe ja tüdruk naise komplekti, aga ilma ehete, vöö ja põlleta. Valikud valitakse iga inimese jaoks püsivalt tema võtme järgi.

### Kiviaeg

- **Mees:** Nahkne niudevöö (`stone_hide_loincloth`), Nahkne kuub (`stone_hide_tunic`), Nahksäärised (`stone_hide_leggings`), Nahkkingad (mokassiinid) (`stone_moccasins`). Valikud: üleriie: ilma / Karusnahkne keep; ehe: ilma / Merevaigust ja hambaripatsitega kaelakee
- **Naine:** Pikk nahkkleit (`stone_hide_dress`), Nahksäärised (`stone_hide_leggings`), Nahkkingad (mokassiinid) (`stone_moccasins`), Merevaigust ja hambaripatsitega kaelakee (`stone_amber_necklace`). Valikud: üleriie: ilma / Karusnahkne keep
- **Ametite lisad:** hunter: Karusnahkne kapuuts, Karusnahkne keep

### Pronksiaeg

- **Mees:** Villane mähisrõivas (`bronze_wool_wrap`), Nahkkingad (`bronze_leather_shoes`). Valikud: üleriie: ilma / Ümar villane keep; peakate: ilma / Villane vildikübar
- **Naine:** Lühikeste varrukatega villane pluus (`bronze_wool_blouse`), Pronksist vööketas (`bronze_belt_disc`), Nahkkingad (`bronze_leather_shoes`). Valikud: alakeha: Nööriseelik / Pikk villane seelik; peakate: ilma / Juuksevõrk; ehe: ilma / Pronksist kaelavõru
- **Ametite lisad:** bronze_foundry: Nahkpõll

### Rauaaeg

- **Mees:** Linane särk (`iron_linen_shirt`), Villased püksid (`iron_wool_trousers`), Villane kuub (`iron_wool_tunic`), Pastlad ja säärepaelad (`iron_pastlad`), Vöö ja nuga (`iron_belt_knife`). Valikud: üleriie: ilma / Mantel hoburaudsõlega
- **Naine:** Pikk linane särk (`iron_linen_shift`), Villane vaipseelik (`iron_wool_skirt`), Pastlad ja säärepaelad (`iron_pastlad`), Kaelavõru ja rinnalehed (`iron_breast_ornaments`). Valikud: üleriie: ilma / Õlarätt (sõba); peakate: Pronksspiraalidega peapael / ilma
- **Ametite lisad:** smith: Nahkpõll; smelter: Nahkpõll

### Keskaeg

- **Mees:** Linane särk (`med_linen_shirt`), Villased sukkpüksid (`med_wool_hose`), Põlvini villane kuub (`med_wool_cote`), Pöördkingad (`med_turnshoes`), Vöö ja kukkur (`med_belt_pouch`). Valikud: peakate: ilma / Kapuuts õlakattega
- **Naine:** Linane alussärk (`med_linen_chemise`), Pikk villane kleit (`med_wool_kirtle`), Pöördkingad (`med_turnshoes`). Valikud: peakate: Linane peakate / ilma; põll: Põll / ilma; üleriie: ilma / Villane mantel
- **Ametite lisad:** farm: Õlgkübar; smith: Nahkpõll

### Renessanss

- **Mees:** Krae ja kurrutatud kätistega särk (`ren_shirt`), Vamss (`ren_doublet`), Pluuderpüksid (`ren_breeches`), Villased sukad (`ren_stockings`), Nahkkingad (`ren_shoes`). Valikud: peakate: ilma / Barett
- **Naine:** Linane särk (`ren_smock`), Liibuga kleit (`ren_bodice_gown`), Nahkkingad (`ren_shoes`). Valikud: peakate: Tanu / ilma; põll: Põll / ilma; üleriie: ilma / Õlarätt
- **Ametite lisad:** farm: Õlgkübar; smith: Nahkpõll; printer: Nahkpõll

### Tööstusajastu

- **Mees:** Puuvillane särk (`ind_cotton_shirt`), Villased püksid traksidega (`ind_trousers_braces`), Säärsaapad (`ind_boots`). Valikud: kuub: Vest / ilma; üleriie: ilma / Villane pintsak; peakate: Nokamüts / ilma
- **Naine:** Pikkade varrukatega pluus (`ind_blouse`), Pikk seelik (`ind_long_skirt`), Säärsaapad (`ind_boots`). Valikud: peakate: Pearätt / ilma; põll: Põll / ilma; üleriie: ilma / Villane suurrätt
- **Ametite lisad:** fisher: Õlirõivast vihmamantel; farm: Õlgkübar; steelworks: Nahkpõll

### Moodne ajastu

- **Mees:** T-särk (`mod_tshirt`), Teksapüksid (`mod_jeans`), Spordijalatsid (`mod_sneakers`). Valikud: üleriie: ilma / Jope; peakate: ilma / Nokkmüts
- **Naine:** Kingad (`mod_shoes`). Valikud: särk: T-särk / Pluus; alakeha: Teksapüksid / Põlvepikkune seelik; üleriie: ilma / Jope
- **Ametite lisad:** builder: Kiiver, Helkurvest; mine: Kiiver; autofactory: Tunked; refinery: Tunked, Kiiver
