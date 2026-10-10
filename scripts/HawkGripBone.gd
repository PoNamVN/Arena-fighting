extends PhysicalBone3D

var hawk_pinned := false
var hawk_pin := Transform3D.IDENTITY

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if not hawk_pinned: return
	state.transform = hawk_pin
	state.linear_velocity = Vector3.ZERO
	state.angular_velocity = Vector3.ZERO
	global_transform = hawk_pin
