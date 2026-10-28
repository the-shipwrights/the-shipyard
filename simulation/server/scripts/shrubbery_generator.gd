@tool
extends MultiMeshInstance3D

@export_tool_button("scale outside of threshold") var rescale_actio = rescale
@export_tool_button("Make All Instances Upright") var upright_action = make_upright

@export var y_min_threshold: float = -0.5
@export var y_max_threshold: float = 4.0

func rescale() -> void:
	if not _validate_multimesh(): return
		
	for i in range(self.multimesh.instance_count):
		var mesh_transform := self.multimesh.get_instance_transform(i)
		
		if mesh_transform.origin.y < y_min_threshold:
			mesh_transform.basis = Basis().scaled(Vector3.ZERO)
			self.multimesh.set_instance_transform(i, mesh_transform)
		
		if mesh_transform.origin.y > y_max_threshold:
			mesh_transform.basis = Basis().scaled(Vector3.ZERO)
			self.multimesh.set_instance_transform(i, mesh_transform)
			
	print("Rescale complete!")

func make_upright() -> void:
	if not _validate_multimesh(): return
		
	for i in range(self.multimesh.instance_count):
		var mesh_transform := self.multimesh.get_instance_transform(i)
		
		# Skip fully hidden/scaled-to-zero meshes so we don't distort them
		var current_scale = mesh_transform.basis.get_scale()
		if current_scale.is_zero_approx():
			continue
			
		# Extract current facing direction projected onto the horizontal (XZ) plane
		var forward = -mesh_transform.basis.z
		forward.y = 0.0
		if forward.is_zero_approx():
			forward = Vector3.FORWARD
		else:
			forward = forward.normalized()
			
		# Rebuild an upright basis (Y points straight up, maintaining original facing direction)
		var new_basis = Basis()
		new_basis.y = Vector3.UP
		new_basis.x = Vector3.UP.cross(forward).normalized()
		new_basis.z = new_basis.x.cross(Vector3.UP).normalized()
		
		# Restore original scale and position
		mesh_transform.basis = new_basis.scaled(current_scale)
		
		self.multimesh.set_instance_transform(i, mesh_transform)
		
	print("All instances aligned upright!")

func _validate_multimesh() -> bool:
	if not self.multimesh:
		print("Multimesh resource is missing!")
		return false
	if self.multimesh.instance_count < 1:
		print("Multimesh is empty!")
		return false
	return true
