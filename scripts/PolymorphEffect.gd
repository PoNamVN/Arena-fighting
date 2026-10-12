class_name PolymorphEffect
extends Node

const DURATION: float = 1.5
const RESISTANCE: float = 2.0
var actor: Node3D
var remaining: float = 0.0
var resistance: float = 0.0
var label: Label3D
var chicken: Node3D
var _visuals: Array[Dictionary] = []

func active() -> bool:
	return remaining > 0.0

func begin() -> bool:
	if actor is PlayerController and actor.is_ragdoll_recovering(): return false
	if actor.get("hawk_carry") and actor.hawk_carry.active(): return false
	if active() or resistance > 0 or _dead():
		return false
	if actor.frost.active() or (actor is PlayerController and actor.wizard_combat and actor.wizard_combat.storm.channeling()):
		return false
	if actor is PlayerController and not actor.controls_enabled:
		return false
	cancel_actions()
	var root_visuals: Node3D = actor.get_node("Visuals")
	for child: Node in root_visuals.get_children():
		if child is Node3D:
			_visuals.append({"node": child, "visible": child.visible})
			child.hide()
	chicken = preload("res://assets/models/polymorph_chicken.glb").instantiate() as Node3D
	root_visuals.add_child(chicken)
	chicken.rotation.y = PI
	label = Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position.y = 1.15
	label.font_size = 42
	label.pixel_size = 0.004
	chicken.add_child(label)
	var puff: CPUParticles3D = CPUParticles3D.new()
	puff.amount = 16
	puff.lifetime = 0.45
	puff.one_shot = true
	puff.explosiveness = 1
	puff.position.y = 0.5
	puff.direction = Vector3.UP
	puff.spread = 160
	puff.initial_velocity_min = 0.5
	puff.initial_velocity_max = 2
	puff.gravity = Vector3.ZERO
	puff.scale_amount_min = 0.04
	puff.scale_amount_max = 0.1
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1
	mesh.radial_segments = 6
	mesh.rings = 3
	puff.mesh = mesh
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.8, 0.4, 1)
	puff.material_override = mat
	chicken.add_child(puff)
	puff.emitting = true
	remaining = DURATION
	label.text = "HÓA GÀ · 1.5s"
	return true

func _dead() -> bool:
	return actor.is_dead if actor is PlayerController else actor.is_dead()

func _physics_process(delta: float) -> void:
	resistance = maxf(0, resistance - delta)
	if not active():
		return
	if _dead() or (actor is PlayerController and not actor.controls_enabled):
		clear()
		return
	remaining = maxf(0, remaining - delta)
	if remaining <= 0:
		_restore()
		resistance = RESISTANCE
	elif is_instance_valid(chicken):
		label.text = "HÓA GÀ · %.1fs" % remaining
		var speed: float = actor.velocity.length() if actor is PlayerController else 0.0
		chicken.position.y = absf(sin((DURATION - remaining) * 20)) * minf(0.08, speed * 0.02)

func _restore() -> void:
	for entry: Dictionary in _visuals:
		if is_instance_valid(entry.node):
			entry.node.visible = entry.visible
	_visuals.clear()
	if is_instance_valid(chicken):
		chicken.queue_free()
	chicken = null

func clear() -> void:
	remaining = 0
	resistance = 0
	_restore()

func cancel_actions() -> void:
	if actor is PlayerController:
		var player: PlayerController = actor
		if player.active_ability_action:
			player.active_ability_action.cancel()
		if player.archer_combat:
			player.archer_combat.interrupt()
		if player.wizard_combat:
			player.wizard_combat.interrupt()
		player.dodge_controller.reset()
		player.reset_combo()
		var room: Node = player.get_parent()
		if room is PracticeArena and room.brain and room.brain.actor == player:
			room.brain._cancel_warning()
		player._attack_impact_applied = true
		player._counter_target = null
		player.combat.stop_slash_effect()
		var old: PlayerController.CombatState = player.combat_state
		player.combat_state = PlayerController.CombatState.IDLE
		player.state_changed.emit(old, player.combat_state)
		if player.anim_player and not player.is_ragdoll_active():
			player.anim_player.play("idle")
	elif actor is TrainingDummy:
		actor.is_blocking = false
