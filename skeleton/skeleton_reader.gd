@tool
extends Resource
class_name Skeleton_Reader

var input_folder : String 
var skeleton : Skeleton3D
var retarget_names : Dictionary
var vertex_groups : Dictionary = OSPath.read_json("res://addons/humanizer/data/resources/basemesh_vertex_groups.json")
var rig : HumanizerRig

func _init(_folder:String):
	input_folder = _folder
	var skeleton_name = input_folder.get_file()
	var config_file_path = ""
	var weights_file_path = ""
	
	var input_files = DirAccess.get_files_at(input_folder)
	for file_name in input_files:
		if file_name.begins_with("rig.") or file_name.ends_with(".mhskel"):
			config_file_path = input_folder.path_join(file_name)
		elif file_name.begins_with("weights.") or file_name.ends_with(".mhw"):
			weights_file_path = input_folder.path_join(file_name)
	if config_file_path == "":
		printerr("couldnt find rig config in " + input_folder)
		return
	if weights_file_path == "":
		printerr("couldnt find weights config in " + input_folder)
		return
	print(weights_file_path)
	var contents = OSPath.read_json(config_file_path)
	#if "bones" in contents:
		#contents = contents.bones
	if "bones" not in contents:
		contents = {bones=contents}
	
	rig = HumanizerRig.new()
	skeleton = Skeleton3D.new()
	skeleton.name = "General_Skeleton"
	for bone_name in contents.bones:
		var bone_id = recursive_add_bone(bone_name,contents)
	load_bone_config(contents)
	load_bone_weights(weights_file_path,contents)
	var helpers = HumanizerTargetService.init_helper_vertex()
	#have to set bone rotations before initing the data, then can set positions
	set_bone_rotations(helpers,skeleton)
	var skeleton_data = HumanizerRigService.init_skeleton_data(skeleton)
	HumanizerRigService.adjust_bone_positions(skeleton_data,rig,helpers,{},{})
	HumanizerRigService.adjust_skeleton_3D(skeleton,skeleton_data)
	retarget_bone_names()
	
	var rig_save_path = "res://humanizer/skeleton".path_join(skeleton_name) + ".res"
	if not DirAccess.dir_exists_absolute(rig_save_path.get_base_dir()):
		DirAccess.make_dir_absolute(rig_save_path.get_base_dir())
	
	var packed_skeleton = PackedScene.new()
	#skeleton.owner = skeleton
	packed_skeleton.pack(skeleton)
	rig.skeleton = packed_skeleton
	ResourceSaver.save(rig,rig_save_path)

func set_bone_rotations(helper_vertex:Array,skeleton:Skeleton3D):
	var matrix_world = []
	for bone_id in rig.config.size():
		var bone_name = skeleton.get_bone_name(bone_id)
		#print(bone_name)
		var head_position = HumanizerRigService.get_bone_position_from_config(rig,bone_id,"head",helper_vertex)
		var tail_position = HumanizerRigService.get_bone_position_from_config(rig,bone_id,"tail",helper_vertex)
		var roll = 0
		if "roll" in rig.config[bone_id]:
			roll = rig.config[bone_id].roll
		var bone_rotation = get_bone_quat_from_position_roll(head_position,tail_position,roll)
		var bone_matrix = Basis(Vector3(bone_rotation[0][0],bone_rotation[0][1],bone_rotation[0][2]),Vector3(bone_rotation[1][0],bone_rotation[1][1],bone_rotation[1][2]),Vector3(bone_rotation[2][0],bone_rotation[2][1],bone_rotation[2][2]))
		#print("matrix world")
		#print(bone_matrix)
		matrix_world.append(bone_matrix)
		var parent_id = skeleton.get_bone_parent(bone_id)
		var local_rotation :Basis = bone_matrix
		if parent_id > -1:
			var parent_inverse = matrix_world[parent_id].inverse()
			#print("parent inverse")
			#print(parent_inverse)
			local_rotation = parent_inverse * bone_matrix
		#print("local rotation")
		#print(local_rotation)
		#print("quaternion")
		var quat = local_rotation.get_rotation_quaternion()
		quat = Quaternion(quat.x,quat.z,-quat.y,quat.w)
		#print(quat)
		#var local_rotation = bone_rotation * global_rotation[skeleton.get_bone_parent(bone_id)].inverse()
		#print(local_rotation)
		skeleton.set_bone_rest(bone_id,Transform3D(Basis(quat),Vector3.ZERO))
		#print()
		
