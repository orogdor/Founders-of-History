extends SceneTree
const Grid=preload("res://scripts/campaign_grid.gd")
const Terrain=preload("res://scripts/detail_terrain.gd")
const Visual=preload("res://scripts/visual_river.gd")
func _initialize():call_deferred("run")
func run():
 load("res://scripts/mobile_profile.gd").active=true
 var game:Node=load("res://main.tscn").instantiate();root.add_child(game);game.paused=true
 await process_frame
 var edges=0;var max_seam=0.0;var max_hill=0.0;var sea_changed=0
 for r in range(25,145,12):
  for c in range(25,190,12):
   var a:PackedVector4Array=Visual.color_heights(game.grid,game.world_height_samples,c,r,int(game.game.seed),game.world_river_graph)
   var b:PackedVector4Array=Visual.color_heights(game.grid,game.world_height_samples,c+1,r,int(game.game.seed),game.world_river_graph)
   for j in 17:
    max_seam=maxf(max_seam,absf(a[j*17+16].z-b[j*17].z));edges+=1
   for v in a:
    if v.x<0.85 and absf(v.z-v.x)>0.001:sea_changed+=1
    if v.x>4.25 and v.x<5.5:max_hill=maxf(max_hill,absf(v.z-v.x))
 print("TERRAIN_RELIEF_CHECK seam=",max_seam," samples=",edges," dry_delta=",max_hill," lowland_delta=",sea_changed)
 assert(max_seam<0.005 and max_hill>0.1 and sea_changed==0)
 game.queue_free();quit()
