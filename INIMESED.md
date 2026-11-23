# Inimesed: kehad, riided ja ajastud

Süsteem asub failides `scripts/human_factory.gd` (kehad, riided, tööriistad), `scripts/human_rig.gd` (luustiku sobitus) ja `data/human_outfits.json` (riidekomplektid). Kuni MPFB2 kehasid pole, kasutab mäng edasi vana mudelit `human_far.glb`; uued failid hakkavad kehtima kohe, kui need on õiges kohas.

## Failide asukohad

- Kehad: `assets/people/bodies/man.glb`, `woman.glb`, `boy.glb`, `girl.glb`
- Riided: `assets/people/clothes/<eseme_id>/<keha>.glb`, näiteks `clothes/iron_wool_tunic/woman.glb`
- Soengud, habemed ja peakatted on samuti riided: `clothes/hair_w_braids2/woman.glb`, `clothes/beard_full/man.glb`
- Sõdurite relvad, kilbid ja hobused: `assets/soldiers/split/<väeliik>.glb` (vt „Sõdurid”)
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

Ühendatud on detailvaate töölised, ehitajad, õpetaja, kaubakandjad, asunik, asula elanikud (üks neist on laps), maailmal liikuvad asunikud (mees, naine ja laps) ja kaupmehed ning lahingu ja detailvaate sõdurid.

Test: `godot --headless --path . -s tests/human_outfits.gd`

## Proovivarad, tekstuurid ja näidispildid

`assets/people/bodies` sisaldab MPFB2 andmetest tehtud kehasid (mees 1,80 m, naine 1,61 m, poiss 1,30 m, tüdruk 1,21 m) ja `assets/people/clothes` automaatseid proovirõivaid kõigi ajastute riietele. Riiete ja väeliikide nimekiri tehakse skriptiga `tools/outfits.py` (`data/human_outfits.json`), kehad, rõivad ja tekstuurid skriptiga `tools/mpfb_bodies.py` (allikad ja käsud: `assets/people/ALLIKAD.md`). Proovirõivas asendub päris riidega, kui sama nimega fail üle kirjutada.

Tekstuurid on kaustas `assets/people/textures` ja glb-failid viitavad neile (neid ei korrata igas failis):
- `skin_<keha>_albedo/normal/orm.png`: küpsetatud nahk MPFB2 maskidega (huuled, silmalaud, kõrvad, küüned), põsepuna, joonistatud kulmud, mehel habemetüü, poorid normaalkaardis.
- `<kangas>_albedo/normal/orm.png`: korduvad kangad 1024×1024 (varem 512): linane, villane, toimne, kalasaba, ruuduline, triibuline, brokaat, kudum, vilt, tepitud, teksariie, trikoo, nahk, toornahk, õliriie, karusnahk, õled, juuksed, punutud juuksed, metall, rõngasrüü, plaatrüü ja laiguline välivorm. Albedo on hall (välivormil värviline), mäng värvib riided JSON-i `tints` värvidega.
- Riietel on tipuvärvides varjud: voldid, kaenlaalused, jalgevahe ning vanematel ajastutel äärte mustus. `HumanFactory.tint()` lülitab tipuvärvid sisse.
- Importimisel on mipmapid ja VRAM-tihendus (ETC2/ASTC Androidile), normaalkaardid normaalkaardi režiimis.

## Animatsioonid

Liigutused tulevad Quaternius Universal Animation Library 1 ja 2 teegist (CC0, 49 klippi: seismine, kõnd, jooks, hiilimine, kandmine, istumine, kükitamine, rääkimine, puu raiumine, saagi korjamine, külvamine, kastmine, viskamine, söömine, tantsimine, mõõgavõitlus, kilp, tulirelv, tabamus, surm jne). `tools/retarget_ual.py` kannab need iga keha luustikule üle (`assets/people/animations/<keha>.glb`):