func recursive_add_bone(bone_name:String,contents:Dictionary):
	var bone_data = contents.bones[bone_name]
	var safe_name = safe_bone_name(bone_name)
	var parent_id = -1
	if "parent" in bone_data and bone_data.parent != "" and bone_data.parent != null:
		#print(bone_data.parent)
		parent_id = skeleton.find_bone(safe_bone_name(bone_data.parent))
		if parent_id == -1:
			recursive_add_bone(bone_data.parent,contents)
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

func load_bone_config(contents:Dictionary):
	# Create skeleton config		
	rig.config.resize(skeleton.get_bone_count())
	for in_name in contents.bones:
		var out_name = safe_bone_name(in_name)
		var bone_id = skeleton.find_bone(out_name)
		if bone_id > -1:
			var parent_name = contents.bones[in_name].parent
			var parent_id = -1
			if parent_name != null and parent_name != "":
				parent_name = safe_bone_name(parent_name)
				parent_id = skeleton.find_bone(parent_name)
			rig.config[bone_id] = contents.bones[in_name]
			rig.config[bone_id].parent = parent_id
			rig.config[bone_id].head = get_vertex_indices(contents,in_name,"head")
			rig.config[bone_id].tail = get_vertex_indices(contents,in_name,"tail")
			#rig.config_json_path = dir.path_join('skeleton_config.json')
			#HumanizerResourceService.save_resource(rig.config_json_path, rig_config)

func get_vertex_indices(contents:Dictionary,bone_name:String,head:String):
	var vertex_indices = []
	var config = contents.bones[bone_name][head] #or tail..
	if config is String:
		#old format, get from joints in config
		vertex_indices = contents.joints[config]
	elif config.strategy == "CUBE":
		var cube_range = vertex_groups[config.cube_name][0]
		var cube_index = []
		for i in range(cube_range[0], cube_range[1] + 1):
			cube_index.append(i)
		vertex_indices = cube_index
	elif config.strategy == "MEAN":
		vertex_indices = config.vertex_indices
	else:
		vertex_indices.append(config.vertex_index)
	return vertex_indices

func get_weights_reference(contents:Dictionary):
	var references = {}
	for bone_name in contents.bones:
		var bone_config = contents.bones[bone_name]
		var ref_array = []
		if "weights_reference" in bone_config:
			ref_array = bone_config.weights_reference
		elif "reference" in bone_config and bone_config.reference != null:
			ref_array = bone_config.reference
		for ref_name in ref_array:
			var safe_ref_name = safe_bone_name(ref_name)
			if safe_ref_name not in references:
				references[safe_ref_name] = []
				#printerr("bone already has reference " + ref_name)
			references[safe_ref_name].append( skeleton.find_bone( safe_bone_name(bone_name)))
	return references		

