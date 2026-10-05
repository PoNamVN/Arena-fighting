extends "res://scripts/vfx/PooledVFX.gd"
## Visual-only resources are generated once when the pool is built.
@export_enum("DustPuff", "DustRing", "Debris", "Sparks", "Shockwave", "GroundDecal") var kind := 0
@export_range(0.01,8.0) var effect_scale := 1.0
@export_range(0.0,2.0) var amount_scale := 1.0
@export var color := Color("c9b48a")
@export var ground_y := 0.0
@export_range(0.1,8.0) var radius := 1.5
@export_flags_3d_render var ground_layer := 8
const BASE_COUNTS = [32,40,24,16,0,0]
const LIFETIMES = [0.9,1.1,1.6,0.3,0.55,4.0]
const RingShader = preload("res://vfx/common/shockwave.gdshader")
var particles: GPUParticles3D
var motion: ParticleProcessMaterial
var collision: GPUParticlesCollisionBox3D
var ring: MeshInstance3D
var ring_material: ShaderMaterial
var decal: Decal
var _quality := 1.0
var _cast_amount := 1.0
static var _cracks: Texture2D
static var _radial: GradientTexture2D

func _ready() -> void:
 if kind < 4:
  _build_particles()
 elif kind == 4:
  ring = MeshInstance3D.new()
  ring.name = "Ring"
  ring.mesh = _ring_mesh()
  ring_material = ShaderMaterial.new()
  ring_material.shader = RingShader
  ring.material_override = ring_material
  add_child(ring)
 else:
  decal = Decal.new()
  decal.name = "Cracks"
  if not _cracks:
   _cracks = _crack_texture()
  decal.texture_albedo = _cracks
  decal.cull_mask = ground_layer
  decal.upper_fade = 0.01
  decal.lower_fade = 0.01
  decal.normal_fade = 0.8
  add_child(decal)
 super._ready()

static func _soft_texture() -> GradientTexture2D:
 if not _radial:
  var g := Gradient.new()
  g.offsets = PackedFloat32Array([0,0.28,0.65,1])
  g.colors = PackedColorArray([Color.WHITE,Color(1,1,1,0.8),Color(1,1,1,0.22),Color(1,1,1,0)])
  _radial = GradientTexture2D.new()
  _radial.width = 64
  _radial.height = 64
  _radial.gradient = g
  _radial.fill = GradientTexture2D.FILL_RADIAL
  _radial.fill_from = Vector2(0.5,0.5)
  _radial.fill_to = Vector2(1,0.5)
 return _radial

