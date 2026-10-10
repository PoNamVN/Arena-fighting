class_name ArcherVFXManager
extends Node3D

## Dedicated High-Impact VFX System for Archer (Forest Ranger Theme: Emerald & Gold)
## Manages wind gathering charge wisps, arrow spiral trails, impact leaf bursts, muzzle shockwaves, and predator sigils.

const COLOR_EMERALD_BRIGHT: Color = Color(0.2, 0.95, 0.55, 1.0)
const COLOR_EMERALD_DEEP: Color = Color(0.05, 0.70, 0.35, 0.9)
const COLOR_GOLD_CRIT: Color = Color(1.0, 0.85, 0.22, 1.0)
const COLOR_SEEKING_CYAN: Color = Color(0.25, 0.88, 1.0, 0.95)

var combat: ArcherCombat = null
var actor: PlayerController = null

# Sub-emitters & resources
var _charge_particles: CPUParticles3D = null
var _charge_light: OmniLight3D = null
var _impact_pool: Array[CPUParticles3D] = []
var _impact_pool_index: int = 0
const IMPACT_POOL_SIZE: int = 8

# Shared materials
var _leaf_material: StandardMaterial3D = null
var _spark_material: StandardMaterial3D = null
var _ring_material: StandardMaterial3D = null

func setup(archer_combat: ArcherCombat, player_actor: PlayerController) -> void:
	combat = archer_combat
	actor = player_actor

	_init_materials()
	_create_charge_vfx()
	_create_impact_pool()


func _init_materials() -> void:
	# 1. Leaf shard material
	_leaf_material = StandardMaterial3D.new()
	_leaf_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_leaf_material.albedo_color = Color(0.25, 0.85, 0.35, 0.95)
	_leaf_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_leaf_material.cull_mode = BaseMaterial3D.CULL_DISABLED

	# 2. Glowing spark material
	_spark_material = StandardMaterial3D.new()
	_spark_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_spark_material.albedo_color = Color(1.0, 0.9, 0.4, 0.95)
	_spark_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	# 3. Shockwave ring material
	_ring_material = StandardMaterial3D.new()
	_ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring_material.albedo_color = Color(0.3, 1.0, 0.6, 0.8)
	_ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA


func _create_charge_vfx() -> void:
	# Inward spiraling wind wisps towards bow arrow rest
	_charge_particles = CPUParticles3D.new()
	_charge_particles.name = "BowChargeWisps"
	_charge_particles.emitting = false
	_charge_particles.amount = 24
	_charge_particles.lifetime = 0.45
	_charge_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_charge_particles.emission_sphere_radius = 0.75
	_charge_particles.radial_accel_min = -3.5
	_charge_particles.radial_accel_max = -2.0
	_charge_particles.direction = Vector3.ZERO
	_charge_particles.gravity = Vector3.ZERO
	_charge_particles.scale_amount_min = 0.04
	_charge_particles.scale_amount_max = 0.09

	var sphere_mesh: SphereMesh = SphereMesh.new()
	sphere_mesh.radial_segments = 6
	sphere_mesh.rings = 3
	sphere_mesh.radius = 0.05
	sphere_mesh.height = 0.10
	_charge_particles.mesh = sphere_mesh
	_charge_particles.material_override = _spark_material
	add_child(_charge_particles)

	# Dynamic charge glow light
	_charge_light = OmniLight3D.new()
	_charge_light.name = "ChargeGlowLight"
	_charge_light.omni_range = 3.5
	_charge_light.omni_attenuation = 1.5
	_charge_light.light_color = COLOR_EMERALD_BRIGHT
	_charge_light.light_energy = 0.0
	add_child(_charge_light)


func _create_impact_pool() -> void:
	for i in range(IMPACT_POOL_SIZE):
		var p: CPUParticles3D = CPUParticles3D.new()
		p.name = "ArrowImpact_%d" % i
		p.emitting = false
		p.one_shot = true
		p.explosiveness = 0.95
		p.amount = 18
		p.lifetime = 0.55
		p.direction = Vector3.UP
		p.spread = 75.0
		p.initial_velocity_min = 2.0
		p.initial_velocity_max = 5.5
		p.gravity = Vector3(0, -9.8, 0)
		p.scale_amount_min = 0.06
		p.scale_amount_max = 0.16

		var prism: PrismMesh = PrismMesh.new()
		prism.size = Vector3(0.08, 0.02, 0.14)
		p.mesh = prism
		p.material_override = _leaf_material

		add_child(p)
		p.top_level = true
		_impact_pool.append(p)


