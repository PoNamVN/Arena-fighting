extends Node3D

## Subclass hooks are visual-only. Never queue_free(), create gameplay colliders,
## deal damage, or use autostart audio. finish() is the only completion path.
signal finished(effect: Node3D)
var lease_id: int = 0
var active: bool = false
var elapsed: float = 0.0
var duration: float = 0.4
var particle_budget: int = 200
var _emitters: Array[Dictionary] = []
var _animations: Array[AnimationPlayer] = []
var _owned_tweens: Array[Tween] = []
var _transforms: Array[Dictionary] = []
var _follow: WeakRef
var _follow_offset: Transform3D = Transform3D.IDENTITY
var _context: Dictionary = {}

func _ready() -> void:
	_cache(self)
	reset()

func _cache(node: Node) -> void:
	if node is Node3D and node != self:
		_transforms.append({"node":node,"rest":node.transform})
	if node is GeometryInstance3D:
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if node is OmniLight3D or node is SpotLight3D:
		node.shadow_enabled = false
	if node is CPUParticles3D or node is GPUParticles3D:
		_emitters.append({"node":node,"base":node.amount,"visible":node.visible})
	if node is AnimationPlayer:
		_animations.append(node)
	for child: Node in node.get_children():
		_cache(child)

func configure(lifetime: float, budget: int) -> void:
	duration = lifetime
	particle_budget = budget

func apply_quality(multiplier: float) -> void:
	var base_total: int = 0
	for item: Dictionary in _emitters:
		base_total += item.base
	var ratio: float = clampf(multiplier, 0.0, 1.0) * minf(1.0, float(particle_budget) / maxi(1, base_total))
	var remaining: int = particle_budget
	for item: Dictionary in _emitters:
		var count: int = mini(remaining, int(floor(item.base * ratio)))
		remaining -= count
		var emitter: GeometryInstance3D = item.node
		emitter.visible = item.visible and count > 0
		if emitter is GPUParticles3D:
			# Fixed allocation at authored High amount; quality does not resize buffers.
			emitter.amount_ratio = float(count) / item.base
		else:
			emitter.amount = maxi(1, count)

func effective_particles() -> int:
	var total: int = 0
	for item: Dictionary in _emitters:
		var emitter: GeometryInstance3D = item.node
		if emitter.visible:
			total += int(round(emitter.amount * emitter.amount_ratio)) if emitter is GPUParticles3D else emitter.amount
	return total

func play(context: Dictionary = {}) -> void:
	reset()
	_context = context.duplicate()
	elapsed = 0.0
	lease_id += 1
	active = true
	_follow = weakref(context.follow) if context.get("follow") is Node3D else null
	_follow_offset = context.get("follow_offset", Transform3D.IDENTITY)
	show()
	set_process(true)
	for item: Dictionary in _emitters:
		if item.node.visible:
			item.node.restart()
			item.node.emitting = true
	_on_play(_context)

func _process(delta: float) -> void:
	if not active:
		return
	if _follow:
		var anchor: Node3D = _follow.get_ref() as Node3D
		if not is_instance_valid(anchor) or not anchor.is_inside_tree():
			finish()
			return
		global_transform = anchor.global_transform * _follow_offset
	elapsed += delta
	_on_update(delta)
	if active and elapsed >= duration:
		finish()

func finish(expected_lease: int = -1) -> void:
	if not active or (expected_lease >= 0 and expected_lease != lease_id):
		return
	reset()
	finished.emit(self)

func reset() -> void:
	active = false
	elapsed = 0.0
	_follow = null
	_context.clear()
	set_process(false)
	hide()
	for item: Dictionary in _emitters:
		item.node.restart()
		item.node.emitting = false
	for tween: Tween in _owned_tweens:
		if tween.is_valid():
			tween.kill()
	_owned_tweens.clear()
	for animation: AnimationPlayer in _animations:
		animation.stop()
	for item: Dictionary in _transforms:
		item.node.transform = item.rest
	_on_reset()

func track_tween(tween: Tween) -> Tween:
	_owned_tweens.append(tween)
	return tween

func _on_play(_payload: Dictionary) -> void:
	pass

func _on_update(_delta: float) -> void:
	pass

func _on_reset() -> void:
	pass
