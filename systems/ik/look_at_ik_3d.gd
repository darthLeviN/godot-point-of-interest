@tool
extends SkeletonModifier3D
class_name LookAtIK3D

@export var tail_bone: StringName:
	set(value):
		if tail_bone != value:
			tail_bone = value
			if is_node_ready():
				var skele := get_skeleton()
				if skele:
					tail_bone_idx = skele.find_bone(tail_bone)
				update_cache()

@export var root_bone: StringName:
	set(value):
		if root_bone != value:
			root_bone = value
			if is_node_ready():
				var skele := get_skeleton()
				if skele:
					root_bone_idx = skele.find_bone(root_bone)
					update_cache()


@export var ik_weights: PackedVector3Array:
	set(value):
		ik_weights = value
		notify_property_list_changed()


@export var offset := Vector3()
@export var front := Vector3.FORWARD


var tail_bone_idx: int = -1
var root_bone_idx: int = -1
var bone_indices: PackedInt32Array = []


func _ready() -> void:
	var skele := get_skeleton()
	if skele:
		tail_bone_idx = skele.find_bone(tail_bone)
		root_bone_idx = skele.find_bone(root_bone)
		update_cache()


func _enter_tree() -> void:
	var skele := get_skeleton()
	if skele:
		tail_bone_idx = skele.find_bone(tail_bone)
		root_bone_idx = skele.find_bone(root_bone)
		update_cache()


func _process_modification() -> void:
	if bone_indices.size() < 0:
		return
	
	var skeleton := get_skeleton()
	if not skeleton:
		return
	
	var weight_factor := Vector3()
	
	for weight in ik_weights:
		weight_factor += weight
	
	weight_factor = Vector3(1.0, 1.0, 1.0)/(weight_factor + Vector3(0.001,0.001, 0.001))
	
	var convergence_requirement := Vector3()
	var accum_quat := Quaternion.IDENTITY
	for idx in bone_indices.size():
		var bone_idx := bone_indices[idx]
		var bone_weight := ik_weights[idx]*weight_factor
		convergence_requirement += bone_weight
		var bone_transform := skeleton.get_bone_global_pose(bone_idx)
		var direction = (transform.origin + offset - bone_transform.origin).normalized()
		var rotationq = Quaternion(accum_quat*front, direction)
		
		var eulerq = rotationq.get_euler()*convergence_requirement
		rotationq = Quaternion.from_euler(eulerq)
		var prev_trans = skeleton.get_bone_pose(bone_idx)
		
		accum_quat = (accum_quat*rotationq).normalized()
		
		skeleton.set_bone_pose_rotation(bone_idx, rotationq)


func update_cache() -> void:
	bone_indices.clear()
	
	if not is_node_ready():
		return
	
	var skele := get_skeleton()
	if not skele:
		return
	if root_bone_idx < 0 or tail_bone_idx < 0:
		return
	
	
	bone_indices.append(tail_bone_idx)
	var next_idx := skele.get_bone_parent(tail_bone_idx)
	var failed := false
	while next_idx != root_bone_idx:
		bone_indices.append(next_idx)
		next_idx = skele.get_bone_parent(next_idx)
		if next_idx < 0:
			failed = true
			break
	
	if not failed:
		bone_indices.reverse()
	
	else:
		bone_indices.clear()
		bone_indices.append(tail_bone_idx)
	
	var chain_count := bone_indices.size()
	var diff = chain_count - ik_weights.size()
	if diff < 0:
		ik_weights.resize(chain_count)
	elif diff > 0:
		for c in diff:
			ik_weights.append(Vector3(1.0,1.0,1.0))
	


func _validate_property(property: Dictionary) -> void:
	if property.name == &"tail_bone" or property.name == &"root_bone":
		var skele = get_skeleton()
		if skele:
			property.hint = PROPERTY_HINT_ENUM
			property.hint_string = skele.get_concatenated_bone_names()
		else:
			property.hint = PROPERTY_HINT_NONE
			property.hint_string = ""
	elif property.name == &"ik_weights":
		var chain_count := bone_indices.size()
		var diff = chain_count - ik_weights.size()
		if diff < 0:
			ik_weights.resize(chain_count)
		elif diff > 0:
			for c in diff:
				ik_weights.append(Vector3(1.0,1.0,1.0))
