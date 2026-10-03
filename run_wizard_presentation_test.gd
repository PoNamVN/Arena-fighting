extends "res://run_wizard_foundation_test.gd"

func snapshot(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var preview: Camera3D = Camera3D.new()
	arena.add_child(preview)
	preview.position = player.position + Vector3(3, 2.2, -4)
	preview.look_at(player.position + Vector3.UP * 1.25)
	preview.make_current()
	await frames(2)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://scratch/wizard_pose_verified_%s.png" % label)
	preview.queue_free()
	player.camera.make_current()

func _run() -> void:
	root.size = Vector2i(1152,720)
	arena = load("res://scenes/EmptyArena.tscn").instantiate() as Node3D
	root.add_child(arena)
	await fresh()
	var kit: WizardCombat = player.wizard_combat
	var pose: Node = kit.presentation
	check(pose._bones.size()==6 and pose.mode=="idle", "Rig bones are cached once, idle is ready")
	check(pose.palm_ring.mesh==pose.ground_ring.mesh and not pose.palm_ring.visible and not pose.ground_ring.visible and not pose.staff_glow.visible, "Three reusable effects share ring geometry and start hidden")
	var initial_energy: float=player.stamina_component.current_stamina
	var initial_health: float=enemy.health_component.current_health
	var initial_position: Vector3=player.position
	check(kit.start_charge(), "Charge starts through existing combat API")
	await frames(65)
	check(pose.mode=="charge" and pose._left_weight>0.8 and pose.palm_ring.visible and pose.staff_glow.visible, "Charging raises hand and lights casting ring and staff")
	await snapshot("charge")
	var grip: Vector3=player._skeleton.to_global(player._skeleton.get_bone_global_pose(player._skeleton.find_bone("hand.R")).origin)
	check(kit._staff.global_position.distance_to(grip)<0.12, "Wooden staff grip follows right hand")
	var ring_id: int=pose.palm_ring.get_instance_id()
	var glow_id: int=pose.staff_glow.get_instance_id()
	var node_count: int=root.get_child_count()
	var started: int=Time.get_ticks_usec()
	for i: int in range(1000):
		pose.update(1.0/60)
	print("Presentation CPU average: %.3f ms/update" % (float(Time.get_ticks_usec()-started)/1000000.0))
	check(pose.palm_ring.get_instance_id()==ring_id and pose.staff_glow.get_instance_id()==glow_id and root.get_child_count()==node_count, "Repeated presentation updates reuse effects")
	check(is_equal_approx(initial_energy,player.stamina_component.current_stamina) and is_equal_approx(initial_health,enemy.health_component.current_health) and player.position.distance_to(initial_position)<0.02, "Presentation has no damage, energy or movement side effects")
	check(kit.release_fireball(), "Release uses unchanged fireball")
	await frames(2)
	check(pose.mode=="release" and pose.release_remaining>0, "Fireball release extends casting hand briefly")
	await frames(28)
	check(pose.mode=="idle" and not pose.palm_ring.visible and not pose.staff_glow.visible, "Release pose and effects recover automatically")
	await frames(10)
	kit.start_block()
	await frames(12)
	check(pose.mode=="guard" and pose._left_weight>0.8, "Guard has raised protective hand")
	await snapshot("guard")
	player._release_block()
	await frames(25)
	player.stamina_component.current_stamina=100
	check(kit.start_staff(), "Giant staff starts unchanged")
	await frames(25)
	check(pose.mode=="staff" and pose._right_hand.y>1.4, "Z raises staff during warning")
	await snapshot("staff")
	for i: int in range(120):
		if not kit.staff_strike.active or kit.staff_strike.elapsed>=1.15:
			break
		await frames(1)
	check(pose.mode=="staff" and pose._staff_pitch < -0.1, "Z hand staff follows the falling phase")
	kit.interrupt()
	await frames(90)
	player.stamina_component.current_stamina=100
	check(kit.start_polymorph(), "Hex starts unchanged")
	await frames(5)
	check(pose.mode=="hex" and pose.palm_ring.visible, "X points casting hand with purple rune")
	await snapshot("hex")
	kit.interrupt()
	await frames(28)
	player.stamina_component.current_stamina=100
	action("skill_3",true)
	await frames(12)
	check(pose.mode=="ice" and pose.ground_ring.visible and pose._staff_pitch < -0.2, "C lowers staff and shows ice aura")
	await snapshot("ice")
	action("skill_3",false)
	await frames(30)
	kit.reset()
	player.position=Vector3(0,0.1,3)
	await frames(5)
	player.stamina_component.current_stamina=100
	check(kit.storm.begin(), "Ultimate aim starts unchanged")
	await frames(25)
	check(kit.storm.confirm(Vector3(0,0,-5)), "Ultimate confirms unchanged")
	await frames(25)
	var raised_hand: Vector3=player._skeleton.get_bone_global_pose(player._skeleton.find_bone("hand.L")).origin
	check(pose.mode=="storm" and kit._staff.position.y>1.6 and raised_hand.y>1.6 and pose.ground_ring.visible, "V raises actual hands and staff with channel aura")
	await snapshot("storm")
	kit.storm.stop()
	await frames(25)
	check(pose.mode=="idle" and not pose.ground_ring.visible and not pose.staff_glow.visible, "Channel visuals clear after stop")
	kit.recovery_remaining=0
	kit.start_charge()
	await frames(12)
	player.take_damage(1,enemy.global_position)
	await frames(3)
	check(not kit.charging and pose.release_remaining==0 and not pose.palm_ring.visible and not pose.staff_glow.visible, "Hit cancels casting presentation")
	check(player.polymorph.begin(), "Polymorph interrupts presentation")
	await frames(3)
	check(not kit._staff.visible and not pose.palm_ring.visible and not pose.ground_ring.visible, "Chicken hides staff and all casting visuals")
	player.polymorph.clear()
	await frames(3)
	check(kit._staff.visible, "Wizard staff restores after chicken")
	player.health_component.take_damage(999)
	await frames(3)
	check(not kit._staff.visible and not pose.staff_glow.visible, "Death clears procedural casting without blocking death animation")
	arena.queue_free()
	await frames(3)
	CombatTimeManager.reset_time()
	print("RESULTS: %d/%d PASSED" % [passed,total])
	quit(0 if passed==total else 1)
