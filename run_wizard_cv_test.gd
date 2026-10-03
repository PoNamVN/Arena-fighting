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

func glide(look_up: bool=false) -> void:
	player._camera_pitch=deg_to_rad(35) if look_up else 0
	player.camera_pivot.rotation.x=player._camera_pitch
	action("skill_3",true)
	await frames(1)

func release_glide() -> void:
	action("skill_3",false)
	await frames(1)

func ready_storm() -> WizardStormUltimate:
	player.stamina_component.current_stamina=100
	var storm: WizardStormUltimate=player.wizard_combat.storm
	check(storm.begin(), "V enters aim with full energy")
	await frames(25)
	return storm

func _run() -> void:
	root.size=Vector2i(1152,720)
	arena=load("res://scenes/EmptyArena.tscn").instantiate()
	root.add_child(arena)
	await fresh()
	var kit: WizardCombat=player.wizard_combat
	check(player.ability_system.get_ability("skill_3").id=="wizard_ice_glide" and player.ability_system.get_ability("ultimate").requires_full_stamina, "C/V loadout isolated and Ultimate requires full energy")
	check(not kit.ice.begin() and not kit.storm.begin(), "Zero energy rejects C/V")
	player.stamina_component.current_stamina=100
	var start: Vector3=player.global_position
	await glide()
	check(kit.ice.active and player.ability_system.get_cooldown_remaining("skill_3")>0, "Real held C starts glide and cooldown")
	await frames(25)
	check(player.global_position.distance_to(start)>3 and kit.ice.tiles.size()>2, "Glide moves and leaves physical ice")
	check(player.stamina_component.current_stamina<80 and player.stamina_component.current_stamina>70, "C drains continuously after15 energy start")
	var tile_pos: Vector3=kit.ice.tiles[0].body.global_position
	check(not kit.start_charge() and not kit.start_staff() and not kit.storm.begin(), "Glide rejects overlapping attacks")
	await release_glide()
	check(not kit.ice.active and kit.ice.tiles.size()>0, "C release stops movement while ice remains temporarily")
	await frames(10)
	check(kit.ice.tiles[0].body.global_position==tile_pos, "Ice stays in world instead of following character")
	await frames(250)
	check(kit.ice.tiles.is_empty(), "Temporary ice expires")
	await fresh()
	kit=player.wizard_combat
	player.stamina_component.current_stamina=100
	enemy.position.x=5
	await glide(true)
	await frames(100)
	check(player.global_position.y>2, "Aiming upward builds a climbable mountain (height=%s elapsed=%s tiles=%s forward=%s)" % [player.global_position.y,kit.ice.elapsed,kit.ice.tiles.size(),-player.camera.global_basis.z])
	check(player.global_position.y<=kit.ice.baseline+WizardIceGlide.MAX_HEIGHT+0.25, "Mountain height bounded")
	await release_glide()
	await fresh()
	kit=player.wizard_combat
	player.stamina_component.current_stamina=20
	await glide()
	await frames(45)
	check(not kit.ice.active and player.stamina_component.current_stamina<0.3, "Glide stops on depleted energy")
	await release_glide()
	await fresh()
	kit=player.wizard_combat
	player.stamina_component.current_stamina=100
	var wall: StaticBody3D=wall_at(Vector3(0,2,0))
	await frames(3)
	await glide()
	await frames(50)
	check(player.global_position.z>0.4 and not kit.ice.active, "Wall collision stops glide without tunneling")
	await release_glide()
	wall.queue_free()
	await fresh()
	kit=player.wizard_combat
	player.stamina_component.current_stamina=100
	enemy.position.z=1
	await glide()
	await frames(7)
	check(enemy.frost.active() and is_instance_valid(enemy.frost.shell), "Glide contact freezes enemy")
	check(not enemy._try_combat_attack() and not enemy._try_dodge() and not enemy._start_block(), "Frozen actor cannot fight")
	var frozen_pos: Vector3=enemy.global_position
	enemy.external_move_direction=Vector3.RIGHT
	await frames(10)
	check(enemy.global_position.distance_to(frozen_pos)<0.02, "Freeze stops movement (delta=%s active=%s)" % [enemy.global_position-frozen_pos,enemy.frost.active()])
	await release_glide()
	enemy.external_move_direction=Vector3.ZERO
	await frames(55)
	check(not enemy.frost.active() and enemy.polymorph.resistance>0 and not enemy.polymorph.begin(), "Freeze expires with shared CC resistance")
	await fresh()
	kit=player.wizard_combat
	player.stamina_component.current_stamina=100
	await glide()
	await frames(10)
	player.health_component.take_damage(1000)
	await frames(3)
	check(not kit.ice.active and kit.ice.tiles.is_empty(), "Death removes all created ice")
	await release_glide()
	await fresh()
	kit=player.wizard_combat
	var storm: WizardStormUltimate=await ready_storm()
	check(storm.phase==WizardStormUltimate.Phase.AIM and is_equal_approx(player.stamina_component.current_stamina,100), "Aim reserves no energy")
	check(not player._is_mouse_captured and storm.camera.current, "V zoom camera frees cursor")
	check(not player.health_component.ability_invulnerable, "Aiming grants no immunity")
	check(not storm.confirm(Vector3(100,0,0)), "Out-of-range Ultimate rejected without spending")
	storm.stop()
	check(player._is_mouse_captured and player.camera.current and is_equal_approx(player.stamina_component.current_stamina,100), "Aim cancel restores camera/cursor and energy")
	await fresh()
	kit=player.wizard_combat
	if DisplayServer.get_name()!="headless":
		enemy.position.x=5
		player.stamina_component.current_stamina=100
		await glide(true)
		await frames(95)
		await release_glide()
		player._camera_pitch=deg_to_rad(-15)
		player.camera_pivot.rotation.x=player._camera_pitch
		await frames(2)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://scratch/wizard_ice_preview.png")
		await fresh()
		kit=player.wizard_combat
	storm=await ready_storm()
	check(storm.confirm(Vector3(0,0,-5)), "Valid selected ground confirms storm")
	var storm_light: DirectionalLight3D=arena.get_node("DirectionalLight3D")
	var original_light_energy: float=storm._original_energy
	check(is_equal_approx(storm_light.light_energy,original_light_energy) and storm._dark_environment.background_mode==storm._original_environment.background_mode and is_equal_approx(storm._dark_environment.background_energy_multiplier,storm._original_environment.background_energy_multiplier), "Weather starts at original sky and light without a jump")
	check(storm.channeling() and is_instance_valid(storm.shield) and is_equal_approx(player.stamina_component.current_stamina,0), "Commit spends100 and raises full spherical shield")
	var hp: float=player.health_component.current_health
	player.take_damage(999,enemy.global_position,100)
	player.health_component.take_damage(999)
	player.apply_knockback(Vector3.RIGHT,10,1)
	check(is_equal_approx(player.health_component.current_health,hp) and player._knockback_timer<=0 and is_equal_approx(player.shield_durability,100), "Channel immunity blocks all directions, raw HP damage, knockback and shield damage")
	check(not player.polymorph.begin() and not player.frost.begin(), "Channel cannot be interrupted by polymorph or freeze")
	check(not kit.start_charge() and not kit.start_staff() and not kit.ice.begin(), "Channel disallows other skills")
	start=player.global_position
	action("move_forward",true)
	await frames(30)
	action("move_forward",false)
	check(player.global_position.distance_to(start)<0.02, "Storm channels stationary")
	check(storm.strikes_spawned>0 and storm.strikes_landed>0 and storm.weather!=null, "Clouds, warning circles and lightning run")
	var in_zone: bool=true
	for strike: Dictionary in storm.strikes:
		in_zone = in_zone and Vector2(strike.point.x-storm.ground.x,strike.point.z-storm.ground.z).length()<=WizardStormUltimate.RADIUS+0.01
	check(in_zone, "Random bolts stay within zone")
	var environment: WorldEnvironment=arena.get_node("WorldEnvironment")
	check(environment.environment==storm._dark_environment, "Storm darkens sky using a private environment")
	var partial_energy: float=storm_light.light_energy
	check(partial_energy<original_light_energy and partial_energy>0.35, "First half second gradually darkens lighting")
	await frames(70)
	check(is_equal_approx(storm_light.light_energy,0.35), "Storm reaches full darkness after fade in")
	await frames(170)
	check(storm.channeling() and storm_light.light_energy>0.35 and storm_light.light_energy<original_light_energy, "Last half second gradually brightens while channel is active")
	await frames(50)
	check(is_equal_approx(storm_light.light_energy,original_light_energy), "Lighting ends at its original energy")
	check(not storm.active() and not player.health_component.ability_invulnerable and storm.shield==null and storm.weather==null and storm.strikes.is_empty(), "Five-second storm removes shield/weather/warnings")
	check(storm.strikes_spawned==20 and storm.strikes_landed==20, "All20 warned bolts land within5 seconds")
	check(environment.environment!=storm._dark_environment and player.camera.current and player._is_mouse_captured, "Sky and camera restored after storm")
	player.take_damage(10,enemy.global_position)
	check(player.health_component.current_health<hp, "Immunity ends with channel")
	await fresh()
	kit=player.wizard_combat
	storm=await ready_storm()
	player.take_damage(1,enemy.global_position)
	check(not storm.active() and not player.health_component.ability_invulnerable, "Hit cancels aim before immunity")
	await fresh()
	kit=player.wizard_combat
	storm=await ready_storm()
	storm.confirm(Vector3(0,0,-5))
	player.controls_enabled=false
	await frames(3)
	check(not storm.active() and not player.health_component.ability_invulnerable and player.camera.current, "Round lock clears storm, immunity and camera")
	await fresh()
	kit=player.wizard_combat
	enemy.position=Vector3(0,0.1,-5)
	storm=await ready_storm()
	storm.confirm(Vector3(0,0,-5))
	var energy: float=player.stamina_component.current_stamina
	var enemy_hp: float=enemy.health_component.current_health
	storm._damage_at(enemy.global_position)
	check(is_equal_approx(enemy.health_component.current_health,enemy_hp-24) and is_equal_approx(player.stamina_component.current_stamina,energy), "Bolt deals24 via shared combat with no energy farming")
	storm.stop()
	await fresh()
	kit=player.wizard_combat
	player.set_third_person(false)
	storm=await ready_storm()
	storm.confirm(Vector3(0,0,-5))
	storm.stop()
	check(not player.is_third_person and player.camera.current, "V restores original FPS camera")
	await fresh()
	kit=player.wizard_combat
	storm=await ready_storm()
	var click: InputEventMouseButton=InputEventMouseButton.new()
	click.button_index=MOUSE_BUTTON_LEFT
	click.pressed=true
	click.position=storm.camera.unproject_position(Vector3(0,0,-5))
	Input.parse_input_event(click)
	Input.flush_buffered_events()
	await frames(1)
	check(storm.channeling(), "Real LMB picks ground from zoomed camera")
	storm.stop()
	click.pressed=false
	Input.parse_input_event(click)
	Input.flush_buffered_events()
	await fresh()
	kit=player.wizard_combat
	wall=wall_at(Vector3(0,2,0))
	await frames(3)
	storm=await ready_storm()
	check(not storm.confirm(Vector3(0,0,-5)) and is_equal_approx(player.stamina_component.current_stamina,100), "Wall blocks Ultimate ground selection")
	storm.stop()
	wall.queue_free()
	await fresh()
	kit=player.wizard_combat
	storm=await ready_storm()
	storm.confirm(Vector3(0,0,-5))
	enemy.dodge_controller.dodge_distance=0
	enemy.stamina_component.current_stamina=100
	enemy._try_dodge()
	await frames(5)
	var enemy_before: float=enemy.health_component.current_health
	storm._damage_at(enemy.global_position)
	check(is_equal_approx(enemy.health_component.current_health,enemy_before) and enemy.is_counter_window_active(), "Lightning supports real i-frame and Perfect Dodge")
	storm.stop()
	CombatTimeManager.reset_time()
	await fresh()
	kit=player.wizard_combat
	player.stamina_component.training_infinite=true
	player.stamina_component.current_stamina=100
	enemy.position.x=5
	await glide()
	await frames(210)
	check(not kit.ice.active and is_equal_approx(player.stamina_component.current_stamina,100) and kit.ice.tiles.size()<=55, "F1 keeps energy while C duration and tile count stay bounded")
	await release_glide()
	kit.reset()
	check(kit.ice.tiles.is_empty() and is_equal_approx(player.floor_snap_length,0.1), "Reset removes ice and restores floor snap")
	await fresh()
	kit=player.wizard_combat
	player.stamina_component.current_stamina=100
	await glide()
	await frames(5)
	player.take_damage(1,enemy.global_position)
	check(not kit.ice.active, "Taking damage interrupts glide without immunity")
	await release_glide()
	await fresh()
	check(enemy.frost.begin() and not enemy.polymorph.begin(), "Freeze cannot chain directly into chicken CC")
	enemy.frost.clear()
	check(enemy.platform_floor_layers==4294967295, "Freeze restores platform layers")
	arena.queue_free()
	await frames(3)
	PracticeArena.selected_hero="wizard"
	var match_room: PracticeArena=load("res://scenes/PracticeArena.tscn").instantiate() as PracticeArena
	root.add_child(match_room)
	await frames(200)
	match_room.player.stamina_component.current_stamina=100
	var practice_storm: WizardStormUltimate=match_room.player.wizard_combat.storm
	check(practice_storm.begin(), "Actual practice allows Ultimate after countdown")
	await frames(25)
	check(practice_storm.confirm(Vector3(0,0,-5)), "Practice ground selection works")
	match_room._finish_round()
	check(not practice_storm.active() and not match_room.player.health_component.ability_invulnerable and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE, "Practice results clear immunity and leave results cursor")
	match_room.queue_free()
	await frames(3)
	PracticeArena.selected_hero="knight"
	arena=load("res://scenes/EmptyArena.tscn").instantiate()
	root.add_child(arena)
	await fresh()
	kit=player.wizard_combat
	storm=await ready_storm()
	storm.confirm(Vector3(0,0,-5))
	if DisplayServer.get_name()!="headless":
		await frames(55)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://scratch/wizard_storm_preview.png")
	var exit_mouse_mode: int=storm._previous_mode
	arena.queue_free()
	await frames(3)
	check(Input.mouse_mode==exit_mouse_mode, "Active scene exit restores mouse mode")
	CombatTimeManager.reset_time()
	print("RESULTS: %d/%d PASSED" % [passed,total])
	quit(0 if passed==total else 1)