func update_charge_vfx(charging: bool, charge_ratio: float, bow_hand_pos: Vector3) -> void:
	if not _charge_particles or not _charge_light:
		return

	if charging:
		_charge_particles.global_position = bow_hand_pos
		_charge_light.global_position = bow_hand_pos

		if not _charge_particles.emitting:
			_charge_particles.emitting = true

		# Scale light intensity & color as charge peaks
		var is_crit: bool = charge_ratio >= 0.98
		if is_crit:
			_charge_light.light_color = COLOR_GOLD_CRIT
			_charge_light.light_energy = 2.8
			_charge_particles.scale_amount_max = 0.14
		else:
			_charge_light.light_color = COLOR_EMERALD_BRIGHT.lerp(COLOR_GOLD_CRIT, charge_ratio)
			_charge_light.light_energy = charge_ratio * 1.8
			_charge_particles.scale_amount_max = 0.09
	else:
		if _charge_particles.emitting:
			_charge_particles.emitting = false
		_charge_light.light_energy = 0.0


func trigger_arrow_impact(impact_pos: Vector3, normal: Vector3, is_crit: bool = false) -> void:
	if _impact_pool.is_empty():
		return

	var p: CPUParticles3D = _impact_pool[_impact_pool_index]
	_impact_pool_index = (_impact_pool_index + 1) % IMPACT_POOL_SIZE

	p.global_position = impact_pos
	p.direction = (normal + Vector3.UP * 0.5).normalized()
	if is_crit:
		p.material_override = _spark_material
		p.initial_velocity_max = 7.0
		p.amount = 26
	else:
		p.material_override = _leaf_material
		p.initial_velocity_max = 5.0
		p.amount = 18

	p.restart()


func trigger_muzzle_flash(pos: Vector3, dir: Vector3) -> void:
	# Fast expanding sonic shockwave ring at bow release point
	var ring: MeshInstance3D = MeshInstance3D.new()
	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = 0.08
	torus.outer_radius = 0.18
	torus.rings = 16
	torus.ring_segments = 6
	ring.mesh = torus
	ring.material_override = _ring_material

	get_tree().root.add_child(ring)
	ring.global_position = pos
	if dir.length_squared() > 0.001:
		ring.look_at(pos + dir, Vector3.UP)

	# Animate expanding ring and fade out in 0.18s
	var tween: Tween = ring.create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector3(3.2, 3.2, 3.2), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(_ring_material, "albedo_color:a", 0.0, 0.18)
	tween.chain().tween_callback(ring.queue_free)


func trigger_escape_whirlwind(pos: Vector3) -> void:
	# Dramatic leaves vortex for Forest Escape skill
	var vortex: CPUParticles3D = CPUParticles3D.new()
	vortex.emitting = false
	vortex.one_shot = true
	vortex.explosiveness = 0.88
	vortex.amount = 45
	vortex.lifetime = 0.75
	vortex.direction = Vector3.UP
	vortex.spread = 90.0
	vortex.initial_velocity_min = 2.5
	vortex.initial_velocity_max = 6.0
	vortex.angular_velocity_min = 120.0
	vortex.angular_velocity_max = 360.0
	vortex.gravity = Vector3(0, -5.0, 0)
	vortex.scale_amount_min = 0.08
	vortex.scale_amount_max = 0.22

	var prism: PrismMesh = PrismMesh.new()
	prism.size = Vector3(0.12, 0.03, 0.22)
	vortex.mesh = prism
	vortex.material_override = _leaf_material

	get_tree().root.add_child(vortex)
	vortex.global_position = pos
	vortex.restart()

	var t: SceneTreeTimer = get_tree().create_timer(1.0)
	t.timeout.connect(vortex.queue_free)