func load_bone_weights(weights_file_path:String,contents:Dictionary):
	# old format
	var weights_reference = get_weights_reference(contents)
	# Get bone weights for clothes
	var out_data := []
	out_data.resize(HumanizerTargetService.basis.size())
	for i in out_data.size():
		out_data[i] = []
	
	var skeleton_weights = OSPath.read_json(weights_file_path).weights
	
	for bone_name in skeleton_weights:
		if not skeleton_weights[bone_name].is_empty():
			var ref_array = []
			var safe_bone_name = safe_bone_name(bone_name)
			if safe_bone_name in weights_reference:
				ref_array = weights_reference[safe_bone_name]
			else:	
				var bone_id = skeleton.find_bone(safe_bone_name)
				if bone_id > -1:
					ref_array.append(bone_id)
				elif not weights_reference.is_empty():
					#printerr("bone not found " + bone_name)
					#find the bone in the default skeleton get the parent from the reference?
					#idk if this is right but i dont want to step through the makehuman source code right now
					#requires defualt rig in humanizer folder
					var default_skeleton : Skeleton3D = HumanizerRegistry.rigs["default"].load_skeleton()
					ref_array = find_reference_recursive(safe_bone_name,weights_reference,default_skeleton)
				else:
					if safe_bone_name.begins_with('toe'):
						if safe_bone_name.ends_with('_L'): # default rig, example: toe4-1.R
							ref_array = [skeleton.find_bone("toe1-1_L")]
						elif safe_bone_name.ends_with('_R'):
							ref_array = [skeleton.find_bone("toe1-1_R")]
						else:
							printerr("Unhandled bone " + bone_name)	
						
			for ref_id in ref_array:	
				for id_weight_pair in skeleton_weights[bone_name]:
					#need to combine since some bones reference the same 
					var ref_id_found = false
					for existing_pair in out_data[id_weight_pair[0]]: #arrays are passed by reference
						if existing_pair[0] == ref_id:
							existing_pair[1] += id_weight_pair[1]/ref_array.size()
							ref_id_found = true
					if not ref_id_found:
						out_data[id_weight_pair[0]].append([ref_id,id_weight_pair[1]/ref_array.size()])
				
	#normalize
	for bw_array:Array in out_data:
		while bw_array.size() > 8:
			#remove lowest weight until array size is 8
			var lowest = bw_array[0]
			for bw_pair in bw_array:
				if bw_pair[1] < lowest[1]:
					lowest=bw_pair
			bw_array.erase(lowest)
		#then normalize
		var weight_sum = 0
		for bw_pair in bw_array:
			weight_sum += bw_pair[1]
		for bw_pair in bw_array:
			bw_pair[1] /= weight_sum
				
			
	rig.weights = out_data
	
	## Build cross reference dicts to easily map between a vertex group index and # a vertex group name
	#var group_index = []
	#for bone_name in bone_weights.names:
		#var new_bone_id = skeleton_data.keys().find(bone_name)
		#if new_bone_id == -1:
			#if bone_name.begins_with('toe'):
				#if bone_name.ends_with('.L'): # default rig, example: toe4-1.R
					#new_bone_id = skeleton_data.keys().find("toe1-1.L")
				#elif bone_name.ends_with('.R'):
					#new_bone_id = skeleton_data.keys().find("toe1-1.R")
				#else:
					#printerr("Unhandled bone " + bone_name)
		#group_index.append(new_bone_id)
	#for bone_name in bone_weights.names:
		#var new_id = skeleton_data.keys().find(bone_name)
		#group_index.append(new_id)

func find_reference_recursive(bone_name:String,weights_reference:Dictionary,df_skeleton:Skeleton3D):		
	var df_bone_id = df_skeleton.find_bone(bone_name)
	var df_parent_id = df_skeleton.get_bone_parent(df_bone_id)
	var df_parent_name = df_skeleton.get_bone_name(df_parent_id)
	if df_parent_name in weights_reference:
		return weights_reference[df_parent_name]
	return find_reference_recursive(df_parent_name,weights_reference,df_skeleton)
	
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
	#get spine and chest stack
	if "Spine" in retarget_names:
		spine_stack = get_bone_stack(retarget_names["Spine"],["spine","chest"],"center")
	else:
		spine_stack = get_bone_stack(retarget_names["Hips"],["spine","chest"],"center")
	
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
		retarget_names[side+"LowerLeg"] = get_child_bone_with_pattern_recursive(retarget_names[side+"UpperLeg"],["lowerleg","calf","shin"],side.to_lower(),2) 
		if retarget_names[side+"LowerLeg"] == null:
			#mixamo and cmu_mb
			retarget_names[side+"LowerLeg"] = get_child_bone_with_pattern_recursive(retarget_names[side+"UpperLeg"],["leg"],side.to_lower(),2) 
		retarget_names[side+"Foot"] = get_child_bone_with_pattern_recursive(retarget_names[side+"LowerLeg"],["foot"],side.to_lower(),2) 
		#might need better handling for default with toes. probably shouldnt have toe bones in game anyway...
		retarget_names[side+"Toes"] = get_child_bone_with_pattern_recursive(retarget_names[side+"Foot"],["toe","ball"],side.to_lower(),1) 
		#arms
		#retarget_names[side+"Shoulder"] = get_child_bone_with_pattern(retarget_names["UpperChest"],["shoulder","clavicle"],side.to_lower())
		retarget_names[side+"Shoulder"] = get_child_bone_with_pattern_recursive(retarget_names["UpperChest"],["shoulder"],side.to_lower(),2)
		#default rig has clavicle and shoulder, using clavicle as shoulder since its closer to mixamo, but may change
		if retarget_names[side+"Shoulder"] == null:
			retarget_names[side+"Shoulder"] = get_child_bone_with_pattern_recursive(retarget_names["UpperChest"],["clavicle"],side.to_lower(),2)
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
		
	#print(retarget_names)

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
	
