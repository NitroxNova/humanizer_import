@tool
extends Resource
class_name Skeleton_Reader

var file_path : String 
var contents : Dictionary
var skeleton : Skeleton3D
var vertex_groups : Dictionary = OSPath.read_json("res://addons/humanizer/data/resources/basemesh_vertex_groups.json")
var rig : HumanizerRig

func _init(_file_path:String):
	file_path = _file_path
	contents = OSPath.read_json(file_path)
	if "bones" in contents:
		contents = contents.bones
	
	rig = HumanizerRig.new()
	skeleton = Skeleton3D.new()
	skeleton.name = "General_Skeleton"
	for bone_name in contents:
		var bone_id = recursive_add_bone(bone_name)
	load_bone_config()
	load_bone_weights()
	var skeleton_data = HumanizerRigService.init_skeleton_data(skeleton)
	var helpers = HumanizerTargetService.init_helper_vertex()
	HumanizerRigService.adjust_bone_positions(skeleton_data,rig,helpers,{},{})
	HumanizerRigService.adjust_skeleton_3D(skeleton,skeleton_data)
	
	var rig_save_path = file_path.replace("res://data/input/skeleton","res://humanizer/skeleton")
	rig_save_path = rig_save_path.replace(".json",".res")
	if not DirAccess.dir_exists_absolute(rig_save_path.get_base_dir()):
		DirAccess.make_dir_absolute(rig_save_path.get_base_dir())
	var packed_skeleton = PackedScene.new()
	#skeleton.owner = skeleton
	packed_skeleton.pack(skeleton)
	rig.skeleton = packed_skeleton
	ResourceSaver.save(rig,rig_save_path)

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
		
	return bone_id
		
func safe_bone_name(bone_name:String):
	var safe_name = bone_name
	safe_name = safe_name.replace(":","_")
	return safe_name	

func load_bone_config():
	# Create skeleton config		
	rig.config.resize(skeleton.get_bone_count())
	for in_name in contents:
		var out_name = safe_bone_name(in_name)
		var bone_id = skeleton.find_bone(out_name)
		if bone_id > -1:
			var parent_name = safe_bone_name( contents[in_name].parent)
			var parent_id = skeleton.find_bone(parent_name)
			rig.config[bone_id] = contents[in_name]
			rig.config[bone_id].parent = parent_id
			if rig.config[bone_id].head.strategy == "CUBE":
				var cube_range = vertex_groups[rig.config[bone_id].head.cube_name][0]
				var cube_index = []
				for i in range(cube_range[0], cube_range[1] + 1):
					cube_index.append(i)
				rig.config[bone_id].head.vertex_indices = cube_index
			
			#rig.config_json_path = dir.path_join('skeleton_config.json')
			#HumanizerResourceService.save_resource(rig.config_json_path, rig_config)

func load_bone_weights():
	# Get bone weights for clothes
	var out_data := []
	out_data.resize(HumanizerTargetService.basis.size())
	for i in out_data.size():
		out_data[i] = []
	
	#var skeleton_weights:Dictionary = HumanizerResourceService.load_resource(dir.path_join("weights."+name+".json")).weights
	var skeleton_weights = HumanizerResourceService.load_resource(file_path.replace("rig.","weights.")).weights
	#for in_name:String in skeleton_weights.keys():
		#var out_name = in_name.replace(":","_")
		#if not in_name == out_name:
			#skeleton_weights[out_name] = skeleton_weights[in_name]
			#skeleton_weights.erase(in_name)
	for bone_name in skeleton_weights:
		#bone_names.append(bone_name)
		var bone_id = skeleton.find_bone(safe_bone_name(bone_name))
		for id_weight_pair in skeleton_weights[bone_name]:
			out_data[id_weight_pair[0]].append([bone_id,id_weight_pair[1]])
	
	#normalize
	for bw_array in out_data:
		var weight_sum = 0
		for bw_pair in bw_array:
			weight_sum += bw_pair[1]
		for bw_pair in bw_array:
			bw_pair[1] /= weight_sum
	
	rig.weights = out_data
	
	#rig.bone_weights_json_path = dir.path_join('bone_weights.json')
	#HumanizerResourceService.save_resource(rig.bone_weights_json_path, {names=bone_names,weights=out_data})

func retarget_bone_names():
	pass
