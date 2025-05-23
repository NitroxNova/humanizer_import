@tool
extends Resource
class_name Skeleton_Reader

var file_path : String 
var contents : Dictionary
var skeleton : Skeleton3D 
var vertex_groups : Dictionary = OSPath.read_json("res://addons/humanizer/data/resources/basemesh_vertex_groups.json")

func _init(_file_path:String):
	file_path = _file_path
	contents = OSPath.read_json(file_path)
	if "bones" in contents:
		contents = contents.bones
	
	skeleton = Skeleton3D.new()
	skeleton.name = "General_Skeleton"
	for bone_name in contents:
		var bone_id = recursive_add_bone(bone_name)

func recursive_add_bone(bone_name):
	var bone_data = contents[bone_name]
	var safe_name = safe_bone_name(bone_name)
	var parent_id = -1
	if "parent" in bone_data and bone_data.parent != "":
		parent_id = skeleton.find_bone(safe_bone_name(bone_data.parent))
		if parent_id == -1:
			recursive_add_bone(bone_data.parent)
		parent_id = skeleton.find_bone(safe_bone_name(bone_data.parent))
	var bone_id = skeleton.find_bone(safe_name)
	if bone_id == -1:
		bone_id = skeleton.add_bone(safe_name)
		if parent_id != -1:
			skeleton.set_bone_parent(bone_id,parent_id)	
		var default_position = contents[bone_name].head.default_position
		var x_form = Transform3D.IDENTITY
		x_form.origin = Vector3.ZERO
		x_form.origin.x = default_position[0]
		x_form.origin.y = default_position[2]
		x_form.origin.z = -default_position[1]
		skeleton.set_bone_global_pose(bone_id,x_form)
	return bone_id
		
func safe_bone_name(bone_name:String):
	var safe_name = bone_name
	safe_name = safe_name.replace(":","_")
	return safe_name	
