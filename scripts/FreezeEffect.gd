class_name FreezeEffect
extends Node

var actor: Node3D
var remaining: float = 0.0
var _floor_layers: int = 0
var _wall_layers: int = 0
var shell: MeshInstance3D

func active() -> bool:
	return remaining > 0

func begin() -> bool:
	if active() or actor.polymorph.active() or actor.polymorph.resistance > 0 or actor.polymorph._dead():
		return false
	if actor is PlayerController and (not actor.controls_enabled or (actor.wizard_combat and actor.wizard_combat.storm.channeling())):
		return false
	actor.polymorph.cancel_actions()
	if actor is PlayerController:
		_floor_layers = actor.platform_floor_layers
		_wall_layers = actor.platform_wall_layers
		actor.platform_floor_layers = 0
		actor.platform_wall_layers = 0
		actor.velocity.x = 0
		actor.velocity.z = 0
	remaining = 0.8
	shell = MeshInstance3D.new()
	var mesh: PrismMesh = PrismMesh.new()
	mesh.size = Vector3(1.1, 2.0, 1.1)
	shell.mesh = mesh
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.8, 1, 0.45)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.15
	shell.material_override = mat
	actor.add_child(shell)
	shell.position.y = 0.95
	return true

func _physics_process(delta: float) -> void:
	if not active():
		return
	if actor.polymorph._dead() or (actor is PlayerController and not actor.controls_enabled):
		clear()
		return
	if remaining <= delta:
		clear()
		actor.polymorph.resistance = PolymorphEffect.RESISTANCE
	else:
		remaining -= delta

func clear() -> void:
	if active() and actor is PlayerController:
		actor.platform_floor_layers = _floor_layers
		actor.platform_wall_layers = _wall_layers
	remaining = 0
	if is_instance_valid(shell):
		shell.queue_free()
	shell = null