- iga luu maailmapöörde muutus allika puhkeasendi suhtes kantakse MPFB2 luule, mille puhkeasend pööratakse enne allika omaga samaks (luu suund ja teine telg, nt peopesa põiki); sõrmed tulevad kaasa;
- puusa nihe skaleeritakse puusa kõrguste suhtega;
- seisuasendites tuuakse jalad lähemale ja pannakse maapinnale (allika „valmis” asend on laiade jalgadega).

Mängus lisab `HumanFactory.create` igale uuele inimesele AnimationPlayeri ja `HumanMotion.apply` valib klipi tegevuse järgi (`scripts/human_clips.gd`, tabel `WORK`), teeb sujuva ülemineku ja liigutab aega mänguaja järgi (paus peatab). Sama tegevusega inimesed ei liigu ühes taktis ja seisjatel on eri seisuasendid. Tööriist on rusikas (`HumanRig.grip_frame`): vars läheb väikese sõrme poolt pöidla poole ja kirve pea kaldub löögi suunas.

| Tegevus | Klipp |
|---|---|
| seisab | idle / idle_arms (käed rinnal) / idle_no |
| kõnnib, kannab | walk, walk_carry; lapsed vahel jog |
| raiub, sepistab, kaevandab | chop (TreeChopping) |
| ehitab | fix_kneel / interact |
| korjab, kaevab | harvest |
| harib, külvab | plant / harvest |
| kannab vett | water |
| püüab kala, karjatab | hold_up (ritv või kepp ees) |
| jahib | throw |
| õpib, räägib | talk |
| istub | crouch (kükitab) |
| sööb | eat |
| mängib | dance |
| valvab | idle_arms |
| hiilib | sneak / crouch |
| harjutab (sõdur) | sword_a / sword_b / sword_c / sword_attack |

Sõdurite jalad (sammud, labajalad, seisuasend) tulevad samast teegist, ülakeha ja relvad sõduri enda liigutusest, et relv jääks kätte (test: käsi relvakäest alla 0,22 m). Ratsanikel jääb senine liigutus. Seelikud on reite küljes pehmemalt, et kükitades ei paisuks.

Pildid ja testid:
- `godot --path . --resolution 1600x900 -s tests/human_showcase.gd -- <kaust>` (üldvaade majaga; lisa `lähivaade` või `nägu`)
- `godot --path . --resolution 1600x900 -s tests/human_detail_workers.gd -- <kaust>` (detailvaate töölised, ajastu vahetus)
- `godot --path . --resolution 1600x900 -s tests/human_animations.gd -- <kaust>` (kõik liigutused)
- `godot --path . --resolution 1600x900 -s tests/human_hair_showcase.gd -- <kaust>` (kõik soengud ja habemed, `soengud.png`)
- `godot --path . --resolution 1600x900 -s tests/human_outfits_showcase.gd -- <kaust>` (iga ajastu 5 mehe ja 5 naise riietust, `riietused_<ajastu>.png`)
- `godot --path . --resolution 1600x900 -s tests/human_soldiers.gd -- <kaust>` (kõik väeliigid, käte asukoha kontroll, `sodurid.png`)

Ilma graafikata (`--headless`) testid kontrollivad sama, kuid pilte ei salvesta.

## Riiete langemine

Rõivad ei kleepu kehale: `tools/mpfb_bodies.py` (`drape`) täidab abivõrgu nõgusad kohad (rinna vahe, selja nõgusus, kõhulihaste vaod, jalgevahe) kuni 2,5 cm ulatuses ja kõik kihid tehakse sellelt samalt pinnalt, nii et kihid (särk, kuub, vöö, põll) ei lõika üksteisest läbi. Riiete servad (kaelus, varrukaotsad, alläär) silutakse piki serva, et need ei oleks sakilised. Püksisääred on lahedamad kui säärised ja sukad, saapasäärte all kitsamad. Heledatel kangastel pole suuri laike. Inimestel on veidi erinev nahatoon (`HumanFactory.tint_skin`).

