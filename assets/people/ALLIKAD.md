# Inimeste varade allikad

- `bodies/*.glb`: MakeHumani/MPFB2 baaskeha (hm08), makro-sihtkujud (sugu, vanus, rass), MPFB2 `game_engine` luustik ja kaalud. Allikas: github.com/makehumancommunity/mpfb2, CC0.
- Silmad: MakeHumani `high-poly` silmad ja `brown_eye.png`. Allikas: github.com/makehumancommunity/makehuman, CC0.
- `clothes/*/*.glb`: **automaatsed proovirõivad**, mis on tehtud skriptiga `tools/mpfb_bodies.py` MakeHumani abivõrkudest (`helper-tights`, `helper-skirt`, `helper-hair`) ja kehapinnast. Need on ajutised ja tuleb asendada päris MPFB2 riietega (vt `INIMESED.md`).
- Soengud ja habemed (`clothes/mh_*`), kulmud ja ripsmed (kehade failides) ning nende tekstuurid (`textures/mh_*`): MakeHumani CC0 varad, mis on üle kantud skriptiga `tools/mh_hair.py`. Allikas: https://github.com/Makehuman-2/MH2_Asset_Repository_CCO väljalase „CC0”: `hm08-mh_system_CC0.zip` (MakeHumani süsteemi soengud, kulmud, ripsmed; CC0 alates 2020, Data Collection AB, Joel Palmius, Jonas Hauquier), `legacy-community_hair_pack1_CC0.zip` (kogukonna soengud, CC0) ja `hm08-RP_Viking_set_CC0.zip` (Rehman Polanski viikingi soeng, habe ja vuntsid, CC0). Tekstuurid on muudetud halliks ja vähendatud 1024 pikslini.
- Kiivrite ja mütside kujud: tehtud skriptiga `tools/hair.py` sama keha pinnast.
- `../soldiers/split/*.glb`: mängu olemasolevad sõdurimudelid, mille `tools/split_soldiers.py` on jaganud kehaks ja varustuseks; uut sisu pole lisatud.
- `textures/`: kangaste ja naha tekstuurid on tehtud protseduuriliselt skriptiga `tools/textures.py`; nahk kasutab MPFB2 CC0 maske (`mpfb_lips`, `mpfb_eyelids`, `mpfb_ears`, `mpfb_fingernails`, `mpfb_toenails`). `eye_brown.png` on MakeHumani CC0 silmatekstuur.

- `animations/*.glb`: Quaternius Universal Animation Library 1 ja 2 (CC0, https://quaternius.com/packs/universalanimationlibrary.html), üle kantud skriptiga `tools/retarget_ual.py`. Litsents: `animations/LICENSE_UAL.txt`.

Uuesti tegemine (vajab numpy, scipy, Pillow):

```
python3 tools/outfits.py .
python3 tools/mpfb_bodies.py <mpfb2>/src/mpfb/data <makehuman>/makehuman/data . --clothes --mh-hair <lahtipakitud MakeHumani CC0 pakid: sys/, comm/, vik/>
python3 tools/split_soldiers.py .
python3 tools/retarget_ual.py <mpfb2>/src/mpfb/data <makehuman>/makehuman/data . UAL1_Standard.glb UAL2_Standard.glb
```
