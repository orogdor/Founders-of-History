"""Build the painted historical surface sets.

Run with Python + numpy and Pillow. The position, palette and relief of every
variant are deterministic. Albedo, height and normal sample the same surface.
"""
import argparse
from pathlib import Path
from hashlib import blake2b

import numpy as np
from PIL import Image

OUT = Path(__file__).resolve().parents[1] / "assets/painted/variants"
SIZE = 384
COLS = np.arange(SIZE, dtype=np.float32) / SIZE
X, Y = np.meshgrid(COLS, COLS)

# profile, base pigment, mortar/background, repeat grid, relief
RECIPES = {
    "aegeanStone": ("rubble", "b29773", "6f645a", (5, 4), 0.81),
    "aegeanPlaster": ("plaster", "c6ad86", "9d6b50", (4, 4), 0.34),
    "aegeanBlue": ("pigment", "4d7780", "778d83", (5, 8), 0.49),
    "aegeanRed": ("grain", "985447", "583d31", (4, 5), 0.60),
    "aegeanFrieze": ("frieze", "a67d5e", "547887", (8, 4), 0.36),
    "aegeanSlab": ("block", "d0b691", "867360", (4, 5), 0.63),
    "romanBrick": ("block", "a66552", "b1a08a", (5, 14), 0.63),
    "romanTravertine": ("block", "c8b49a", "8d8174", (5, 6), 0.58),
    "romanStucco": ("plaster", "d2bfa4", "a07d68", (4, 4), 0.28),
    "romanRed": ("pigment", "9f493d", "b07a63", (4, 8), 0.40),
    "romanTile": ("tile", "a86047", "624b45", (6, 6), 0.70),
    "romanMosaic": ("mosaic", "bbab8e", "584942", (24, 24), 0.45),
    "norseTimber": ("boards", "6c5440", "393027", (6, 2), 0.68),
    "norseShingle": ("shingle", "74604b", "44392f", (7, 8), 0.76),
    "medievalMasonry": ("block", "8f8b7e", "676459", (5, 5), 0.82),
    "medievalLime": ("plaster", "baa98c", "918976", (4, 5), 0.36),
    "norsePaint": ("grain", "744332", "382f26", (5, 5), 0.66),
    "lappedPine": ("siding", "c1b5a0", "73645a", (2, 11), 0.53),
    "navalPlank": ("boards", "858078", "494842", (8, 2), 0.72),
    "maritimePaint": ("boards", "617778", "536064", (7, 3), 0.43),
    "portBrick": ("block", "a16b61", "8f8477", (6, 12), 0.66),
    "slate": ("shingle", "645f60", "474548", (9, 8), 0.67),
    "millBrick": ("block", "935d49", "8b7e74", (6, 13), 0.72),
    "sootBrick": ("block", "715b52", "5b554e", (6, 13), 0.66),
    "corrugation": ("sheet", "7d8178", "575b52", (15, 6), 0.72),
    "castIron": ("metal", "525957", "655e48", (8, 8), 0.37),
    "khakiCanvas": ("cloth", "92856a", "716953", (8, 8), 0.54),
    "boardConcrete": ("concrete", "a5a49d", "777a78", (4, 8), 0.54),
    "darkCladding": ("sheet", "5e666b", "383c3f", (7, 6), 0.35),
    "membrane": ("concrete", "706e68", "535451", (4, 8), 0.31),
    "metalTrim": ("metal", "667478", "545c60", (8, 8), 0.31),
    "modernCedar": ("boards", "ad8062", "5a4c43", (9, 2), 0.54),
    "pavingSetts": ("block", "8b8176", "5d574e", (13, 12), 0.74),
    "aegeanGravel": ("aggregate", "ab9476", "7d6f58", (28, 32), 0.59),
    "romanBasalt": ("rubble", "80766e", "483d35", (5, 6), 0.74),
    "railBallast": ("aggregate", "777470", "4c493f", (35, 42), 0.67),
    "asphalt": ("aggregate", "666767", "45494b", (67, 83), 0.38),
    "cutClay": ("aggregate", "aa7855", "7e4e3a", (52, 41), 0.52),
    "dampClay": ("aggregate", "806253", "5f4940", (45, 42), 0.46),
}
MAP_SURFACES = (
    "aegeanPlaster", "aegeanRed", "romanTile", "romanStucco", "romanRed",
    "norseTimber", "norseShingle", "medievalMasonry",
    "lappedPine", "slate", "maritimePaint", "millBrick", "corrugation", "castIron",
    "boardConcrete", "membrane", "metalTrim",
)

