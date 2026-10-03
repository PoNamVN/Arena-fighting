class_name AbilityAction
extends RefCounted

## Signals
signal phase_changed(old_phase: int, new_phase: int)
signal action_finished()
signal action_cancelled()

## Phases
enum Phase {
	INACTIVE = 0,
	STARTUP = 1,
	ACTIVE = 2,
	RECOVERY = 3,
	FINISHED = 4
}

## State
var slot_name: String = ""
var data: AbilityData = null
var caster: CharacterBody3D = null

var current_phase: Phase = Phase.INACTIVE
var phase_timer: float = 0.0
var is_cancelled: bool = false

var hit_targets: Array[Node] = []
var custom_data: Dictionary = {}


func init_action(p_caster: CharacterBody3D, p_slot: String, p_data: AbilityData) -> void:
	caster = p_caster
	slot_name = p_slot
	data = p_data
	current_phase = Phase.STARTUP
	phase_timer = data.startup_duration if data else 0.0
	is_cancelled = false
	hit_targets.clear()
	custom_data.clear()

	# If startup duration is 0, advance directly to ACTIVE
	if phase_timer <= 0.0:
		_transition_phase(Phase.ACTIVE)


func update(delta: float) -> void:
	if current_phase == Phase.INACTIVE or current_phase == Phase.FINISHED or is_cancelled:
		return

	if phase_timer > 0.0:
		phase_timer -= delta
		if phase_timer <= 0.0:
			_advance_phase()


func _advance_phase() -> void:
	match current_phase:
		Phase.STARTUP:
			_transition_phase(Phase.ACTIVE)
		Phase.ACTIVE:
			_transition_phase(Phase.RECOVERY)
		Phase.RECOVERY:
			_transition_phase(Phase.FINISHED)
			action_finished.emit()


func _transition_phase(next_phase: Phase) -> void:
	var prev: Phase = current_phase
	current_phase = next_phase
	match current_phase:
		Phase.ACTIVE:
			phase_timer = data.active_duration if data else 0.0
			# If active duration is 0, advance to recovery immediately
			if phase_timer <= 0.0:
				_transition_phase(Phase.RECOVERY)
				return
		Phase.RECOVERY:
			phase_timer = data.recovery_duration if data else 0.0
			# If recovery duration is 0, finish immediately
			if phase_timer <= 0.0:
				_transition_phase(Phase.FINISHED)
				action_finished.emit()
				return
		Phase.FINISHED:
			phase_timer = 0.0

	phase_changed.emit(prev, current_phase)


func cancel() -> void:
	if is_cancelled or current_phase == Phase.FINISHED or current_phase == Phase.INACTIVE:
		return
	is_cancelled = true
	current_phase = Phase.FINISHED
	phase_timer = 0.0
	action_cancelled.emit()


func is_active() -> bool:
	return not is_cancelled and current_phase != Phase.INACTIVE and current_phase != Phase.FINISHED


func has_front_protection() -> bool:
	if is_cancelled or not data:
		return false
	return data.has_front_protection and current_phase == Phase.ACTIVE


func allows_movement() -> bool:
	if is_cancelled or not data:
		return false
	return data.allows_movement and current_phase == Phase.ACTIVE


func allows_dodge() -> bool:
	if is_cancelled or not data:
		return false
	return data.allows_dodge and current_phase == Phase.RECOVERY


func can_hit_target(target: Node) -> bool:
	if is_cancelled or not target or current_phase != Phase.ACTIVE:
		return false
	return not hit_targets.has(target)


func register_hit(target: Node) -> void:
	if target and not hit_targets.has(target):
		hit_targets.append(target)
