extends SceneTree
var passed: int = 0
var total: int = 0
var arena: Node3D
var player: PlayerController
var enemy: PlayerController

func _init() -> void:
	_run.call_deferred()

func check(value: bool, description: String) -> void:
	total += 1
	if value:
		passed += 1
	print("[%s] TEST %d: %s" % ["PASS" if value else "FAIL", total, description])

func frames(count: int) -> void:
	for i: int in range(count):
		await physics_frame
		await process_frame

func action(name: String, pressed: bool) -> void:
	var event: InputEventAction = InputEventAction.new()
	event.action = name
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func fresh() -> void:
	CombatTimeManager.reset_time()
	if is_instance_valid(player):
		player.queue_free()
	if is_instance_valid(enemy):
		enemy.queue_free()
	await frames(2)
	player = load("res://scenes/Player.tscn").instantiate() as PlayerController
	player.hero_profile = "wizard"
	player.position = Vector3(0, 0.1, 3)
	arena.add_child(player)
	enemy = load("res://scenes/Player.tscn").instantiate() as PlayerController
	enemy.external_controlled = true
	enemy.position = Vector3(0, 0.1, -5)
	enemy.collision_layer = 4
	enemy.collision_mask = 3
	enemy.get_node("HealthComponent").max_health = 500.0
	arena.add_child(enemy)
	await frames(5)
	player.stamina_component.current_stamina = 0.0

func fire(charge_frames: int = 100) -> void:
	action("attack", true)
	await frames(charge_frames)
	if charge_frames >= 100:
		for attempt: int in range(150):
			if not player.wizard_combat.charging or player.wizard_combat.charge_time >= WizardCombat.MAX_CHARGE:
				break
			await frames(1)
	action("attack", false)
	await frames(1)

func perfect() -> void:
	player.dodge_controller.dodge_distance = 0
	player._try_dodge()
	await frames(5)
	var payload: AttackPayload = AttackPayload.new(25, enemy.global_position)
	payload.attacker = enemy
	player.take_damage(payload)
	check(player.is_counter_window_active(), "Real Perfect Dodge opens window")

func wall_at(pos: Vector3) -> StaticBody3D:
	var wall: StaticBody3D = StaticBody3D.new()
	wall.collision_layer = 1
	var collision: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(6, 4, 0.2)
	collision.shape = box
	wall.add_child(collision)
	arena.add_child(wall)
	wall.position = pos
	return wall

