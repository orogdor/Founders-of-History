# Inimeste varade allikad

- `bodies/*.glb`: MakeHumani/MPFB2 baaskeha (hm08), makro-sihtkujud (sugu, vanus, rass), MPFB2 `game_engine` luustik ja kaalud. Allikas: github.com/makehumancommunity/mpfb2, CC0.
- Silmad: MakeHumani `high-poly` silmad ja `brown_eye.png`. Allikas: github.com/makehumancommunity/makehuman, CC0.
- `clothes/*/*.glb`: **automaatsed proovirõivad**, mis on tehtud skriptiga `tools/mpfb_bodies.py` MakeHumani abivõrkudest (`helper-tights`, `helper-skirt`, `helper-hair`) ja kehapinnast. Need on ajutised ja tuleb asendada päris MPFB2 riietega (vt `INIMESED.md`).
- Soengud ja habemed (`clothes/hair_*`, `clothes/beard_*`) ning kiivrite ja mütside kujud: tehtud skriptiga `tools/hair.py` sama keha pinnast.
- `../soldiers/split/*.glb`: mängu olemasolevad sõdurimudelid, mille `tools/split_soldiers.py` on jaganud kehaks ja varustuseks; uut sisu pole lisatud.
- `textures/`: kangaste ja naha tekstuurid on tehtud protseduuriliselt skriptiga `tools/textures.py`; nahk kasutab MPFB2 CC0 maske (`mpfb_lips`, `mpfb_eyelids`, `mpfb_ears`, `mpfb_fingernails`, `mpfb_toenails`). `eye_brown.png` on MakeHumani CC0 silmatekstuur.

Uuesti tegemine (vajab numpy, scipy, Pillow):

```
python3 tools/outfits.py .
python3 tools/mpfb_bodies.py <mpfb2>/src/mpfb/data <makehuman>/makehuman/data . --clothes
python3 tools/split_soldiers.py .
```