static func get_bone_quat_from_position_roll(position1:Vector3,position2:Vector3,roll:float):
	position1 = Vector3(position1.x,-position1.z,position1.y)
	position2 = Vector3(position2.x,-position2.z,position2.y)
	#print(roll)
	#roll = deg_to_rad(roll) - roll is already in radians
	var bone_vector = position2 - position1
	var rMatrix = Skeleton_Reader.vec_roll_to_mat3(bone_vector,roll)
	#print(rMatrix)
	#var xform_matrix = Skeleton_Reader.rot_pos_to_m4(rMatrix,position1)
	rMatrix = Skeleton_Reader.swizzle_rotation_matrix_y_up(rMatrix)
	##xform_matrix = Skeleton_Reader.mul_m4db_m4db_m4fl(axis_basis_change,xform_matrix)
	#print(rMatrix)
	#var decompose = Skeleton_Reader.decompose_matrix4(xform_matrix)
	##print(decompose.rotation_m3[2][1])
	#rMatrix = decompose.rotation_m3
	#var r_basis = Basis(Vector3(rMatrix[0][0],rMatrix[0][1],rMatrix[0][2]),Vector3(rMatrix[1][0],rMatrix[1][1],rMatrix[1][2]),Vector3(rMatrix[2][0],rMatrix[2][1],rMatrix[2][2]))
	#var r_quat = r_basis.get_rotation_quaternion()
	var rotation_quaternion = Skeleton_Reader.mat3_normalized_to_quat_fast( rMatrix);
	#rotate for up
	rotation_quaternion = Quaternion(rotation_quaternion.y,rotation_quaternion.w,-rotation_quaternion.z,rotation_quaternion.x)
	return rMatrix
	#$%rotation_label.text = str(rotation_quaternion)

#func vec_roll_to_mat3_normalized(const float nor[3], const float roll, float r_mat[3][3])->void:
#https://github.com/blender/blender/blob/1fbd83f72eaeffb08c080c938c89b749ef3a94d7/source/blender/blenkernel/intern/armature.cc#L2593
static func vec_roll_to_mat3_normalized(nor:Vector3, roll:float):
	#/**
	#* P.S. In the end, this basically is a heavily optimized version of Damped Track +Y.
	#*/
	#print("normal " + str(nor))
	#print("roll " + str(roll))
	const SAFE_THRESHOLD:float = 6.1e-3;     #/* Theta above this value has good enough precision. */
	const CRITICAL_THRESHOLD:float = 2.5e-4; #/* True singularity if XZ distance is below this. */
	const THRESHOLD_SQUARED:float = CRITICAL_THRESHOLD * CRITICAL_THRESHOLD;

	var x:float = nor[0];
	var y:float = nor[1];
	var z:float = nor[2];

	var theta:float = 1.0 + y;                #/* Remapping Y from [-1,+1] to [0,2]. */
	var theta_alt:float = x * x + z * z; #/* Squared distance from origin in x,z plane. */
	var bMatrix = [[0,0,0],[0,0,0],[0,0,0]]
	var rMatrix = [[0,0,0],[0,0,0],[0,0,0]]
	#float rMatrix[3][3], bMatrix[3][3];
	
	#assert that its a valid vector?
	#BLI_ASSERT_UNIT_V3(nor);

	#/* Determine if the input is far enough from the true singularity of this type of
	#* transformation at (0,-1,0), where roll becomes 0/0 undefined without a limit.
	#*
	#* When theta is close to zero (nor is aligned close to negative Y Axis),
	#* we have to check we do have non-null X/Z components as well.
	#* Also, due to float precision errors, nor can be (0.0, -0.99999994, 0.0) which results
	#* in theta being close to zero. This will cause problems when theta is used as divisor.
	#*/
	if (theta > SAFE_THRESHOLD || theta_alt > THRESHOLD_SQUARED) :
		#/* nor is *not* aligned to negative Y-axis (0,-1,0). */

		bMatrix[0][1] = -x;
		bMatrix[1][0] = x;
		bMatrix[1][1] = y;
		bMatrix[1][2] = z;
		bMatrix[2][1] = -z;

		if (theta <= SAFE_THRESHOLD) :
		#/* When nor is close to negative Y axis (0,-1,0) the theta precision is very bad,
		#* so recompute it from x and z instead, using the series expansion for `sqrt`. */
			theta = theta_alt * 0.5 + theta_alt * theta_alt * 0.125;
		#}
