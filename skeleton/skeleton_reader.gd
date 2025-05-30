@tool
extends Resource
class_name Skeleton_Reader

var file_path : String 
var contents : Dictionary
var skeleton : Skeleton3D
var retarget_names : Dictionary
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
	retarget_bone_names()
	
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
	safe_name = safe_name.replace(".","_")
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
	
	var skeleton_weights = HumanizerResourceService.load_resource(file_path.replace("rig.","weights.")).weights
	for bone_name in skeleton_weights:
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
	
func retarget_bone_names():
	retarget_names.clear()
	#first bone will either be Root or Hips
	var bone_id = 0
	var bone_name = skeleton.get_bone_name(bone_id)
	if bone_name.to_lower().contains("root"):
		#bone is named root.. but might be hips (like the default rig)
		#get child bones, see if any are "hips"
		for child_id in skeleton.get_bone_children(bone_id):
			var child_name = skeleton.get_bone_name(child_id)
			var is_match = check_bone_pattern(child_name,["hips","pelvis"],"center")
			if is_match:
				retarget_names["Hips"] = child_id
		if "Hips" in retarget_names:
			retarget_names["Root"] = bone_id
		else:
			#default rig has left and right pelvis, but no single hips bone, but the root bone starts at the back of the hips
			retarget_names["Hips"] = bone_id	
	else:
		var is_match = check_bone_pattern(bone_name,["hips","pelvis"],"center")
		if is_match:
			retarget_names["Hips"] = bone_id
	if "Hips" not in retarget_names:
		printerr("Could not find Hips - returning")
		return
	#check for "LowerBack" - cmu_mb rig
	var spine_id = get_child_bone_with_pattern(retarget_names["Hips"],["lowerback"],"center")
	if spine_id > -1:
		retarget_names["Spine"] = spine_id
	var spine_stack
	if "Spine" in retarget_names:
		spine_stack = get_bone_stack(retarget_names["Spine"],["spine"],"center")
	else:
		spine_stack = get_bone_stack(retarget_names["Hips"],["spine"],"center")
	#TODO search for "chest" as well
	retarget_names["UpperChest"] = spine_stack.pop_back()
	retarget_names["Chest"] = spine_stack.pop_back()
	if "Spine" not in retarget_names:
		#take second spine from "default rig" (out of 5 -2 for chest)?
		if spine_stack.size()>2:
			retarget_names["Spine"] = spine_stack[1]
		else:
			retarget_names["Spine"] = spine_stack[0]
	#neck
	retarget_names["Neck"] = get_child_bone_with_pattern(retarget_names["UpperChest"],["neck"],"center")		
	#default skeleton has 3 neck bones for some reason
	retarget_names["Head"] = get_child_bone_with_pattern_recursive(retarget_names["Neck"],["head"],"center",3)
	var jaw_bone = get_child_bone_with_pattern_recursive(retarget_names["Head"],["jaw"],"center",2)
	if jaw_bone != null:
		retarget_names["Jaw"] = jaw_bone
	for side in ["Left","Right"]:
		var eye_bone = get_child_bone_with_pattern_recursive(retarget_names["Head"],["eye"],side.to_lower(),3)
		if eye_bone != null:
			retarget_names[side+"Eye"] = eye_bone
		#legs
		retarget_names[side+"UpperLeg"] = get_child_bone_with_pattern_recursive(retarget_names["Hips"],["leg","thigh"],side.to_lower(),2) 
		retarget_names[side+"LowerLeg"] = get_child_bone_with_pattern_recursive(retarget_names[side+"UpperLeg"],["lowerleg","calf"],side.to_lower(),2) 
		if retarget_names[side+"LowerLeg"] == null:
			#mixamo and cmu_mb
			retarget_names[side+"LowerLeg"] = get_child_bone_with_pattern_recursive(retarget_names[side+"UpperLeg"],["leg"],side.to_lower(),2) 
		retarget_names[side+"Foot"] = get_child_bone_with_pattern_recursive(retarget_names[side+"LowerLeg"],["foot"],side.to_lower(),2) 
		#might need better handling for default with toes. probably shouldnt have toe bones in game anyway...
		retarget_names[side+"Toes"] = get_child_bone_with_pattern_recursive(retarget_names[side+"Foot"],["toe","ball"],side.to_lower(),1) 
		#arms
		retarget_names[side+"Shoulder"] = get_child_bone_with_pattern(retarget_names["UpperChest"],["shoulder","clavicle"],side.to_lower())
		#default rig has clavicle and shoulder, using clavicle as shoulder since its closer to mixamo, but may change
		retarget_names[side+"UpperArm"] = get_child_bone_with_pattern_recursive(retarget_names[side+"Shoulder"],["arm"],side.to_lower(),2) 
		retarget_names[side+"LowerArm"] = get_child_bone_with_pattern_recursive(retarget_names[side+"UpperArm"],["forearm","lowerarm"],side.to_lower(),2) 
		retarget_names[side+"Hand"] = get_child_bone_with_pattern_recursive(retarget_names[side+"LowerArm"],["hand"],side.to_lower(),2) 
		if retarget_names[side+"Hand"] == null:
			retarget_names[side+"Hand"] = get_child_bone_with_pattern_recursive(retarget_names[side+"LowerArm"],["wrist"],side.to_lower(),2) 
		#fingers
		retarget_names[side+"ThumbMetacarpal"] = get_child_bone_with_pattern(retarget_names[side+"Hand"],["thumb","finger1"],side.to_lower())
		#cmu_mb only has 1 thumb bone, and 1 other finger with 2 bones
		var thumb_proximal = get_child_bone_with_pattern(retarget_names[side+"ThumbMetacarpal"],["thumb","finger1"],side.to_lower())
		if thumb_proximal not in [null,-1]:
			retarget_names[side+"ThumbProximal"] = thumb_proximal
			retarget_names[side+"ThumbDistal"] = get_child_bone_with_pattern(retarget_names[side+"ThumbProximal"],["thumb","finger1"],side.to_lower())
		var finger_count = skeleton.get_bone_children(retarget_names[side+"Hand"]).size()
		if finger_count == 2: #cmu_mb
			retarget_names[side+"MiddleProximal"] = get_child_bone_with_pattern(retarget_names[side+"Hand"],["finger"],side.to_lower())
			retarget_names[side+"MiddleIntermediate"] = get_child_bone_with_pattern(retarget_names[side+"MiddleProximal"],["finger"],side.to_lower())
		elif finger_count == 5: #default, game_engine, mixamo
			#skip the metacarpal (default)
			parse_finger("Index",side,["index","finger2"])
			parse_finger("Middle",side,["middle","finger3"])
			parse_finger("Ring",side,["ring","finger4"])
			parse_finger("Little",side,["pinky","finger5"])
			
		else:
			printerr("Unexpected Number of Fingers - " + str(finger_count))	
		
	print(retarget_names)

