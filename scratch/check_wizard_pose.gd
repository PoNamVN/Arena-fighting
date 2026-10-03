extends "res://run_wizard_foundation_test.gd"
func _run() -> void:
 arena=load("res://scenes/EmptyArena.tscn").instantiate()
 root.add_child(arena)
 await fresh()
 var kit=player.wizard_combat
 for name in ["upper_arm.R","forearm.R","hand.R"]:
  print(name, " rest=",player._skeleton.get_bone_global_rest(player._skeleton.find_bone(name)))
 print("skeleton=",player._skeleton.global_transform)
 print("IDLE grip=",kit._staff.position)
 player.stamina_component.current_stamina=100
 kit.storm.begin()
 await frames(25)
 kit.storm.confirm(Vector3(0,0,-5))
 await frames(25)
 print("V grip=",kit._staff.position, " rhand=",kit.presentation._right_hand)
 arena.queue_free()
 await frames(3)
 quit()
