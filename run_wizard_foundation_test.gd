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
	root.size = Vector2i(1152,720)
	arena = load("res://scenes/EmptyArena.tscn").instantiate() as Node3D
	root.add_child(arena)
	await fresh()
	var kit: WizardCombat = player.wizard_combat
	check(kit != null and player.archer_combat == null and enemy.wizard_combat == null, "Wizard kit isolated from Knight and Archer")
	check(player.anim_player.has_animation("run") and player._skeleton.get_bone_count()==18, "Separate model retains rig and locomotion")
	check(player.ability_system.get_ability("skill_1").id=="wizard_giant_staff" and player.ability_system.get_ability("ultimate").id=="wizard_lightning_storm", "Future spells cannot cast Knight abilities")
	action("attack", true)
	await frames(10)
	check(kit.charging and kit.locked_target==enemy, "Real held LMB charges and autoaims")
	check(kit.shots_fired==0, "No auto-fire or melee while held")
	var small: float = kit._orb.scale.x
	await frames(100)
	check(is_equal_approx(kit.charge_time,kit.MAX_CHARGE) and kit._orb.scale.x>small, "Charge caps and fireball grows")
	action("attack",false)
	await frames(1)
	check(kit.shots_fired==1 and kit._projectiles.size()==1, "Release creates one physical fireball")
	check(is_equal_approx(enemy.health_component.current_health,500), "Fireball is not hitscan")
	await frames(35)
	check(is_equal_approx(enemy.health_component.current_health,466), "Full fireball deals 34 once")
	check(is_equal_approx(player.stamina_component.current_stamina,15), "Actual basic hit awards energy once")
	await fire(1)
	await frames(40)
	check(enemy.health_component.current_health<456 and enemy.health_component.current_health>455, "Quick fireball deals about 10")
	await fresh()
	kit=player.wizard_combat
	check(kit.start_block(), "Wizard raises magical front guard")
	await frames(2)
	check(kit._shield.visible, "Guard renders visible magical shield")
	player.take_damage(40,enemy.global_position)
	check(is_equal_approx(player.health_component.current_health,90) and is_equal_approx(player.shield_durability,85), "Front guard mitigates 75 percent with durability")
	player._release_block()
	check(not player.is_blocking, "Guard releases")
	await fresh()
	kit=player.wizard_combat
	kit.start_block()
	player.take_damage(25,player.global_position+Vector3.BACK*3)
	check(is_equal_approx(player.health_component.current_health,75) and is_equal_approx(player.shield_durability,100), "Rear damage bypasses magical guard")
	await fresh()
	kit=player.wizard_combat
	action("attack",true)
	await frames(10)
	action("block",true)
	action("attack",false)
	check(player.is_blocking and not kit.charging and kit.shots_fired==0, "Block cancels charge without shot")
	action("block",false)
	await fresh()
	kit=player.wizard_combat
	kit.start_block()
	player.take_damage(10,enemy.global_position,100)
	check(player.is_shield_broken and not kit.start_charge() and not kit.start_block(), "Broken shield gates attacks and guard")
	await frames(135)
	check(not player.is_shield_broken and kit.start_block(), "Test-room shield recovers")
	await fresh()
	kit=player.wizard_combat
	var wall: StaticBody3D = wall_at(Vector3(0,2,0))
	await frames(3)
	check(kit._find_target()==null, "World wall blocks target lock")
	await fire()
	await frames(45)
	check(is_equal_approx(enemy.health_component.current_health,500) and kit._projectiles.is_empty(), "Physical fireball and splash cannot cross wall")
	wall.queue_free()
	await fresh()
	kit=player.wizard_combat
	check(not kit.start_counter(), "Counter requires Perfect Dodge")
	await perfect()
	var start: Vector3 = player.global_position
	action("attack",true)
	action("attack",false)
	await frames(1)
	check(kit.counter_active and kit.counters_fired==1 and not kit.charging, "Fresh LMB casts magic counter")
	check(not player.is_counter_window_active() and not player.dodge_controller.is_dodging, "Counter consumes window and i-frame")
	await frames(55)
	check(is_equal_approx(enemy.health_component.current_health,455), "Counter deals 45 once")
	check(absf(player.global_position.z-start.z-3.2)<0.02, "Counter retreats 3.2m")
	check(not player.is_countering and not kit.counter_active, "Counter finishes in neutral")
	check(is_equal_approx(player.stamina_component.current_stamina,25), "Counter does not farm basic energy")
	await fresh()
	kit=player.wizard_combat
	await perfect()
	wall=wall_at(Vector3(0,2,4.5))
	await frames(2)
	kit.start_counter()
	await frames(55)
	check(player.global_position.z>3 and player.global_position.z<4.15, "Rear wall stops retreat")
	wall.queue_free()
	await fresh()
	kit=player.wizard_combat
	kit.start_charge()
	player._set_mouse_captured(false)
	check(not kit.charging and not kit.release_fireball(), "Escape cancels charge")
	await fresh()
	kit=player.wizard_combat
	await fire()
	player.controls_enabled=false
	await frames(40)
	check(kit._projectiles.is_empty() and is_equal_approx(enemy.health_component.current_health,500), "Round lock removes outgoing spells")
	await fresh()
	kit=player.wizard_combat
	await fire()
	player.health_component.take_damage(1000)
	await frames(40)
	check(player.is_dead and kit._projectiles.is_empty() and not kit.charging, "Death clears magic")
	player.respawn(Vector3(0,0.1,3),0)
	await frames(5)
	check(kit.start_charge(), "Respawn restores wizard input")
	kit.cancel_charge()
	await fresh()
	kit=player.wizard_combat
	enemy.visuals.rotation.y=PI
	enemy._camera_yaw=PI
	enemy._start_block()
	await fire()
	await frames(35)
	check(is_equal_approx(enemy.health_component.current_health,494.9) and is_equal_approx(enemy.shield_durability,85), "Knight front block mitigates fireball exactly once")
	await fresh()
	kit=player.wizard_combat
	action("attack",true)
	await frames(5)
	enemy.queue_free()
	await frames(3)
	check(kit.charging and not is_instance_valid(kit.locked_target), "Deleted locked target safely returns to free aim")
	action("attack",false)
	await frames(90)
	check(kit._projectiles.is_empty(), "Missed fireball expires at range")
	await fresh()
	kit=player.wizard_combat
	var bystander: PlayerController=load("res://scenes/Player.tscn").instantiate() as PlayerController
	bystander.external_controlled=true
	bystander.collision_layer=4
	bystander.position=Vector3(1,0.1,-5)
	arena.add_child(bystander)
	await frames(5)
	await fire()
	await frames(35)
	check(is_equal_approx(enemy.health_component.current_health,466) and is_equal_approx(bystander.health_component.current_health,83), "Full fireball deals half splash to nearby second enemy (primary=%s secondary=%s)" % [enemy.health_component.current_health, bystander.health_component.current_health])
	check(is_equal_approx(player.stamina_component.current_stamina,15) and is_equal_approx(player.health_component.current_health,100), "Splash gives one energy reward and never damages caster")
	bystander.queue_free()
	await fresh()
	kit=player.wizard_combat
	if not DisplayServer.get_name()=="headless":
		kit.recovery_remaining=0
		player.controls_enabled=true
		player.camera.current=false
		var preview: Camera3D=Camera3D.new()
		arena.add_child(preview)
		preview.global_position=player.global_position+Vector3(3,2.1,-4)
		preview.look_at(player.global_position+Vector3(0,1.1,0))
		preview.current=true
		kit.start_charge()
		await frames(45)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://scratch/wizard_preview.png")
	arena.queue_free()
	await frames(3)
	PracticeArena.selected_hero="wizard"
	var room: CombatTestArena=load("res://scenes/CombatTestArena.tscn").instantiate() as CombatTestArena
	root.add_child(room)
	await frames(5)
	check(room.player.wizard_combat!=null and room.hero_select.selected==2 and room.hero_select.item_count==3, "Arena selector exposes and restores third hero")
	room.queue_free()
	await frames(3)
	var match_room: PracticeArena=load("res://scenes/PracticeArena.tscn").instantiate() as PracticeArena
	root.add_child(match_room)
	await frames(5)
	check(match_room.player.wizard_combat!=null and match_room.opponent.hero_profile=="knight", "Practice loads wizard versus Knight AI")
	check(not match_room.player.wizard_combat.start_charge(), "Countdown prevents charging")
	await frames(200)
	check(match_room.player.wizard_combat.start_charge(), "After countdown wizard can attack")
	match_room.player.wizard_combat.cancel_charge()
	match_room.queue_free()
	await frames(3)
	PracticeArena.selected_hero="knight"
	CombatTimeManager.reset_time()
	print("RESULTS: %d/%d PASSED" % [passed,total])
	quit(0 if passed==total else 1)