func _build_particles() -> void:
 particles = GPUParticles3D.new()
 particles.name = "Particles"
 particles.emitting = false
 particles.amount = ceili(BASE_COUNTS[kind]*1.2)
 particles.lifetime = LIFETIMES[kind]
 particles.one_shot = true
 particles.explosiveness = 1.0
 particles.randomness = 0.25
 particles.local_coords = false
 particles.visibility_aabb = AABB(Vector3(-8,-2,-8),Vector3(16,8,16))
 particles.fixed_fps = 60 if kind == 3 else 30
 motion = ParticleProcessMaterial.new()
 motion.direction = Vector3.UP
 motion.spread = 65
 motion.initial_velocity_min = 0.4 if kind < 2 else 2.0
 motion.initial_velocity_max = 1.0 if kind < 2 else 4.0
 motion.gravity = Vector3(0,0.15,0) if kind < 2 else Vector3(0,-9.8,0)
 motion.damping_min = 0.5 if kind < 2 else 0.15
 motion.damping_max = 1.0 if kind < 2 else 0.3
 motion.angle_min = -180
 motion.angle_max = 180
 motion.angular_velocity_min = -40 if kind < 2 else -180
 motion.angular_velocity_max = 40 if kind < 2 else 180
 motion.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
 motion.emission_sphere_radius = 0.15
 if kind == 1:
  motion.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
  motion.emission_ring_axis = Vector3.UP
  motion.emission_ring_height = 0.02
  motion.emission_ring_radius = 0.35
  motion.emission_ring_inner_radius = 0.3
  motion.initial_velocity_min = 0
  motion.initial_velocity_max = 0
  motion.radial_velocity_min = 1.1
  motion.radial_velocity_max = 1.5
 if kind < 2:
  motion.turbulence_enabled = true
  motion.turbulence_noise_strength = 0.12
  motion.turbulence_influence_min = 0.05
  motion.turbulence_influence_max = 0.1
  motion.scale_min = 0.3
  motion.scale_max = 0.55
  var curve := Curve.new()
  curve.add_point(Vector2(0,0.5))
  curve.add_point(Vector2(0.65,1.3))
  curve.add_point(Vector2(1,1.6))
  var texture := CurveTexture.new()
  texture.curve = curve
  motion.scale_curve = texture
 else:
  motion.scale_min = 0.65
  motion.scale_max = 1.15
 var g := Gradient.new()
 g.offsets = PackedFloat32Array([0,0.08,0.55,1])
 g.colors = PackedColorArray([Color(1,1,1,0),Color.WHITE,Color(1,1,1,0.8),Color(1,1,1,0)])
 var fade := GradientTexture1D.new()
 fade.gradient = g
 motion.color_ramp = fade
 particles.process_material = motion
 var material := StandardMaterial3D.new()
 material.vertex_color_use_as_albedo = true
 material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
 material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
 material.cull_mode = BaseMaterial3D.CULL_DISABLED
 material.roughness = 0.95
 if kind < 2:
  material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
  material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
  material.albedo_texture = _soft_texture()
  var quad := QuadMesh.new()
  quad.size = Vector2(0.75,0.75)
  quad.material = material
  particles.draw_pass_1 = quad
 elif kind == 2:
  var chunk := PrismMesh.new()
  chunk.size = Vector3(0.07,0.055,0.065)
  chunk.material = material
  particles.draw_pass_1 = chunk
  motion.collision_mode = ParticleProcessMaterial.COLLISION_RIGID
  motion.collision_bounce = 0.28
  motion.collision_friction = 0.8
  particles.collision_base_size = 0.035
  collision = GPUParticlesCollisionBox3D.new()
  collision.name = "GroundCollision"
  collision.size = Vector3(20,0.1,20)
  collision.cull_mask = 2
  particles.layers = 2
  add_child(collision)
 else:
  material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
  material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
  material.emission_enabled = true
  material.emission = Color(1,0.6,0.25)
  material.emission_energy_multiplier = 2
  motion.particle_flag_align_y = true
  motion.angular_velocity_min = 0
  motion.angular_velocity_max = 0
  var sliver := BoxMesh.new()
  sliver.size = Vector3(0.012,0.12,0.012)
  sliver.material = material
  particles.draw_pass_1 = sliver
 add_child(particles)

func apply_quality(multiplier: float) -> void:
 _quality = clampf(multiplier,0,1.2)
 _apply_amount()

func _apply_amount() -> void:
 if particles:
  var count := clampi(roundi(BASE_COUNTS[kind]*_quality*_cast_amount),0,mini(particle_budget,particles.amount))
  particles.amount_ratio = float(count)/particles.amount
  particles.visible = count > 0

func requested_particles(multiplier: float, payload: Dictionary) -> int:
 return clampi(roundi(BASE_COUNTS[kind]*multiplier*clampf(payload.get("amount_scale",amount_scale),0,2)),0,ceili(BASE_COUNTS[kind]*1.2))

func play(payload: Dictionary = {}) -> void:
 _cast_amount = clampf(payload.get("amount_scale",amount_scale),0,2)
 _apply_amount()
 var s: float = clampf(payload.get("scale",effect_scale),0.01,8)
 var r: float = clampf(payload.get("radius",radius),0.1,8)
 var y: float = payload.get("ground_y",ground_y)
 var tint: Color = payload.get("color",color)
 var shade := tint.lerp(Color(tint.get_luminance(),tint.get_luminance(),tint.get_luminance(),tint.a),0.12)
 scale = Vector3.ONE*s
 # Super.play resets cached child transforms. Apply placement in _on_play afterwards.
 if particles:
  motion.color = Color(shade.r*0.85,shade.g*0.85,shade.b*0.85,clampf(payload.get("alpha",0.6),0.5,0.7)) if kind < 2 else Color(shade.r*0.7,shade.g*0.7,shade.b*0.7,1)
  if kind == 3:
   motion.color = payload.get("color",Color(1,0.82,0.5))
  if kind == 1:
   motion.emission_ring_radius = r*0.25
   motion.emission_ring_inner_radius = r*0.22
   motion.radial_velocity_min = r*0.7
   motion.radial_velocity_max = r
 super.play(payload)