def color(value):
    return np.asarray([int(value[i:i+2], 16) / 255.0 for i in (0, 2, 4)], dtype=np.float32)

def ease(t):
    return t*t*(3-2*t)

def grain(rng, size_x, size_y):
    # Wrap the lookup grid and use the same interpolation across the seam.
    grid = rng.random((size_y,size_x), dtype=np.float32)-0.5
    gx,gy = X*size_x,Y*size_y
    ix,iy = gx.astype(np.int32),gy.astype(np.int32)
    tx,ty = ease(gx-ix),ease(gy-iy)
    xx,yy = (ix+1)%size_x,(iy+1)%size_y
    return (grid[iy,ix]*(1-tx)+grid[iy,xx]*tx)*(1-ty)+(grid[yy,ix]*(1-tx)+grid[yy,xx]*tx)*ty

def rows(rng, cx, cy, nx, ny, width=0.05):
    row = np.floor(cy*ny).astype(np.int32)
    a = cx*nx+(row%2)*0.5
    col = np.floor(a).astype(np.int32)
    u,v = a-col,cy*ny-row
    margin = np.minimum(np.minimum(u,1-u),np.minimum(v,1-v))
    face = ease(np.clip((margin-width)/0.07,0,1))
    individual = rng.uniform(-0.12,0.12,(ny,nx))[row%ny,col%nx]
    return face,individual,u,v

def rubble(rng, nx, ny, x, y):
    offsets = rng.uniform(-0.27,0.27,(ny,nx,2))
    colors = rng.uniform(-0.10,0.10,(ny,nx))
    px,py = x*nx,y*ny
    j,i = np.floor(px).astype(np.int32),np.floor(py).astype(np.int32)
    best,second = np.full_like(x,100.),np.full_like(x,100.)
    tint = np.zeros_like(x)
    for dy in (-1,0,1):
        for dx in (-1,0,1):
            ii,jj = i+dy,j+dx
            offset = offsets[ii%ny,jj%nx]
            distance = (px-jj-0.5-offset[:,:,0])**2+(py-ii-0.5-offset[:,:,1])**2
            nearer = distance<best
            tint=np.where(nearer,colors[ii%ny,jj%nx],tint)
            second=np.where(nearer,best,np.minimum(second,distance))
            best=np.minimum(best,distance)
    return ease(np.clip(((second-best)-0.034)/0.13,0,1)),tint