## Soengud ja habemed

Soengud tehakse skriptiga `tools/hair.py` pea kuju järgi: peanahk kindla juustejoonega (laup, oimud, kukal), pikad juuksed paksusega kihina, mille otsad on salkudena läbipaistvad (`hairlock` tekstuur alfaga), patsid kolmest keerduvast salgust, hobusesabad, nutsud ning pärjapats. Lokkis soengutel on pinnal lokid; polkpea otsad keeravad sisse. Habemed (lühike, täis-, pikk, vuntsid, kitsehabe) tehakse näo piirkondadest ja huuled jäetakse vabaks. Juuste värv on inimesel ühine (soeng + habe), värvid on JSON-i `hair_colors` all.

## Sõdurid

`HumanFactory.dress_soldier(model, kind, team, seed, scale)` paneb lahingu sõdurimudelile uue inimese, kellel on väeliigi riided (`units` JSON-is) ja tiimivärv. Iga kaader kannab `follow_soldier(model)` sõduri luustiku asendi uuele inimesele, nii et relv jääb kätte (test kontrollib, et käsi on relvakäest alla 0,22 m).

- Sõdurimudelid on skriptiga `tools/split_soldiers.py` jagatud kaheks võrguks: `SoldierBody` (vana keha) ja `SoldierGear` (relvad, kilbid, hobune). Lähedal (alla 40 m) on näha uus inimene + `SoldierGear`, kaugemal vana keha (LOD), mis hoiab suure armee kiire.
- Riietatud on 28 väeliiki 37-st. Masinamudelitega väeliigid (sõjavanker, müürilõhkuja, piiramistorn, katapult, väli- ja vintraudne suurtükk, kuulipilduja- ja tankitõrjerühm, motoriseeritud jalavägi) kasutavad veel oma senist meeskonda.

## Ajastute riidekomplektid, soengud ja habemed

Igal ajastul on 5 riietust mehele ja 5 naisele, 5 soengut kummalegi ning habemete valik (tühi kirje tähendab habemeta meest, nii et habe on ainult osal meestel). Valik tehakse inimese seemne järgi püsivalt. Poiss kannab mehe ja tüdruk naise riietust, aga ilma `drop` kohtadeta (ehted, vöö, põll jne).

### Kiviaeg

- **Mees:**
  - Nahkriided: Nahkne niudevöö, Nahkne kuub, Nahksäärised, Nahkkingad (mokassiinid)
  - Talveriided: Nahkne niudevöö, Nahkne kuub, Nahksäärised, Nahkkingad (mokassiinid), Karusnahkne keep
  - Karusnahkne vest: Nahkne niudevöö, Karusnahkne vest, Nahksäärised, Nahkkingad (mokassiinid), Merevaigust ja hambaripatsitega kaelakee
  - Säärsaabastega: Nahkne niudevöö, Nahkne kuub, Nahksäärised, Karusnahksed säärsaapad, Karusnahkne õlakate
  - Suveriided: Nahkne niudevöö, Nahkne põll-seelik, Karusnahkne õlakate, Nahkkingad (mokassiinid)
- **Naine:**
  - Nahkkleit: Pikk nahkkleit, Nahksäärised, Nahkkingad (mokassiinid), Merevaigust ja hambaripatsitega kaelakee
  - Talvekleit: Pikk nahkkleit, Nahksäärised, Nahkkingad (mokassiinid), Karusnahkne keep
  - Seelik ja vest: Pikk nahkseelik, Karusnahkne vest, Nahkkingad (mokassiinid), Merevaigust ja hambaripatsitega kaelakee
  - Karusnahaga: Pikk nahkkleit, Karusnahksed säärsaapad, Karusnahkne õlakate
  - Niinseelik: Niinest seelik, Nahkne pluus, Nahksäärised, Nahkkingad (mokassiinid), Merevaigust ja hambaripatsitega kaelakee