#
		bMatrix[0][0] = 1 - x * x / theta;
		bMatrix[2][2] = 1 - z * z / theta;
		bMatrix[2][0] = -x * z / theta;
		bMatrix[0][2] = bMatrix[2][0]
		#print(bMatrix)
	#}
	else:
		printerr("nor is very close to negative Y axis (0,-1,0): use simple symmetry by Z axis.")
		#/* nor is very close to negative Y axis (0,-1,0): use simple symmetry by Z axis. */
		#unit_m3(bMatrix);
		#bMatrix[0][0] =  -1.0;
		#bMatrix[1][1] = bMatrix[0][0]
	#}
#
	#/* Make Roll matrix */
	axis_angle_normalized_to_mat3(rMatrix, nor, roll)
#
	#/* Combine and output result */
	var r_mat = mul_m3_m3(rMatrix, bMatrix);
	#print("rMatrix")
	#print(rMatrix)
	#print("bMatrix")
	#print(bMatrix)
	#print("r_mat")
	#print(r_mat)
	return r_mat
	#}
#
#void axis_angle_normalized_to_mat3(float R[3][3], const float axis[3], const float angle)
static func axis_angle_normalized_to_mat3(R:Array, axis:Vector3, angle:float):
	#print("axis angle normalized to mat3")
	axis_angle_normalized_to_mat3_ex(R, axis, sin(angle), cos(angle));
#oid axis_angle_normalized_to_mat3_ex(float mat[3][3], const float axis[3], const float angle_sin, const float angle_cos
static func axis_angle_normalized_to_mat3_ex(mat:Array, axis:Vector3, angle_sin:float, angle_cos:float):
	var nsi:Vector3 
	var ico:float;
	var n_00:float
	var n_01:float
	var n_11:float
	var n_02:float
	var n_12:float
	var n_22:float

	#BLI_ASSERT_UNIT_V3(axis);

	#/* now convert this to a 3x3 matrix */

	ico = (1.0 - angle_cos);
	nsi[0] = axis[0] * angle_sin;
	nsi[1] = axis[1] * angle_sin;
	nsi[2] = axis[2] * angle_sin;

	n_00 = (axis[0] * axis[0]) * ico;
	n_01 = (axis[0] * axis[1]) * ico;
	n_11 = (axis[1] * axis[1]) * ico;
	n_02 = (axis[0] * axis[2]) * ico;
	n_12 = (axis[1] * axis[2]) * ico;
	n_22 = (axis[2] * axis[2]) * ico;

	mat[0][0] = n_00 + angle_cos;
	mat[0][1] = n_01 + nsi[2];
	mat[0][2] = n_02 - nsi[1];
	mat[1][0] = n_01 - nsi[2];
	mat[1][1] = n_11 + angle_cos;
	mat[1][2] = n_12 + nsi[0];
	mat[2][0] = n_02 + nsi[1];
	mat[2][1] = n_12 - nsi[0];
	mat[2][2] = n_22 + angle_cos;

static func mul_m3_m3(A:Array, B:Array):
	var R = [Vector3.ZERO,Vector3.ZERO,Vector3.ZERO]
	R[0][0] = B[0][0] * A[0][0] + B[0][1] * A[1][0] + B[0][2] * A[2][0];
	R[0][1] = B[0][0] * A[0][1] + B[0][1] * A[1][1] + B[0][2] * A[2][1];
	R[0][2] = B[0][0] * A[0][2] + B[0][1] * A[1][2] + B[0][2] * A[2][2];

	R[1][0] = B[1][0] * A[0][0] + B[1][1] * A[1][0] + B[1][2] * A[2][0];
	R[1][1] = B[1][0] * A[0][1] + B[1][1] * A[1][1] + B[1][2] * A[2][1];
	R[1][2] = B[1][0] * A[0][2] + B[1][1] * A[1][2] + B[1][2] * A[2][2];

	R[2][0] = B[2][0] * A[0][0] + B[2][1] * A[1][0] + B[2][2] * A[2][0];
	R[2][1] = B[2][0] * A[0][1] + B[2][1] * A[1][1] + B[2][2] * A[2][1];
	R[2][2] = B[2][0] * A[0][2] + B[2][1] * A[1][2] + B[2][2] * A[2][2];
	return R