func _on_play(payload: Dictionary) -> void:
 var s := scale.x
 var r: float = clampf(payload.get("radius",radius),0.1,8)
 var y: float = payload.get("ground_y",ground_y)
 var tint: Color = payload.get("color",color)
 if particles and kind != 3:
  particles.position = Vector3(0,(y-global_position.y)/s+0.12,0)
 if collision:
  collision.position = Vector3(0,(y-global_position.y-0.05)/s,0)
  collision.size = Vector3(20/s,0.1/s,20/s)
 if ring:
  ring.position = Vector3(0,(y-global_position.y)/s+0.015,0)
  ring_material.set_shader_parameter("tint",Color(tint.r*0.7,tint.g*0.7,tint.b*0.7,0.6))
  ring.scale = Vector3.ONE*0.08
  ring_material.set_shader_parameter("opacity",1.0)
  var t := track_tween(create_tween()).set_parallel(true)
  t.tween_property(ring,"scale",Vector3(r,1,r),duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
  t.tween_method(func(a: float): ring_material.set_shader_parameter("opacity",a),1.0,0.0,duration)
 if decal:
  decal.position = Vector3(0,(y-global_position.y)/s+0.012,0)
  decal.size = Vector3(r*2,0.045/s,r*2)
  decal.cull_mask = int(payload.get("ground_layer",ground_layer))
  decal.modulate = Color(tint.r*0.45,tint.g*0.45,tint.b*0.45,1)

func _on_update(_delta: float) -> void:
 if decal:
  decal.modulate.a = clampf((duration-elapsed)/1.2,0,1)

func _on_reset() -> void:
 if ring_material:
  ring_material.set_shader_parameter("opacity",0.0)
 if decal:
  decal.modulate.a = 0

static func _ring_mesh() -> ArrayMesh:
 var vertices := PackedVector3Array()
 var uv := PackedVector2Array()
 for i in 64:
  var a := TAU*i/64.0
  var b := TAU*(i+1)/64.0
  for v in [Vector3(cos(a)*0.88,0,sin(a)*0.88),Vector3(cos(a),0,sin(a)),Vector3(cos(b),0,sin(b)),Vector3(cos(a)*0.88,0,sin(a)*0.88),Vector3(cos(b),0,sin(b)),Vector3(cos(b)*0.88,0,sin(b)*0.88)]:
   vertices.append(v)
   uv.append(Vector2(v.x,v.z))
 var arrays := []
 arrays.resize(Mesh.ARRAY_MAX)
 arrays[Mesh.ARRAY_VERTEX] = vertices
 arrays[Mesh.ARRAY_TEX_UV] = uv
 var mesh := ArrayMesh.new()
 mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
 return mesh

static func _crack_texture() -> Texture2D:
 var image := Image.create(128,128,false,Image.FORMAT_RGBA8)
 image.fill(Color.TRANSPARENT)
 var rng := RandomNumberGenerator.new()
 rng.seed = 1703
 for ray in 13:
  var angle := TAU*ray/13.0+rng.randf_range(-0.1,0.1)
  var end := rng.randi_range(32,59)
  for step in range(4,end):
   var a := angle+0.07*sin(step*0.43+ray)
   var x := roundi(64+cos(a)*step)
   var y := roundi(64+sin(a)*step)
   image.set_pixel(x,y,Color(1,1,1,0.9*(1-float(step)/70)))
   if step < 24:
    image.set_pixel(x+1,y,Color(1,1,1,0.6))
 for y in range(52,76):
  for x in range(52,76):
   var d := Vector2(x-64,y-64).length()/12
   if d < 1:
    image.set_pixel(x,y,Color(1,1,1,(1-d)*0.32))
 return ImageTexture.create_from_image(image)