def surface(recipe, seed):
    mode, base, background, (nx,ny), strength = recipe
    rng = np.random.default_rng(seed)
    broad = grain(rng,6,6)
    medium = grain(rng,24,23)
    fine = grain(rng,89,95)
    tooth = grain(rng,157,134)
    speckle = rng.random((SIZE,SIZE),dtype=np.float32)-0.5
    x = X + medium*0.019 + broad*0.013
    y = Y + medium*0.011 + broad*0.015
    elevation = np.zeros_like(X)+0.54
    detail = broad*0.14+medium*0.12+fine*0.083+speckle*0.025
    layer = np.ones_like(X)
    if mode in {"block","tile","shingle","mosaic"}:
        layer,tint,u,v=rows(rng,x,y,nx,ny,0.038 if mode in {"tile","shingle"} else 0.06)
        detail+=tint
        elevation=0.24+layer*(0.51+medium*0.12+fine*0.08)
        if mode in {"tile","shingle"}:
            rollover=(np.sin(np.pi*u)**(0.72 if mode=="tile" else 2.2)) if mode=="tile" else 0.7+0.3*np.sin(np.pi*v)
            overlap=np.sqrt(np.clip(v,0,1))
            elevation=0.23+layer*(0.34+rollover*0.24+overlap*0.11+medium*0.07)
            detail+=0.13*(rollover-0.5)-0.20*(1-overlap)
        if mode=="mosaic":
            row=np.floor(Y*ny).astype(np.int32)
            col=np.floor(X*nx).astype(np.int32)
            border = (np.minimum(row,ny-1-row)<2) | (np.minimum(col,nx-1-col)<2)
            diamond=(abs(row-ny/2+0.5)+abs(col-nx/2+0.5))
            chess=((row+col)%2==0)
            motif = (border & chess) | ((diamond>=7)&(diamond<=8)) | ((diamond<=5)&chess)
            detail=np.where(motif,-0.51,detail*0.56)
            elevation += np.where(motif,-0.025,0.021)
    elif mode=="rubble":
        layer,tint=rubble(rng,nx,ny,x,y)
        elevation=0.25+layer*(0.52+medium*0.20+fine*0.08)
        detail+=tint
    elif mode in {"boards","siding","grain"}:
        coord=Y if mode=="siding" else X
        along=X if mode=="siding" else Y
        count=ny if mode=="siding" else nx
        warped=coord*count + broad*0.09
        board=warped-np.floor(warped)
        layer=ease(np.clip(np.minimum(board,1-board)/0.079,0,1)) if mode!="grain" else layer
        fibers=np.sin((coord+medium*0.003+np.sin(along*2*np.pi)*0.006)*160*2*np.pi)
        fine_fibers=grain(rng,96,8) if mode!="siding" else grain(rng,8,96)
        detail+=fine_fibers*0.16 + fibers*0.043
        elevation=0.30+layer*(0.40+fine_fibers*0.20+fibers*0.035)
        if mode=="siding":
            elevation+=board*0.13
    elif mode=="aggregate":
        pebble=grain(rng,nx,ny)
        fleck=ease(np.clip((pebble+0.15)/0.47,0,1))
        layer=0.58+fleck*0.31+broad*0.12
        elevation=0.46+fleck*0.25+tooth*0.18-broad*0.10
        detail+=fine*0.11+fleck*0.13+speckle*0.12
    elif mode=="sheet":
        rib=np.power((np.cos(X*nx*2*np.pi)+1)*0.5,2.0)
        joints=1-np.clip(np.minimum((Y*ny)%1,1-(Y*ny)%1)*30,0,1)
        elevation=0.44+0.28*rib-0.08*joints+fine*0.07
        detail+=rib*0.10-joints*0.07
    elif mode=="frieze":
        bands=(np.sin(Y*6*np.pi)+1.0)*0.5
        u=(X*8+0.06*np.sin(Y*8*np.pi))%1
        v=(Y*4)%1
        inside=(v>0.21)&(v<0.79)
        spiral=((u>0.12)&(u<0.86)&((v<0.31)|(v>0.69)))|((u>0.12)&(u<0.25)&(v<0.75))|((u>0.60)&(u<0.74)&(v>0.39)&(v<0.73))
        layer=np.where(inside & spiral,0.92,0.13)
        layer=np.where(bands<0.12,0.89,layer)
        elevation+=layer*0.12+fine*0.12
    elif mode=="cloth":
        weave=np.sin(X*120*2*np.pi)*np.sin(Y*128*2*np.pi)
        elevation=0.56+0.18*weave+medium*0.12
        detail+=weave*0.043
    elif mode in {"plaster","pigment","metal","concrete"}:
        mineral=medium*0.15+fine*0.14+tooth*0.10
        pits=np.minimum(0,tooth+0.22)*0.50
        elevation+=mineral+pits
        stain=np.clip((broad+medium*0.35+0.08)*0.53,0,0.40)
        layer-=stain
        if mode=="concrete":
            seam=np.clip(1-np.abs(np.sin(Y*8*np.pi))*32,0,1)
            detail-=seam*0.046
            elevation-=seam*0.115
        if mode=="pigment":
            brush=np.sin((x*3.0+y*1.0)*2*np.pi+medium*2.0)
            detail+=brush*0.055
    tint=np.asarray(rng.uniform(-0.035,0.035,3),dtype=np.float32)
    face, behind=color(base),color(background)
    albedo=(behind+layer[:,:,None]*(face-behind))*(1.0+detail[:,:,None])+tint
    relief=np.clip(0.5+(elevation-0.5)*strength,0,1)
    gx=(np.roll(relief,1,axis=1)-np.roll(relief,-1,axis=1))*3.5
    gy=(np.roll(relief,-1,axis=0)-np.roll(relief,1,axis=0))*3.5
    magnitude=np.sqrt(gx*gx+gy*gy+1.0)
    normal=0.5+0.5*np.dstack((gx/magnitude,gy/magnitude,1.0/magnitude))
    return albedo,relief,normal

