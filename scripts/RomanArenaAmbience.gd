extends Node3D
## Visual theme only; collision, actor spawns and combat stay in the arena scenes.
var _banner_material:ShaderMaterial
var _elapsed:float=0.0
func _ready()->void:
 var floor_body:Node=get_parent().get_node_or_null("FloorCollision")
 if floor_body:floor_body.set_meta("ground_color",Color("c9b48a"))
 _banner_material=$RomanBanners.mesh.surface_get_material(0).duplicate() as ShaderMaterial
 $RomanBanners.set_surface_override_material(0,_banner_material)
func _process(delta:float)->void:
 _elapsed+=delta;_banner_material.set_shader_parameter("flutter_time",_elapsed)