static func swizzle_rotation_matrix_y_up(input:Array):
	#idk how matrix multiplication works. flip the 2nd and third row, and make the second row negative
	var output = [Vector3.ZERO,Vector3.ZERO,Vector3.ZERO]
	output[0] = input[0]
	output[1] = input[2] * -1
	output[2] = input[1]
	return output

static func decompose_matrix4(matrix:Array):
	var position : Vector3
	var rotation_m3 : Array = [Vector3.ZERO,Vector3.ZERO,Vector3.ZERO]
	var rotation_quaternion 
	var scale = Vector3.ZERO
	
	#mat4_to_loc_rot_size(loc, rot, size, (const float(*)[4])self->matrix);
	   #float mat3[3][3]; /* wmat -> 3x3 */
	   #copy_m3_m4(mat3, wmat);
	var mat3 = make_m3_from_m4(matrix)
	mat3_to_rot_size(rotation_m3, scale, mat3);
	   #/* location */
	   #copy_v3_v3(loc, wmat[3]);
	# i dont know why we invert the matrix here, cant find it in the blender source
	#rotation_m3 = [Vector3(rotation_m3[0][0],rotation_m3[1][0],rotation_m3[2][0]),Vector3(rotation_m3[0][1],rotation_m3[1][1],rotation_m3[2][1]),Vector3(rotation_m3[0][2],rotation_m3[1][2],rotation_m3[2][2])]
	rotation_quaternion = mat3_normalized_to_quat_fast( rotation_m3);
	
	return {position=position,rotation_m3=rotation_m3,rotation_quaternion=rotation_quaternion,scale=scale}

#void mat3_normalized_to_quat_fast(float q[4], const float mat[3][3])
static func mat3_normalized_to_quat_fast(mat:Array):
  #BLI_ASSERT_UNIT_M3(mat);
  #/* Caller must ensure matrices aren't negative for valid results, see: #24291, #94231. */
  #BLI_assert(!is_negative_m3(mat));

  #/* Method outlined by Mike Day, ref: https://math.stackexchange.com/a/3183435/220949
   #* with an additional `sqrtf(..)` for higher precision result.
   #* Removing the `sqrt` causes tests to fail unless the precision is set to 1e-6 or larger. */
	var q : Array = [0.0,0.0,0.0,0.0]
	if (mat[2][2] < 0.0) :
		if (mat[0][0] > mat[1][1]) :
			var trace:float = 1.0 + mat[0][0] - mat[1][1] - mat[2][2];
			var s:float = 2.0 * sqrt(trace);
			if (mat[1][2] < mat[2][1]) :
			#/* Ensure W is non-negative for a canonical result. */
				s = -s;
			
			q[1] = 0.25 * s;
			s = 1.0 / s;
			q[0] = (mat[1][2] - mat[2][1]) * s;
			q[2] = (mat[0][1] + mat[1][0]) * s;
			q[3] = (mat[2][0] + mat[0][2]) * s;
			#if (UNLIKELY((trace == 1.0f) && (q[0] == 0.0f && q[2] == 0.0f && q[3] == 0.0f))) {
			if ((trace == 1.0) && (q[0] == 0.0 && q[2] == 0.0 && q[3] == 0.0)) :
			#/* Avoids the need to normalize the degenerate case. */
				q[1] = 1.0;
	  
		else :
			var trace:float = 1.0 - mat[0][0] + mat[1][1] - mat[2][2];
			var s:float = 2.0 * sqrt(trace);
			if (mat[2][0] < mat[0][2]):
				#/* Ensure W is non-negative for a canonical result. */
				s = -s;
			
			q[2] = 0.25 * s;
			s = 1.0 / s;
			q[0] = (mat[2][0] - mat[0][2]) * s;
			q[1] = (mat[0][1] + mat[1][0]) * s;
			q[3] = (mat[1][2] + mat[2][1]) * s;
			#if (UNLIKELY((trace == 1.0f) && (q[0] == 0.0f && q[1] == 0.0f && q[3] == 0.0f))) {
			if ((trace == 1.0) && (q[0] == 0.0 && q[1] == 0.0 && q[3] == 0.0)) :
			#/* Avoids the need to normalize the degenerate case. */
				q[2] = 1.0;
		
	else :
		if (mat[0][0] < -mat[1][1]) :
			var trace:float = 1.0 - mat[0][0] - mat[1][1] + mat[2][2];
			var s:float = 2.0 * sqrt(trace);
			if (mat[0][1] < mat[1][0]):
				#/* Ensure W is non-negative for a canonical result. */
				s = -s;
			
			q[3] = 0.25 * s;
			s = 1.0 / s;
			q[0] = (mat[0][1] - mat[1][0]) * s;
			q[1] = (mat[2][0] + mat[0][2]) * s;
			q[2] = (mat[1][2] + mat[2][1]) * s;
			#if (UNLIKELY((trace == 1.0f) && (q[0] == 0.0f && q[1] == 0.0f && q[2] == 0.0f))) {
			if ((trace == 1.0) && (q[0] == 0.0 && q[1] == 0.0 && q[2] == 0.0)) :
			#/* Avoids the need to normalize the degenerate case. */
				q[3] = 1.0;
	
		else :
		  #/* NOTE(@ideasman42): A zero matrix will fall through to this block,
		   #* needed so a zero scaled matrices to return a quaternion without rotation, see: #101848. */
			var trace:float = 1.0 + mat[0][0] + mat[1][1] + mat[2][2];
			var s:float = 2.0 * sqrt(trace);
			q[0] = 0.25 * s;
			s = 1.0 / s;
			q[1] = (mat[1][2] - mat[2][1]) * s;
			q[2] = (mat[2][0] - mat[0][2]) * s;
			q[3] = (mat[0][1] - mat[1][0]) * s;
			#if (UNLIKELY((trace == 1.0f) && (q[1] == 0.0f && q[2] == 0.0f && q[3] == 0.0f))) {
			if ((trace == 1.0) && (q[1] == 0.0 && q[2] == 0.0 && q[3] == 0.0)) :
				#/* Avoids the need to normalize the degenerate case. */
				q[0] = 1.0;

	if (q[0] < 0.0):
		printerr("q[0] is negative")

  #/* Sometimes normalization is necessary due to round-off errors in the above
   #* calculations. The comparison here uses tighter tolerances than
   #* BLI_ASSERT_UNIT_QUAT(), so it's likely that even after a few more
   #* transformations the quaternion will still be considered unit-ish. */

	#const float q_len_squared = dot_qtqt(q, q);
	#const float threshold = 0.0002f /* #BLI_ASSERT_UNIT_EPSILON */ * 3;
	#if (fabs(q_len_squared - 1.0f) >= threshold) {
		#normalize_qt(q);
	var quat = Quaternion(q[0],q[1],q[2],q[3])
	quat = quat.normalized()
	return quat
	