- **Soengud:** mees: Pikk sasitud, Õlgadeni juuksed, Pats seljal, Kuklas hobusesaba, Lühike lõikus; naine: Pikad lahtised, Kaks patsi ees, Pats seljal, Kuklanuts, Lokkis õlgadeni
- **Habemed:** Pikk habe, Täishabe, Lühike habe (habe on umbes 60% meestest)
- **Ametite lisad:** hunter: Karusnahkne kapuuts, Karusnahkne keep

### Pronksiaeg

- **Mees:**
  - Mähisrõivas: Villane mähisrõivas, Ümar villane keep, Villane vildikübar, Nahkkingad
  - Lühike kuub: Lühike villane kuub, Nahkvöö pronkspandlaga, Nahkkingad
  - Mähis ja kaelavõru: Villane mähisrõivas, Nahkkingad, Pronksist kaelavõru
  - Põlvseelik ja keep: Villane põlvseelik, Ümar villane keep, Nahkvöö pronkspandlaga, Nahkkingad
  - Kuub ja keep: Lühike villane kuub, Ümar villane keep, Villane vildikübar, Nahkkingad
- **Naine:**
  - Nööriseelik: Lühikeste varrukatega villane pluus, Nööriseelik, Pronksist vööketas, Nahkkingad, Pronksist kaelavõru
  - Pikk seelik: Lühikeste varrukatega villane pluus, Pikk villane seelik, Pronksist vööketas, Nahkkingad
  - Õlarätiga: Lühikeste varrukatega villane pluus, Pikk villane seelik, Villane õlarätt, Nahkkingad, Juuksevõrk
  - Villane kleit: Pikk villane kleit, Pronksist vööketas, Ümar villane keep, Nahkkingad
  - Nööriseelik ja keep: Lühikeste varrukatega villane pluus, Nööriseelik, Ümar villane keep, Nahkkingad
- **Soengud:** mees: Õlgadeni juuksed, Kuklas hobusesaba, Lühike lõikus, Pats seljal, Pikk sasitud; naine: Kõrge nuts, Kuklanuts, Pikad lahtised, Kõrge hobusesaba, Kaks patsi ees
- **Habemed:** Täishabe, Lühike habe, Pikk habe (habe on umbes 60% meestest)
- **Ametite lisad:** bronze_foundry: Nahkpõll

### Rauaaeg

- **Mees:**
  - Kuub ja püksid: Linane särk, Villased püksid, Villane kuub, Pastlad ja säärepaelad, Vöö ja nuga
  - Mantliga: Linane särk, Villased püksid, Villane kuub, Pastlad ja säärepaelad, Vöö ja nuga, Mantel hoburaudsõlega
  - Ruuduline kuub: Linane särk, Kalasabakoes püksid, Ruuduline villane kuub, Pastlad ja säärepaelad, Vöö ja nuga
  - Talveriided: Linane särk, Villased püksid, Villane kuub, Pastlad ja säärepaelad, Mantel hoburaudsõlega, Villane müts
  - Pidulik: Linane särk, Kalasabakoes püksid, Villane kuub, Pastlad ja säärepaelad, Vöö ja nuga, Keerdkaelavõru
- **Naine:**
  - Vaipseelik: Pikk linane särk, Villane vaipseelik, Pastlad ja säärepaelad, Kaelavõru ja rinnalehed
  - Sõbaga: Pikk linane särk, Villane vaipseelik, Õlarätt (sõba), Pastlad ja säärepaelad, Kaelavõru ja rinnalehed
  - Peplos: Pikk linane särk, Villane peplos-kleit, Pastlad ja säärepaelad, Kaelavõru ja rinnalehed
  - Triibuline seelik: Pikk linane särk, Triibuline villane seelik, Õlarätt (sõba), Pastlad ja säärepaelad
  - Ruuduline seelik ja põll: Pikk linane särk, Ruuduline vaipseelik, Linane põll, Pastlad ja säärepaelad, Pronksspiraalidega peapael
