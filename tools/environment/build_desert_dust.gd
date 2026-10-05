extends SceneTree
func _initialize()->void:call_deferred("build")
func build()->void:
 var node:=GPUParticles3D.new();node.name="DesertDust";node.amount=64;node.lifetime=10;node.preprocess=10
 node.position.y=.12;node.visibility_aabb=AABB(Vector3(-23,-1,-23),Vector3(46,4,46))
 node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 var process:=ParticleProcessMaterial.new();process.emission_shape=ParticleProcessMaterial.EMISSION_SHAPE_BOX
 process.emission_box_extents=Vector3(18,.06,18);process.direction=Vector3(1,.04,.2);process.spread=12
 process.initial_velocity_min=.35;process.initial_velocity_max=.65;process.gravity=Vector3(0,.012,0)
 process.damping_min=.04;process.damping_max=.08;process.scale_min=.7;process.scale_max=1.5
 var fade:=Gradient.new();fade.offsets=PackedFloat32Array([0,.15,.7,1]);fade.colors=PackedColorArray([Color(.65,.50,.30,0),Color(.65,.50,.30,.07),Color(.65,.50,.30,.055),Color(.65,.50,.30,0)])
 var ramp:=GradientTexture1D.new();ramp.gradient=fade;process.color_ramp=ramp;node.process_material=process
 var gradient:=Gradient.new();gradient.offsets=PackedFloat32Array([0,.25,1]);gradient.colors=PackedColorArray([Color.WHITE,Color(1,1,1,.6),Color(1,1,1,0)])
 var texture:=GradientTexture2D.new();texture.width=64;texture.height=64;texture.gradient=gradient;texture.fill=GradientTexture2D.FILL_RADIAL;texture.fill_from=Vector2(.5,.5);texture.fill_to=Vector2(1,.5)
 var mat:=StandardMaterial3D.new();mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
 mat.vertex_color_use_as_albedo=true;mat.albedo_texture=texture;mat.billboard_mode=BaseMaterial3D.BILLBOARD_PARTICLES;mat.no_depth_test=false;mat.cull_mode=BaseMaterial3D.CULL_DISABLED
 var quad:=QuadMesh.new();quad.size=Vector2(2.2,.75);quad.material=mat;node.draw_pass_1=quad
 root.add_child(node)
 var packed:=PackedScene.new();packed.pack(node);ResourceSaver.save(packed,"res://scenes/environments/DesertDust.tscn")
 print("DESERT DUST: 64 pooled continuous particles, 64px radial texture, no shadows/depth read");quit()