#void mat3_to_rot_size(float rot[3][3], float size[3], const float mat3[3][3])
static func mat3_to_rot_size(rot:Array, size:Vector3, mat3:Array):
  #/* keep rot as a 3x3 matrix, the caller can convert into a quat or euler */
	rot[0] = mat3[0].normalized()
	rot[1] = mat3[1].normalized()
	rot[2] = mat3[2].normalized()
	#size[0] = mat3[0].dot(mat3[0]); I think?
	#size[1] = normalize_v3_v3(rot[1], mat3[1]);
	size[0] = 1
	size[1] = 1
	size[2] = 1
	if (is_negative_m3(rot)) : #unlikely
		printerr("Negative M3")
		pass
		#negate_m3(rot);
		#negate_v3(size);
	 
#}

static func is_negative_m3(mat:Array):
	return determinant_m3_array(mat) < 0.0;

static func determinant_m3_array(m:Array):
	var determinant = (m[0][0] * (m[1][1] * m[2][2] - m[1][2] * m[2][1]) -
		  m[1][0] * (m[0][1] * m[2][2] - m[0][2] * m[2][1]) +
		  m[2][0] * (m[0][1] * m[1][2] - m[0][2] * m[1][1]));
	#print(determinant)
	return determinant

#MINLINE float normalize_v3_v3_length(float r[3], const float a[3], const float unit_length)
static func normalize_v3_v3_length(a:Vector3, unit_length:float)->float:
	print("normalize_v3_v3_length")
	var d:float = a.dot(a)
	var r = Vector3.ZERO
	#/* A larger value causes normalize errors in a scaled down models with camera extreme close. */
	if (d > 1.0e-35):
		d = sqrt(d)
		r = mul_v3_v3fl(a, unit_length / d);
		print(a)
		print(r)
	else:
	#/* Either the vector is small or one of it's values contained `nan`. */
		r.x = 0
		r.y = 0
		r.z = 0
		d = 0.0;
	#print(r)
	return d;