func parse_finger(finger_name:String,side:String,pattern:Array):
	retarget_names[side+finger_name+"Proximal"] = get_child_bone_with_pattern_recursive(retarget_names[side+"Hand"],pattern,side.to_lower(),2)
	retarget_names[side+finger_name+"Intermediate"] = get_child_bone_with_pattern(retarget_names[side+finger_name+"Proximal"],pattern,side.to_lower())
	retarget_names[side+finger_name+"Distal"] = get_child_bone_with_pattern(retarget_names[side+finger_name+"Intermediate"],pattern,side.to_lower())
			
	
func get_child_bone_with_pattern(bone_id:int,contains:Array,side:String):
	for child_id in skeleton.get_bone_children(bone_id):
		var child_name = skeleton.get_bone_name(child_id)
		var is_match = check_bone_pattern(child_name,contains,side)
		if is_match:
			return child_id
	return -1

func get_child_bone_with_pattern_recursive(bone_id:int,contains:Array,side:String,iterations:int):
	#to do breadth first, dont want to go all the way down and back up the tree
	var check_list = [bone_id]
	var next_check_list = []
	while iterations > 0:
		for check_id in check_list:
			var match_id = get_child_bone_with_pattern(check_id,contains,side)
			if match_id > -1:
				return match_id
			for child_id in skeleton.get_bone_children(check_id):
				next_check_list.append(child_id)
		check_list = next_check_list
		next_check_list = []		
		iterations -= 1
		
func check_bone_pattern(bone_name:String,contains:Array,side:String):
	for check_string in contains:
		if bone_name.to_lower().contains(check_string):
			if get_bone_side(bone_name) == side:
				return true
	return false

func get_bone_side(bone_name:String):
	if bone_name.ends_with("_L"):
		return "left" #default
	if bone_name.ends_with("_R"):
		return "right" #default
	if bone_name.ends_with("_l"):
		return "left" #game_engine
	if bone_name.ends_with("_r"):
		return "right" #game_engine
	if bone_name.begins_with("LT") or bone_name.begins_with("LH"):
		return "left" #cmu_mb
	if bone_name.begins_with("RT") or bone_name.begins_with("RH"):
		return "right" #cmu_mb	
	if bone_name.contains("Left"):
		return "left" #mixamo
	if bone_name.contains("Right"):
		return "right" #mixamo
	return "center"
	
func get_bone_stack(bone_id:int,contains:Array,side:String,list:Array=[]):
	for child_id in skeleton.get_bone_children(bone_id):
		var child_name = skeleton.get_bone_name(child_id)
		if check_bone_pattern(child_name,contains,side):
			list.append(child_id)
			get_bone_stack(child_id,contains,side,list)
	return list