- **Soengud:** mees: Suebi sõlm, Õlgadeni juuksed, Lühike lõikus, Kuklas hobusesaba, Potisoeng; naine: Pats seljal, Kaks patsi ees, Kuklanuts, Pärjapats, Pikad lahtised
- **Habemed:** Täishabe, Vuntsid, Pikk habe (habe on umbes 60% meestest)
- **Ametite lisad:** smith: Nahkpõll; smelter: Nahkpõll

### Keskaeg

- **Mees:**
  - Põlvini kuub: Linane särk, Villased sukkpüksid, Põlvini villane kuub, Pöördkingad, Vöö ja kukkur
  - Kapuutsiga: Linane särk, Villased sukkpüksid, Põlvini villane kuub, Pöördkingad, Vöö ja kukkur, Kapuuts õlakattega
  - Pealiskuub: Linane särk, Villased sukkpüksid, Põlvini villane kuub, Varrukateta pealiskuub, Pöördkingad
  - Lühike kuub ja saapad: Linane särk, Villased sukkpüksid, Lühike villane kuub, Villane mantel, Nahksaapad, Vöö ja kukkur
  - Pikk rüü: Linane särk, Pikk villane rüü, Vöö ja kukkur, Pöördkingad
- **Naine:**
  - Villane kleit: Linane alussärk, Pikk villane kleit, Pöördkingad
  - Põll ja peakate: Linane alussärk, Pikk villane kleit, Põll, Linane peakate, Pöördkingad
  - Pealiskleit: Linane alussärk, Pikk villane kleit, Varrukateta pealiskleit, Pöördkingad
  - Mantliga: Linane alussärk, Pikk villane kleit, Villane mantel, Linane peakate, Pöördkingad
  - Triibuline kleit: Linane alussärk, Triibuline villane kleit, Põll, Pöördkingad
- **Soengud:** mees: Potisoeng, Lühike lõikus, Lõuani polkpea, Õlgadeni juuksed, Siilisoeng; naine: Kaks patsi ees, Pats seljal, Pärjapats, Kuklanuts, Pikad lahtised
- **Habemed:** Lühike habe, Täishabe (habe on umbes 33% meestest)
- **Ametite lisad:** farm: Õlgkübar; smith: Nahkpõll

### Renessanss

- **Mees:**
  - Vamss ja barett: Krae ja kurrutatud kätistega särk, Vamss, Pluuderpüksid, Villased sukad, Nahkkingad, Barett
  - Brokaatvamss: Krae ja kurrutatud kätistega särk, Brokaatvamss, Pluuderpüksid, Villased sukad, Nahkkingad
  - Nahkvest: Krae ja kurrutatud kätistega särk, Vamss, Nahkvest, Pluuderpüksid, Villased sukad, Nahkkingad
  - Pikk kuub: Krae ja kurrutatud kätistega särk, Vamss, Põlvini kuub, Pluuderpüksid, Villased sukad, Nahkkingad, Barett
  - Tööriided: Krae ja kurrutatud kätistega särk, Nahkvest, Laiad püksid, Säärsaapad
- **Naine:**
  - Liibuga kleit ja tanu: Linane särk, Liibuga kleit, Põll, Tanu, Nahkkingad
  - Brokaatkleit: Linane särk, Brokaatkleit, Nahkkingad
  - Triibuline seelik: Linane särk, Liivik, Triibuline seelik, Põll, Nahkkingad
  - Õlarätiga: Linane särk, Liibuga kleit, Õlarätt, Tanu, Nahkkingad
  - Liivik ja seelik: Linane särk, Liivik, Pikk seelik, Õlarätt, Nahkkingad
- **Soengud:** mees: Lõuani polkpea, Lühike lõikus, Külgkammiga lühike, Õlgadeni juuksed, Siilisoeng; naine: Kuklanuts, Pärjapats, Pats seljal, Kõrge nuts, Kaks patsi ees
- **Habemed:** Kitsehabe, Vuntsid, Täishabe (habe on umbes 60% meestest)
- **Ametite lisad:** farm: Õlgkübar; smith: Nahkpõll; printer: Nahkpõll

