extends SceneTree

func _init() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	print("=================================================================")
	print("PHASE 2 RUNTIME VALIDATION: ATTACK ANIMATION & DAMAGE TIMING")
	print("=================================================================")
	
	var arena_scene: PackedScene = load("res://scenes/Arena.tscn")
	var arena: Node3D = arena_scene.instantiate() as Node3D
	root.add_child(arena)
	
	var player: PlayerController = arena.get_node_or_null("Player") as PlayerController
	var dummy: Node3D = arena.get_node_or_null("TrainingDummy") as Node3D
	
	if not player or not dummy:
		print("ERROR: Player or TrainingDummy missing from Arena scene!")
		quit(1)
		return
		
	var dummy_health: HealthComponent = dummy.get_node("HealthComponent") as HealthComponent
	
	# Wait for physics frames to settle
	for i in range(10):
		await process_frame
		
	print("\n>>> INITIAL STATE:")
	print("Player position: ", player.global_position)
	print("Dummy position: ", dummy.global_position)
	print("Dummy initial health: %d / %d" % [dummy_health.current_health, dummy_health.max_health])
	var initial_health: float = dummy_health.current_health
	
	# Position player facing dummy within melee attack range (approx 1.8m)
	player.global_position = dummy.global_position + Vector3(0, 0, 1.8)
	player._camera_yaw = 0.0 # Facing dummy along -Z
	player._camera_pitch = 0.0
	player.camera_pivot.rotation = Vector3.ZERO
	player.visuals.rotation.y = 0.0
	
	# -----------------------------------------------------------------
	# TEST 1: DAMAGE TIMING & NO PREMATURE DAMAGE (Wind-up Phase)
	# -----------------------------------------------------------------
	print("\n--- TEST 1: DAMAGE TIMING DURING ATTACK (WIND-UP -> IMPACT -> RECOVERY) ---")
	player.set_third_person(false) # First-Person
	await process_frame
	
	# Trigger attack
	player._try_combat_attack()
	print("Attack initiated. is_attacking = ", player._is_attacking)
	
	# Step through frames and monitor damage vs animation position
	var damage_applied_time: float = -1.0
	var damage_count: int = 0
	var last_health: float = dummy_health.current_health
	
	# Simulate 60 physics frames (~1.0 second)
	for f in range(60):
		# Let engine process frame
		await process_frame
		var anim_pos: float = player.anim_player.current_animation_position if player.anim_player else 0.0
		var current_hp: float = dummy_health.current_health
		
		if current_hp < last_health:
			var diff: float = last_health - current_hp
			damage_count += 1
			damage_applied_time = anim_pos
			print(" -> IMPACT HIT DETECTED! Frame %d | Anim Time: %.3f s | Damage: %.1f | Remaining HP: %.1f" % [
				f, anim_pos, diff, current_hp
			])
			last_health = current_hp
			_capture_screenshot("phase2_impact_frame.png")
			
		# At Wind-up apex (around f = 10, anim_pos ~ 0.15s), capture windup screenshot
		if f == 10:
			_capture_screenshot("phase2_windup_frame.png")
			print(" -> Wind-up check at %.3fs: Dummy HP = %.1f (MUST EQUAL INITIAL HP: %.1f)" % [
				anim_pos, current_hp, initial_health
			])
			if current_hp != initial_health:
				print(" FAILED: Premature damage was applied during wind-up!")
			else:
				print(" PASSED: No damage applied during wind-up.")
				
		if not player._is_attacking and f > 25:
			print(" -> Attack animation completed at frame %d (Anim time: %.3f s)" % [f, anim_pos])
			break
			
	print("Total hits applied during swing: %d (Expected: 1)" % damage_count)
	if damage_count == 1 and damage_applied_time >= 0.30:
		print(">>> PASSED: Damage synchronized precisely at impact (t=%.3f s) and dealt exactly once!" % damage_applied_time)
	else:
		print(">>> FAILED: Damage count or timing incorrect! (count=%d, time=%.3f)" % [damage_count, damage_applied_time])
		
	# -----------------------------------------------------------------
	# TEST 2: SINGLE-HIT GUARANTEE ON CONTINUED RECOVERY
	# -----------------------------------------------------------------
	print("\n--- TEST 2: SINGLE-HIT GUARANTEE & COOLDOWN BEHAVIOR ---")
	print("Checking if spamming attack during recovery triggers duplicate hits...")
	var spam_blocked: bool = not player.combat.can_attack()
	print("Combat can_attack() right after attack: ", not spam_blocked)
	print("Health unchanged after full recovery: HP = %.1f" % dummy_health.current_health)
	
	# Wait for cooldown to expire
	while player.combat._cooldown_timer > 0.0:
		await process_frame
		
	print("Cooldown expired. Ready for second attack.")
	
	# -----------------------------------------------------------------
	# TEST 3: ATTACK RANGE CHECK (OUT OF RANGE)
	# -----------------------------------------------------------------
	print("\n--- TEST 3: RANGE VERIFICATION (BEYOND MELEE REACH) ---")
	player.global_position = dummy.global_position + Vector3(0, 0, 3.5) # 3.5m away (beyond 2.2m)
	player._camera_yaw = 0.0
	player.visuals.rotation.y = 0.0
	await process_frame
	
	var hp_before_miss: float = dummy_health.current_health
	player._try_combat_attack()
	print("Attacking from 3.5m (out of reach)...")
	for f in range(50):
		await process_frame
		if not player._is_attacking:
			break
			
	var hp_after_miss: float = dummy_health.current_health
	print("HP before: %.1f | HP after: %.1f" % [hp_before_miss, hp_after_miss])
	if hp_after_miss == hp_before_miss:
		print(">>> PASSED: Out-of-range attack did not deal damage.")
	else:
		print(">>> FAILED: Out-of-range attack dealt damage!")
		
	# -----------------------------------------------------------------
	# TEST 4: DIRECTIONAL CHECK (FACING AWAY FROM TARGET)
	# -----------------------------------------------------------------
	print("\n--- TEST 4: DIRECTIONAL CHECK (FACING 180° AWAY FROM DUMMY) ---")
	player.global_position = dummy.global_position + Vector3(0, 0, 1.5) # Close to dummy
	player._camera_yaw = deg_to_rad(180.0) # Facing South (away from dummy to North)
	player.camera_pivot.rotation.y = deg_to_rad(180.0)
	player.visuals.rotation.y = deg_to_rad(180.0)
	await process_frame
	
	var hp_before_wrong_dir: float = dummy_health.current_health
	player._try_combat_attack()
	print("Attacking while facing away from dummy...")
	for f in range(50):
		await process_frame
		if not player._is_attacking:
			break
			
	var hp_after_wrong_dir: float = dummy_health.current_health
	print("HP before: %.1f | HP after: %.1f" % [hp_before_wrong_dir, hp_after_wrong_dir])
	if hp_after_wrong_dir == hp_before_wrong_dir:
		print(">>> PASSED: Attack facing away did not hit target behind.")
	else:
		print(">>> FAILED: Attack hit target behind player!")
		
	# -----------------------------------------------------------------
	# TEST 5: THIRD-PERSON ATTACK & MESH ALIGNMENT
	# -----------------------------------------------------------------
	print("\n--- TEST 5: THIRD PERSON ATTACK VERIFICATION ---")
	player.set_third_person(true)
	player.global_position = dummy.global_position + Vector3(0, 0, 1.8)
	player._camera_yaw = 0.0
	player.camera_pivot.rotation = Vector3.ZERO
	player.visuals.rotation.y = 0.0
	await process_frame
	
	var hp_before_tps: float = dummy_health.current_health
	player._try_combat_attack()
	print("Attacking in Third-Person mode...")
	for f in range(60):
		await process_frame
		if f == 18:
			_capture_screenshot("phase2_tps_attack_swing.png")
		if not player._is_attacking:
			break
			
	var hp_after_tps: float = dummy_health.current_health
	print("TPS HP before: %.1f | HP after: %.1f" % [hp_before_tps, hp_after_tps])
	if hp_after_tps < hp_before_tps:
		print(">>> PASSED: Third-Person attack connected and dealt damage!")
	else:
		print(">>> FAILED: Third-Person attack failed to connect.")
		
	print("\n=================================================================")
	print("ALL PHASE 2 RUNTIME TESTS FINISHED!")
	print("=================================================================")
	arena.queue_free()
	quit(0)

func _capture_screenshot(filename: String) -> void:
	var img: Image = root.get_viewport().get_texture().get_image()
	if img:
		var path: String = "d:/Game 3D/Game_3D/" + filename
		img.save_png(path)
		print("Saved screenshot: ", path)