def save(pixels, target):
    img = Image.fromarray(np.rint(np.clip(pixels,0,1)*255).astype(np.uint8))
    img.save(target,compress_level=5)

def texture_import(target, normal_map=False):
    meta=target.with_suffix(".png.import")
    if not meta.exists():
        text=("[remap]\nimporter=\"texture\"\ntype=\"CompressedTexture2D\"\n\n"
              "[deps]\nsource_file=\"res://assets/painted/variants/"+target.name+"\"\n\n"
              "[params]\ncompress/mode=0\ncompress/normal_map="+str(int(normal_map))+
              "\nmipmaps/generate=true\ndetect_3d/compress_to=0\n")
        meta.write_text(text,encoding="utf-8")

def map_atlas(name):
    tile,padding=144,6
    block=tile+padding*2
    atlas=Image.new("RGBA",(4*block,2*block))
    for variant in range(8):
        path=OUT/f"period_{name}_{variant}"
        with Image.open(path.with_suffix(".png")) as color_file, Image.open(path.with_name(path.name+"_height.png")) as height_file:
            rgba=color_file.resize((tile,tile),Image.Resampling.LANCZOS).convert("RGBA")
            rgba.putalpha(height_file.resize((tile,tile),Image.Resampling.LANCZOS))
        wrapped=np.pad(np.asarray(rgba),((padding,padding),(padding,padding),(0,0)),mode="wrap")
        atlas.paste(Image.fromarray(wrapped),(variant%4*block,variant//4*block))
    target=OUT/f"period_{name}_atlas.png"
    atlas.save(target,compress_level=5)
    texture_import(target)

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("materials", nargs="*", choices=None)
    parser.add_argument("--map-atlases-only", action="store_true")
    args=parser.parse_args()
    OUT.mkdir(exist_ok=True,parents=True)
    if args.map_atlases_only:
        for name in MAP_SURFACES:
            map_atlas(name)
        return
    for name in args.materials or RECIPES:
        digest=blake2b(name.encode(),digest_size=8).digest()
        seed=int.from_bytes(digest,"little")
        for variant in range(8):
            albedo,relief,normal=surface(RECIPES[name],seed+variant)
            path=OUT/f"period_{name}_{variant}"
            for suffix,data in [("",albedo),("_height",relief),("_normal",normal)]:
                target=path.with_name(path.name+suffix+".png")
                save(data,target)
                texture_import(target,suffix=="_normal")
        if name in MAP_SURFACES:
            map_atlas(name)
        print(name,flush=True)

if __name__=="__main__":
    main()

