extends SceneTree

const Definition = preload("res://scripts/vfx/VFXDefinition.gd")
const PooledEffect = preload("res://scripts/vfx/PooledVFX.gd")
var manager: Node
var passed: int = 0
var failed: int = 0
var received: Array[Dictionary] = []
var target: Node3D

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
		print("[PASS] ",label)
	else:
		failed += 1
		push_error("[FAIL] "+label)

func frames(count: int) -> void:
	for i in range(count):
		await physics_frame
		await process_frame

func events(event: StringName, context: Dictionary) -> void:
	# Do not retain actor/target references in the test event log.
	received.append({"event":event,"skill":context.get("skill",&""),"hero":context.get("hero",&"")})

func definition(name: StringName, count: int = 2) -> Resource:
	var result: Resource = Definition.new()
	result.effect_name = name
	result.scene = load("res://vfx/shared/pool_probe.tscn")
	result.pool_size = count
	result.duration = 0.12
	return result

func run() -> void:
	manager = root.get_node("VFXManager")
	if not manager.warmup_complete:
		await manager.warmup_finished
	check(manager.stats().pooled==8 and manager.stats().available==8, "Autoload preallocates eight named probe scenes")
	check(manager.stats().active==0 and manager.get_node_or_null("WarmupViewport")==null, "Warm-up leaves no active effect or viewport")
	check(manager.warmup_rendered == (DisplayServer.get_name()!="headless"), "Headless skip is reported honestly; renderer performs real warm-up")
	if DisplayServer.get_name()!="headless":
		check(manager._entries[&"framework_probe"].get("warmup_draws",0)>0, "Warm-up viewport submitted the actual GPU particle draw")
	var initial_nodes: int = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var initial_children: int = manager.get_node("Pools").get_child_count()
	var ids: Dictionary = {}
	manager.set_quality(manager.Quality.HIGH)
	for i in range(100):
		var fx: Node3D = manager.spawn(&"framework_probe",Transform3D(Basis.IDENTITY,Vector3(i%3,1,0)))
		if is_instance_valid(fx):
			ids[fx.get_instance_id()] = true
			manager.release(fx)
	check(ids.size()<=8 and manager.stats().active==0 and manager.stats().available==8, "100 spawn/release cycles reuse the fixed pool")
	check(manager.get_node("Pools").get_child_count()==initial_children, "100 cycles do not grow pooled node count")
	await frames(2)
	check(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))==initial_nodes, "No residual scene nodes after 100 cycles")
	var accepted: int = 0
	for i in range(100):
		if manager.spawn(&"framework_probe"):
			accepted += 1
	check(accepted==8 and manager.stats().active==8 and manager.stats().pooled==8, "100 simultaneous requests cap at eight instances")
	check(manager.stats().particle_budget==128, "High stress is bounded at 128 GPU particles")
	await frames(32)
	check(manager.stats().active==0 and manager.stats().available==8, "Duration expiry automatically returns every instance")
	check(not manager.spawn(&"missing"), "Unknown name is safely rejected")
	var high: Node3D = manager.spawn(&"framework_probe")
	check(high.effective_particles()==16 and high.get_node("Sparks").amount==16, "High uses authored amount with fixed GPU allocation")
	var old_lease: int = high.lease_id
	manager.release(high)
	check(not manager.release(high), "Double return cannot duplicate a free slot")
	var reused: Node3D = manager.spawn(&"framework_probe")
	reused.finish(old_lease)
	check(reused.active, "Old asynchronous lease cannot finish a reused instance")
	manager.clear()
	manager.quality = manager.Quality.LOW
	var low: Node3D = manager.spawn(&"framework_probe")
	check(low.effective_particles()==8 and low.get_node("Sparks").amount==16, "Low halves emissions without resizing the GPU buffer")
	manager.release(low)
	manager.set_quality(manager.Quality.MEDIUM)
	var medium: Node3D = manager.spawn(&"framework_probe")
	check(medium.effective_particles()==12, "Medium uses 75 percent of authored particles")
	manager.release(medium)
	manager.set_quality(manager.Quality.HIGH)
	var again: Node3D = manager.spawn(&"framework_probe")
	check(again.effective_particles()==16, "Repeated quality changes do not compound amounts")
	manager.enabled = false
	check(manager.stats().active==0 and not manager.spawn(&"framework_probe"), "Off clears active decorative effects and rejects new ones")
	manager.set_enabled(true)
	var anchor: Node3D = Node3D.new()
	root.add_child(anchor)
	anchor.position = Vector3(2,1,3)
	var followed: Node3D = manager.spawn(&"framework_probe",Transform3D.IDENTITY,{"follow":anchor})
	await frames(2)
	check(followed.global_position.is_equal_approx(anchor.global_position), "Follow uses a weak visual anchor")
	anchor.queue_free()
	await frames(3)
	check(manager.stats().active==0, "Freeing follow anchor returns the effect")
	var essential: Resource = definition(&"essential_probe",1)
	essential.essential = true
	check(manager.register_definition(essential), "New named scene can be registered at load time")
	check(not manager.spawn(&"essential_probe"), "New scene cannot cast before warm-up")
	await manager.warm_up()
	check(not manager.register_definition(essential), "Duplicate names do not add pool nodes")
	manager.set_quality(manager.Quality.LOW)
	manager.set_enabled(false)
	var warning: Node3D = manager.spawn(&"essential_probe")
	check(is_instance_valid(warning) and warning.effective_particles()==16, "Essential telegraph survives Off and quality reduction")
	manager.clear()
	manager.set_enabled(true)
	var bad: Node3D = Node3D.new()
	bad.set_script(PooledEffect)
	var body: StaticBody3D = StaticBody3D.new()
	bad.add_child(body)
	body.owner = bad
	var packed: PackedScene = PackedScene.new()
	packed.pack(bad)
	var invalid: Resource = definition(&"bad")
	invalid.scene = packed
	check(not manager.register_definition(invalid), "Visual pool rejects gameplay collision bodies")
	bad.free()
	var oversized: Node3D = load("res://vfx/shared/pool_probe.tscn").instantiate()
	oversized.get_node("Sparks").amount = 600
	var capped_scene: PackedScene = PackedScene.new()
	capped_scene.pack(oversized)
	oversized.free()
	var regular: Resource = definition(&"capped_regular",1)
	regular.scene = capped_scene
	var ultimate: Resource = definition(&"capped_ultimate",1)
	ultimate.scene = capped_scene
	ultimate.ultimate = true
	check(manager.register_definition(regular) and manager.register_definition(ultimate), "Particle-heavy scenes are registered with per-effect budgets")
	var cpu_root: Node3D = Node3D.new()
	cpu_root.set_script(PooledEffect)
	var cpu: CPUParticles3D = CPUParticles3D.new()
	cpu.name = "Sparks"
	cpu.amount = 16
	cpu.emitting = false
	cpu.mesh = PrismMesh.new()
	cpu_root.add_child(cpu)
	cpu.owner = cpu_root
	var cpu_scene: PackedScene = PackedScene.new()
	cpu_scene.pack(cpu_root)
	cpu_root.free()
	var cpu_definition: Resource = definition(&"cpu_probe",1)
	cpu_definition.scene = cpu_scene
	check(manager.register_definition(cpu_definition), "CPU particle scene uses the same pooled contract")
	await manager.warm_up()
	manager.set_quality(manager.Quality.HIGH)
	var regular_fx: Node3D = manager.spawn(&"capped_regular")
	var ultimate_fx: Node3D = manager.spawn(&"capped_ultimate")
	check(regular_fx.effective_particles()<=200 and ultimate_fx.effective_particles()<=500, "Normal/ultimate particle emissions are capped at 200/500 per effect")
	manager.clear()
	manager.set_quality(manager.Quality.LOW)
	var cpu_low: Node3D = manager.spawn(&"cpu_probe")
	check(cpu_low.effective_particles()==8, "CPU Low amount is scaled from the original authored value")
	var owned_tween: Tween = cpu_low.track_tween(cpu_low.create_tween())
	owned_tween.tween_property(cpu_low,"rotation:y",1.0,3)
	manager.release(cpu_low)
	var rotation_on_return: Vector3 = cpu_low.rotation
	await frames(2)
	check(not owned_tween.is_running() and cpu_low.rotation.is_equal_approx(rotation_on_return), "Return stops tracked visual tweens without residual motion")
	manager.set_quality(manager.Quality.HIGH)
	var cpu_high: Node3D = manager.spawn(&"cpu_probe")
	check(cpu_high.effective_particles()==16, "CPU High restores authored value without compounded scaling")
	manager.clear()
	var bound: Resource = definition(&"cast_probe",2)
	bound.event = &"cast_started"
	bound.hero = &"knight"
	bound.skill = &"shield_charge"
	check(manager.register_definition(bound), "Resource can bind a name to hero, skill and event")
	await manager.warm_up()
	manager.presentation_event.connect(events)
	var arena: Node3D = load("res://scenes/EmptyArena.tscn").instantiate()
	root.add_child(arena)
	var actor: PlayerController = load("res://scenes/Player.tscn").instantiate()
	actor.external_controlled = true
	actor.position=Vector3(0,0.1,3)
	arena.add_child(actor)
	await frames(4)
	check(manager.stats().observed>=1, "Actors are observed without combat-side manager calls")
	var energy: float = actor.stamina_component.current_stamina
	var hp: float = actor.health_component.current_health
	check(actor.ability_system.cast_ability("skill_1"), "Real existing cast signal routes into the pool")
	check(manager.stats().active==1 and received.back().event==&"cast_started", "Matching signal spawns one bound scene")
	check(is_equal_approx(actor.stamina_component.current_stamina,energy-20) and actor.health_component.current_health==hp, "Signal listener leaves gameplay cost and health unchanged")
	manager.clear()
	var mismatch_before: int = manager.stats().spawned
	manager.dispatch(&"cast_started",{"hero":&"wizard","skill":&"shield_charge","position":Vector3.ZERO})
	check(manager.stats().spawned==mismatch_before, "Hero filter prevents cross-character effects")
	manager.dispatch(&"cast_started",{"hero":&"knight","skill":&"sky_dive","position":Vector3.ZERO})
	check(manager.stats().spawned==mismatch_before, "Skill filter prevents unrelated effects")
	actor.combat.hit_landed.emit(actor,1,false)
	check(received.back().event==&"hit", "Existing hit signal is observed")
	actor.combat.hit_landed.emit(actor,1,true)
	check(received.back().event==&"block", "Existing blocked hit signal is observed")
	actor.shield_broken.emit()
	check(received.back().event==&"shield_break", "Existing shield break signal is observed")
	actor.ability_action_finished.emit("skill_1")
	check(received.back().event==&"skill_finished", "Existing Knight completion signal is observed")
	check(actor.has_signal("presentation_cast_started") and actor.has_signal("presentation_skill_finished") and actor.combat.has_signal("presentation_impact_frame"), "Missing exact timing hooks exist as declarations only")
	actor.combat.presentation_impact_frame.emit(&"test",Vector3.ONE,Vector3.UP)
	check(received.back().event==&"impact_frame", "Reserved hook is ready for a future impact signal")
	manager.spawn(&"framework_probe",Transform3D.IDENTITY,{"actor":actor})
	arena.queue_free()
	await frames(4)
	check(manager.stats().active==0 and manager.stats().observed==0, "Actor/scene exit clears owned leases and observer records")
	manager.set_quality(manager.Quality.MEDIUM)
	for effect: Node3D in manager.get_node("Pools").get_children():
		check(not effect.active and not effect.is_processing() and not effect.get_node("Sparks").emitting, "Idle pooled scene is hidden, stopped and not emitting")
	print("RESULTS: %d/%d PASSED" % [passed,passed+failed])
	quit(0 if failed==0 else 1)