### Tööstusajastu

- **Mees:**
  - Traksidega: Puuvillane särk, Villased püksid traksidega, Säärsaapad, Nokamüts
  - Vest ja pintsak: Puuvillane särk, Vest, Villased püksid traksidega, Villane pintsak, Säärsaapad
  - Kampsun: Puuvillane särk, Kootud kampsun, Villased püksid traksidega, Säärsaapad, Nokamüts
  - Mantel ja kõvakübar: Puuvillane särk, Vest, Pikk mantel, Villased püksid traksidega, Säärsaapad, Kõvakübar
  - Tööpõll: Puuvillane särk, Villased püksid traksidega, Nahkpõll, Säärsaapad
- **Naine:**
  - Pearätt ja põll: Pikkade varrukatega pluus, Pikk seelik, Põll, Pearätt, Säärsaapad
  - Triibuline rahvaseelik: Pikkade varrukatega pluus, Triibuline rahvaseelik, Põll, Pearätt, Säärsaapad
  - Suurrätiga: Pikkade varrukatega pluus, Pikk seelik, Villane suurrätt, Säärsaapad
  - Pikk kleit: Pikk kleit, Põll, Säärsaapad
  - Ruuduline seelik ja jakk: Pikkade varrukatega pluus, Ruuduline seelik, Kootud jakk, Säärsaapad
- **Soengud:** mees: Tahapoole kammitud, Külgkammiga lühike, Lühike lõikus, Siilisoeng, Lokkis lühike; naine: Kuklanuts, Kõrge nuts, Pats seljal, Pärjapats, Kõrge hobusesaba
- **Habemed:** Vuntsid, Täishabe, Lühike habe (habe on umbes 60% meestest)
- **Ametite lisad:** fisher: Õlirõivast vihmamantel; farm: Õlgkübar; steelworks: Nahkpõll

### Moodne ajastu

- **Mees:**
  - T-särk ja teksad: T-särk, Teksapüksid, Spordijalatsid
  - Jopega: T-särk, Teksapüksid, Jope, Spordijalatsid
  - Kampsun: Kootud kampsun, Riidest püksid, Kingad
  - Särk ja püksid: Nööpidega särk, Riidest püksid, Kingad
  - Dressipluus: T-särk, Kapuutsiga dressipluus, Teksapüksid, Spordijalatsid, Nokkmüts
- **Naine:**
  - Pluus ja teksad: Pluus, Teksapüksid, Kingad
  - T-särk ja seelik: T-särk, Põlvepikkune seelik, Spordijalatsid
  - Kampsun: Kootud kampsun, Teksapüksid, Kingad
  - Kleit: Põlvini kleit, Kingad
  - Jopega: T-särk, Teksapüksid, Jope, Spordijalatsid
- **Soengud:** mees: Külgkammiga lühike, Siilisoeng, Lühike lõikus, Tahapoole kammitud, Pealae nuts; naine: Kõrge hobusesaba, Polkpea tukaga, Lühike poisipea, Pikad lahtised, Lokkis õlgadeni
- **Habemed:** Lühike habe, Täishabe (habe on umbes 33% meestest)
- **Ametite lisad:** builder: Kiiver, Helkurvest; mine: Kiiver; autofactory: Tunked; refinery: Tunked, Kiiver

## Väeliikide riietus ja varustus

`units` seob iga väeliigi ajastu ja esemetega. Tiimivärviga esemed (vöörätt, käeside, kuub, varrukad) värvitakse mängija värviga. Soeng ja habe tulevad selle ajastu valikust. Relvad, kilbid ja hobune jäävad sõduri senisest mudelist (`SoldierGear`).