static func mul_v3_v3fl(a:Vector3, f:float):
	#print("mul_v3_v3fl")
	var r = Vector3.ZERO
	r[0] = a[0] * f;
	r[1] = a[1] * f;
	r[2] = a[2] * f;
	return r

#void mul_m4db_m4db_m4fl(double R[4][4], const double A[4][4], const float B[4][4])
static func mul_m4db_m4db_m4fl(A:Array, B:Array):
  #if (R == A) {
	#double T[4][4];
	#mul_m4db_m4db_m4fl(T, A, B);
	#copy_m4_m4_db(R, T);
	#return;
  #}

  #/* Matrix product: `R[j][k] = B[j][i] . A[i][k]`. */
	var R = [[0,0,0,0],[0,0,0,0],[0,0,0,0],[0,0,0,0]]
	R[0][0] = B[0][0] * A[0][0] + B[0][1] * A[1][0] + B[0][2] * A[2][0] + B[0][3] * A[3][0];
	R[0][1] = B[0][0] * A[0][1] + B[0][1] * A[1][1] + B[0][2] * A[2][1] + B[0][3] * A[3][1];
	R[0][2] = B[0][0] * A[0][2] + B[0][1] * A[1][2] + B[0][2] * A[2][2] + B[0][3] * A[3][2];
	R[0][3] = B[0][0] * A[0][3] + B[0][1] * A[1][3] + B[0][2] * A[2][3] + B[0][3] * A[3][3];

	R[1][0] = B[1][0] * A[0][0] + B[1][1] * A[1][0] + B[1][2] * A[2][0] + B[1][3] * A[3][0];
	R[1][1] = B[1][0] * A[0][1] + B[1][1] * A[1][1] + B[1][2] * A[2][1] + B[1][3] * A[3][1];
	R[1][2] = B[1][0] * A[0][2] + B[1][1] * A[1][2] + B[1][2] * A[2][2] + B[1][3] * A[3][2];
	R[1][3] = B[1][0] * A[0][3] + B[1][1] * A[1][3] + B[1][2] * A[2][3] + B[1][3] * A[3][3];

	R[2][0] = B[2][0] * A[0][0] + B[2][1] * A[1][0] + B[2][2] * A[2][0] + B[2][3] * A[3][0];
	R[2][1] = B[2][0] * A[0][1] + B[2][1] * A[1][1] + B[2][2] * A[2][1] + B[2][3] * A[3][1];
	R[2][2] = B[2][0] * A[0][2] + B[2][1] * A[1][2] + B[2][2] * A[2][2] + B[2][3] * A[3][2];
	R[2][3] = B[2][0] * A[0][3] + B[2][1] * A[1][3] + B[2][2] * A[2][3] + B[2][3] * A[3][3];

	R[3][0] = B[3][0] * A[0][0] + B[3][1] * A[1][0] + B[3][2] * A[2][0] + B[3][3] * A[3][0];
	R[3][1] = B[3][0] * A[0][1] + B[3][1] * A[1][1] + B[3][2] * A[2][1] + B[3][3] * A[3][1];
	R[3][2] = B[3][0] * A[0][2] + B[3][1] * A[1][2] + B[3][2] * A[2][2] + B[3][3] * A[3][2];
	R[3][3] = B[3][0] * A[0][3] + B[3][1] * A[1][3] + B[3][2] * A[2][3] + B[3][3] * A[3][3];
	return R


#void copy_m3_from_m4(float m1[3][3], const float m2[4][4])
static func make_m3_from_m4(m2:Array):
	var m1 = [Vector3.ZERO,Vector3.ZERO,Vector3.ZERO]
	m1[0][0] = m2[0][0];
	m1[0][1] = m2[0][1];
	m1[0][2] = m2[0][2];

	m1[1][0] = m2[1][0];
	m1[1][1] = m2[1][1];
	m1[1][2] = m2[1][2];

	m1[2][0] = m2[2][0];
	m1[2][1] = m2[2][1];
	m1[2][2] = m2[2][2];
	return m1

#void vec_roll_to_mat3(const float vec[3], const float roll, float r_mat[3][3])
static func vec_roll_to_mat3(vec:Vector3, roll:float):
	#print(nor)
	var rmat = vec_roll_to_mat3_normalized(vec.normalized(), roll);
	return rmat