func _run() -> void:
	root.size=Vector2i(1152,720)
	arena=load("res://scenes/EmptyArena.tscn").instantiate() as Node3D
	root.add_child(arena)
	await fresh()
	var kit: WizardCombat=player.wizard_combat
	player.stamina_component.current_stamina=100
	action("skill_1",true)
	action("skill_1",false)
	await frames(1)
	check(kit.staff_strike.active and is_instance_valid(kit.staff_strike.outline), "Real Z creates staff and outline")
	check(is_equal_approx(player.stamina_component.current_stamina,70) and player.ability_system.get_cooldown_remaining("skill_1")>0, "Z spends30 and starts7s cooldown once")
	check(not kit.start_charge() and not kit.start_polymorph() and not kit.start_staff(), "Z prevents overlapping casts")
	await frames(30)
	check(is_equal_approx(enemy.health_component.current_health,500) and not kit.staff_strike.struck, "Warning gives reaction time before impact")
	await frames(55)
	check(is_equal_approx(enemy.health_component.current_health,462), "Z hits target on strip once for38")
	check(enemy.global_position.z < -5.5, "Unblocked Z pushes enemy away")
	await frames(50)
	check(not kit.staff_strike.active and kit.staff_strike.pivot==null, "Staff and outline disappear")
	check(is_equal_approx(player.stamina_component.current_stamina,70), "Z hit gives no basic energy")
	await fresh()
	kit=player.wizard_combat
	player.stamina_component.current_stamina=100
	enemy.position.x=4
	kit.start_staff()
	await frames(130)
	check(is_equal_approx(enemy.health_component.current_health,500), "Enemy outside outline avoids Z")
	await fresh()
	kit=player.wizard_combat
	player.stamina_component.current_stamina=100
	enemy.visuals.rotation.y=PI
	enemy._camera_yaw=PI
	enemy._start_block()
	kit.start_staff()
	await frames(100)
	check(is_equal_approx(enemy.health_component.current_health,494.3) and is_equal_approx(enemy.shield_durability,70), "Front block mitigates Z and loses30 shield")
	await fresh()
	kit=player.wizard_combat
	player.stamina_component.current_stamina=100
	var wall: StaticBody3D=wall_at(Vector3(0,2,0))
	await frames(3)
	kit.start_staff()
	check(kit.staff_strike.length<3, "Wall shortens warning and staff")
	await frames(130)
	check(is_equal_approx(enemy.health_component.current_health,500), "Z cannot hit through wall")
	wall.queue_free()
	await fresh()
	kit=player.wizard_combat
	player.stamina_component.current_stamina=100
	kit.start_staff()
	player.take_damage(1,enemy.global_position)
	await frames(100)
	check(not kit.staff_strike.active and is_equal_approx(enemy.health_component.current_health,500), "Damage interrupts Z before impact")
	check(is_equal_approx(player.stamina_component.current_stamina,70), "Interrupted Z does not refund energy")
	await fresh()
	kit=player.wizard_combat
	check(not kit.start_staff() and not kit.start_polymorph(), "Insufficient energy rejects both spells")
	player.stamina_component.current_stamina=100
	action("skill_2",true)
	action("skill_2",false)
	await frames(1)
	check(kit.spell=="X" and kit._projectiles.is_empty(), "X has startup instead of instant hit")
	check(is_equal_approx(player.stamina_component.current_stamina,75) and player.ability_system.get_cooldown_remaining("skill_2")>8, "X spends25 and starts9s cooldown")
	await frames(30)
	check(enemy.polymorph.active() and is_instance_valid(enemy.polymorph.chicken), "Physical X turns enemy into visible chicken")
	check(not enemy.visuals.get_node("CharacterModel").visible and is_equal_approx(enemy.health_component.current_health,500), "Original model hidden, X deals no HP damage")
	check(not enemy._try_combat_attack() and not enemy._try_dodge() and not enemy._start_block() and not enemy._try_cast_ability("skill_3"), "Chicken cannot attack, dodge, guard or use abilities")
	var start: Vector3=enemy.global_position
	enemy.external_move_direction=Vector3.RIGHT
	await frames(20)
	check(enemy.global_position.distance_to(start)>0.5, "Chicken can run")
	enemy.external_move_direction=Vector3.ZERO
	enemy.take_damage(10,player.global_position)
	check(is_equal_approx(enemy.health_component.current_health,490), "Chicken still takes damage")
	check(not enemy.polymorph.begin(), "Active transform cannot refresh lock")
	await frames(100)
	check(not enemy.polymorph.active() and enemy.visuals.get_node("CharacterModel").visible and enemy.polymorph.chicken==null, "Timeout restores exact original model")
	check(enemy.polymorph.resistance>0 and not enemy.polymorph.begin(), "Short resistance prevents immediate repeated CC")
	await frames(130)
	check(enemy.polymorph.begin(), "Resistance expires normally")
	enemy.polymorph.clear()
	await fresh()
	kit=player.wizard_combat
	player.stamina_component.current_stamina=100
	enemy.visuals.rotation.y=PI
	enemy._camera_yaw=PI
	enemy._start_block()
	kit.start_polymorph()
	await frames(40)
	check(not enemy.polymorph.active() and is_equal_approx(enemy.shield_durability,85), "Front shield blocks X and costs15 durability")
	await fresh()
	kit=player.wizard_combat
	player.stamina_component.current_stamina=100
	kit.start_polymorph()
	await frames(21)
	enemy.stamina_component.current_stamina=100
	enemy.dodge_controller.dodge_distance=0
	enemy._try_dodge()
	await frames(14)
	check(not enemy.polymorph.active() and enemy.dodge_controller.perfect_dodge_count==1, "Real i-frame avoids X and triggers Perfect Dodge")
	CombatTimeManager.reset_time()
	await fresh()
	kit=player.wizard_combat
	player.stamina_component.current_stamina=100
	wall=wall_at(Vector3(0,2,0))
	await frames(3)
	kit.start_polymorph()
	await frames(80)
	check(not enemy.polymorph.active() and kit._projectiles.is_empty(), "X projectile stops at world wall")
	wall.queue_free()
	await fresh()
	kit=player.wizard_combat
	player.stamina_component.current_stamina=100
	kit.start_polymorph()
	kit.start_block()
	await frames(50)
	check(kit.spell=="" and kit._projectiles.is_empty() and not enemy.polymorph.active(), "Guard interrupts X startup")
	check(is_equal_approx(player.stamina_component.current_stamina,75), "Canceled X keeps energy cost")
	await fresh()
	check(enemy._try_combat_attack(), "Enemy attack starts before polymorph")
	check(enemy.polymorph.begin() and not enemy.is_attacking and enemy._attack_impact_applied, "Polymorph cancels pending melee impact")
	enemy.health_component.take_damage(1000)
	await frames(2)
	check(enemy.is_dead and not enemy.polymorph.active() and enemy.visuals.get_node("CharacterModel").visible, "Death restores original model and clears chicken")
	await fresh()
	var dummy: TrainingDummy=load("res://scenes/TrainingDummy.tscn").instantiate() as TrainingDummy
	dummy.position=Vector3(0,0.1,-2)
	arena.add_child(dummy)
	await frames(3)
	check(dummy.polymorph.begin() and not dummy.body_mesh.visible, "Training dummy supports chicken visuals")
	dummy.reset_dummy()
	check(not dummy.polymorph.active() and dummy.body_mesh.visible, "Dummy reset restores visuals")
	dummy.queue_free()
	await fresh()
	kit=player.wizard_combat
	player.stamina_component.current_stamina=100
	kit.start_staff()
	player.controls_enabled=false
	await frames(3)
	check(not kit.staff_strike.active and kit.staff_strike.outline==null, "Round lock clears staff/outline")
	enemy.polymorph.begin()
	enemy.controls_enabled=false
	await frames(2)
	check(not enemy.polymorph.active(), "Round lock clears polymorph")
	await fresh()
	kit=player.wizard_combat
	player.stamina_component.current_stamina=100
	kit.start_staff()
	await frames(66)
	enemy.stamina_component.current_stamina=100
	enemy.dodge_controller.dodge_distance=0
	enemy._try_dodge()
	await frames(9)
	check(is_equal_approx(enemy.health_component.current_health,500) and enemy.is_counter_window_active(), "Perfect Dodge avoids Z impact and opens Counter")
	CombatTimeManager.reset_time()
	await fresh()
	kit=player.wizard_combat
	player.stamina_component.current_stamina=100
	enemy.visuals.rotation.y=0
	enemy._camera_yaw=0
	enemy._start_block()
	kit.start_polymorph()
	await frames(35)
	check(enemy.polymorph.active() and not enemy.is_blocking, "Rear X bypasses shield and cancels guard")
	await fresh()
	kit=player.wizard_combat
	player.stamina_component.current_stamina=100
	kit.start_polymorph()
	await frames(15)
	enemy.position.x=5
	await frames(65)
	check(not enemy.polymorph.active(), "X commits direction, moving enemy can avoid it")
	await fresh()
	kit=player.wizard_combat
	player.stamina_component.current_stamina=100
	kit.start_polymorph()
	player.health_component.take_damage(1000)
	await frames(40)
	check(kit.spell=="" and kit._projectiles.is_empty() and not enemy.polymorph.active(), "Caster death cancels X startup and projectile")
	arena.queue_free()
	await frames(3)
	PracticeArena.selected_hero="wizard"
	var match_room: PracticeArena=load("res://scenes/PracticeArena.tscn").instantiate() as PracticeArena
	root.add_child(match_room)
	await frames(200)
	match_room.brain.skill_warning_remaining=0.4
	match_room.brain.warning_ring.show()
	check(match_room.opponent.polymorph.begin(), "Actual practice AI can be polymorphed")
	var attack_count: int=match_room.brain.attacks_started
	var skill_count: int=match_room.brain.skills_started
	await frames(50)
	check(match_room.brain.attacks_started==attack_count and match_room.brain.skills_started==skill_count and match_room.brain.skill_warning_remaining==0, "Chicken AI retreats and cancels queued skill")
	await frames(50)
	check(not match_room.opponent.polymorph.active() and not match_room.brain.warning_ring.visible, "AI warning remains cleared after transform ends")
	match_room.opponent.polymorph.resistance=0
	match_room.opponent.polymorph.begin()
	match_room._finish_round()
	check(not match_room.opponent.polymorph.active(), "Practice results clear target polymorph immediately")
	match_room.queue_free()
	await frames(3)
	PracticeArena.selected_hero="knight"
	arena=load("res://scenes/EmptyArena.tscn").instantiate() as Node3D
	root.add_child(arena)
	if DisplayServer.get_name()!="headless":
		await fresh()
		kit=player.wizard_combat
		player.stamina_component.current_stamina=100
		kit.start_staff()
		enemy.polymorph.begin()
		var camera: Camera3D=Camera3D.new()
		arena.add_child(camera)
		camera.global_position=Vector3(8,7,9)
		camera.look_at(Vector3(0,3,-2))
		camera.current=true
		await frames(25)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://scratch/wizard_zx_preview.png")
	arena.queue_free()
	await frames(3)
	CombatTimeManager.reset_time()
	print("RESULTS: %d/%d PASSED" % [passed,total])
	quit(0 if passed==total else 1)