| Väeliik | Ajastu | Riietus ja varustus |
|---|---|---|
| Avastaja (`scout`) | Kiviaeg | Nahkne niudevöö, Nahkne kuub, Nahksäärised, Nahkkingad (mokassiinid), Karusnahkne kapuuts, Vägede värvi vööpael |
| Linna kaitsjad (`militia`) | Kiviaeg | Nahkne niudevöö, Nahkne kuub, Nahksäärised, Nahkkingad (mokassiinid), Vägede värvi vööpael |
| Tornikaitsja (`stone_guard`) | Kiviaeg | Nahkne niudevöö, Paksust nahast rüü, Nahksäärised, Karusnahksed säärsaapad, Vägede värvi vööpael |
| Kiviviskajad (`slinger`) | Kiviaeg | Nahkne niudevöö, Nahkne kuub, Nahksäärised, Nahkkingad (mokassiinid), Vägede värvi vööpael |
| Puuodamehed (`spearman`) | Kiviaeg | Nahkne niudevöö, Karusnahkne vest, Nahksäärised, Nahkkingad (mokassiinid), Karusnahkne õlakate, Vägede värvi vööpael |
| Kivikirvemehed (`axeman`) | Kiviaeg | Nahkne niudevöö, Paksust nahast rüü, Nahksäärised, Karusnahksed säärsaapad, Vägede värvi vööpael |
| Vibukütid (`archer`) | Kiviaeg | Nahkne niudevöö, Nahkne kuub, Nahksäärised, Nahkkingad (mokassiinid), Vägede värvi vööpael |
| Pronksodamees (`bronze_spearman`) | Pronksiaeg | Vägede värvi kuub, Pronksist rinnaturvis, Villane põlvseelik, Nahkkingad, Pronkskiiver |
| Pronkskirvemees (`bronze_axeman`) | Pronksiaeg | Vägede värvi kuub, Nahkrinnaturvis, Nahkkingad, Pronkskiiver |
| Pronksiaja vibukütt (`bronze_archer`) | Pronksiaeg | Vägede värvi kuub, Nahkkingad, Nahkvöö pronkspandlaga, Villane vildikübar |
| Sõjavanker (`chariot`) | Pronksiaeg | Vägede värvi kuub, Pronksist rinnaturvis, Nahkkingad, Pronkskiiver |
| Varajane ratsavägi (vana üksus) (`bronze_cavalry`) | Rauaaeg | Vägede värvi kuub, Nahkrinnaturvis, Villased püksid, Pastlad ja säärepaelad, Pronkskiiver |
| Raudmõõgamehed (`infantry`) | Rauaaeg | Linane särk, Vägede värvi kuub, Rõngassärk, Villased püksid, Pastlad ja säärepaelad, Spangenhelm |
| Ratsavägi (`cavalry`) | Rauaaeg | Linane särk, Vägede värvi kuub, Rõngassärk, Villased püksid, Pastlad ja säärepaelad, Spangenhelm, Mantel hoburaudsõlega |
| Rauaaja vibukütt (`iron_archer`) | Rauaaeg | Linane särk, Vägede värvi kuub, Villased püksid, Pastlad ja säärepaelad, Vöö ja nuga, Villane müts |
| Heiteodamees (`javelinman`) | Rauaaeg | Linane särk, Vägede värvi kuub, Villased püksid, Pastlad ja säärepaelad, Nahkrinnaturvis |
| Müürilõhkuja (`battering_ram`) | Rauaaeg | Linane särk, Vägede värvi kuub, Villased püksid, Pastlad ja säärepaelad |
| Piiramistorn (`siege_tower`) | Rauaaeg | Linane särk, Vägede värvi kuub, Villased püksid, Pastlad ja säärepaelad |
| Rüütel (`knight`) | Keskaeg | Linane särk, Pikk rõngasrüü, Vapikuub, Jalasoomus, Nahksaapad, Suurkiiver |
| Raskeratsavägi (`heavy_cavalry`) | Keskaeg | Linane särk, Pikk rõngasrüü, Plaatrinnaturvis, Vapikuub, Jalasoomus, Nahksaapad, Suurkiiver |
| Soomustatud jalaväelane (`man_at_arms`) | Keskaeg | Linane särk, Vatitikkimisega kuub, Rõngassärk, Vapikuub, Villased sukkpüksid, Nahksaapad, Rauast kübarkiiver |
| Hellebardimees (`halberdier`) | Keskaeg | Linane särk, Vatitikkimisega kuub, Vapikuub, Villased sukkpüksid, Nahksaapad, Rauast kübarkiiver |
| Ristvibumees (`crossbowman`) | Keskaeg | Linane särk, Vatitikkimisega kuub, Vapikuub, Villased sukkpüksid, Nahksaapad, Rauast kübarkiiver |
| Katapult (`catapult`) | Keskaeg | Linane särk, Lühike villane kuub, Vägede värvi vööpael, Villased sukkpüksid, Nahksaapad |
| Piigimees (`pikeman`) | Renessanss | Krae ja kurrutatud kätistega särk, Vägede värvi vamss, Plaatrinnaturvis, Pluuderpüksid, Villased sukad, Nahkkingad, Morion-kiiver |
| Musketärid (`musketeer`) | Renessanss | Krae ja kurrutatud kätistega särk, Vägede värvi vamss, Pluuderpüksid, Villased sukad, Säärsaapad, Laia äärega viltkübar, Ristirihmad |
| Arkebuusimees (`arquebusier`) | Renessanss | Krae ja kurrutatud kätistega särk, Vägede värvi vamss, Pluuderpüksid, Villased sukad, Nahkkingad, Morion-kiiver |
| Kürassiir (`cuirassier`) | Renessanss | Krae ja kurrutatud kätistega särk, Vägede värvi vamss, Plaatrinnaturvis, Käesoomus, Pluuderpüksid, Säärsaapad, Morion-kiiver |
| Välisuurtükk (`field_cannon`) | Renessanss | Krae ja kurrutatud kätistega särk, Vägede värvi vamss, Pluuderpüksid, Villased sukad, Nahkkingad, Laia äärega viltkübar |
| Püssimehed (`rifleman`) | Tööstusajastu | Puuvillane särk, Vormikuub, Valged vormipüksid, Sõjaväesaapad, Šako, Ristirihmad |
| Rivijalavägi (`line_infantry`) | Tööstusajastu | Puuvillane särk, Vormikuub, Valged vormipüksid, Sõjaväesaapad, Šako, Ristirihmad |
| Ratsalaskur (`dragoon`) | Tööstusajastu | Puuvillane särk, Vormikuub, Valged vormipüksid, Sõjaväesaapad, Vormimüts |
| Vintraudne suurtükk (`industrial_artillery`) | Tööstusajastu | Puuvillane särk, Vormikuub, Villased püksid traksidega, Sõjaväesaapad, Vormimüts |
| Moodne jalavägi (`modern_infantry`) | Moodne ajastu | T-särk, Laigulise mustriga välivormi jope, Laigulise mustriga välivormi püksid, Sõjaväesaapad, Lahingukiiver, Kuulivest, Vägede värvi käepael |
| Kuulipildujameeskond (`machinegun_team`) | Moodne ajastu | T-särk, Laigulise mustriga välivormi jope, Laigulise mustriga välivormi püksid, Sõjaväesaapad, Lahingukiiver, Kuulivest, Vägede värvi käepael |
| Tankitõrjerühm (`rocket_team`) | Moodne ajastu | T-särk, Laigulise mustriga välivormi jope, Laigulise mustriga välivormi püksid, Sõjaväesaapad, Lahingukiiver, Kuulivest, Vägede värvi käepael |
| Motoriseeritud jalavägi (`motorized`) | Moodne ajastu | T-särk, Laigulise mustriga välivormi jope, Laigulise mustriga välivormi püksid, Sõjaväesaapad, Lahingukiiver, Vägede värvi käepael |
