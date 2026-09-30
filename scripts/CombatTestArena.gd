class_name CombatTestArena
extends Node3D

@export var respawn_delay: float = 1.5

@onready var player: PlayerController = get_node_or_null("Player") as PlayerController
@onready var attack_dummy: AttackTrainingDummy = get_node_or_null("AttackTrainingDummy") as AttackTrainingDummy
@onready var training_dummy: TrainingDummy = get_node_or_null("TrainingDummy") as TrainingDummy
@onready var hud: CanvasLayer = get_node_or_null("CombatTestHUD") as CanvasLayer

var _player_spawn_pos: Vector3 = Vector3(0, 0.1, 0)
var _player_spawn_yaw: float = 0.0
var _respawn_tween: Tween
var _respawn_count: int = 0

signal player_respawned()


func _ready() -> void:
	if not player:
		player = find_child("Player", true, false) as PlayerController
		
	if player:
		_player_spawn_pos = player.global_position
		_player_spawn_yaw = player._camera_yaw
		if player.health_component:
			player.health_component.died.connect(_on_player_died)
			
	if not hud:
		hud = find_child("CombatTestHUD", true, false) as CanvasLayer


func _on_player_died() -> void:
	if _respawn_tween and _respawn_tween.is_valid():
		_respawn_tween.kill()
		
	_respawn_tween = create_tween()
	_respawn_tween.tween_interval(respawn_delay)
	_respawn_tween.tween_callback(respawn_player)


func respawn_player() -> void:
	if not player:
		return
		
	_respawn_count += 1
	player.respawn(_player_spawn_pos, _player_spawn_yaw)
	
	if hud:
		hud.on_player_respawned()
		
	player_respawned.emit()
