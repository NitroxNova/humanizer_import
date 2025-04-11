extends Resource
class_name HumanizerEquipmentImportService

static func generate_tag_from_guess(name: String) -> Array:
	# manual search... assets dont have some of them
	# Head
	# Eyes
	# Mouth
	# Hands
	# Arms
	# Torso
	# Legs
	# Feet
	var tags = []
	var tag_lookup = {
		"HeadClothes" : ["horn", "glasses", "hat", "mouth", "helmet", "antler", "veil", "cap", "beard", "bonnet", "mask", "moustache", "mask"],
		"TorsoClothes" : ["sweater", "tunic", "sash", "shirt", "robe", "bikini", "belt", "jacket", "suit", "vest", "dress", "bra", "top", "babydoll", "apron", "wings", "armor", "baby_doll", "uniform", "tank"],
		"LegsClothes" : ["stocking", "skirt", "trouser", "jeans", "pants", "panty", "thong", "shorts", "tail"],
		"FeetClothes" : ["shoe", "feet", "sock", "boot", "flats", "sneakers"],
		"HandsClothes" : ["guitar", "sleeve", "bow", "weapon"]
	}
	name = name.to_lower()
	print("Auto detecting tag from name...")
	var found = false
	for slot in tag_lookup.keys():
		for item_tag in tag_lookup[slot]:
			if name.contains(item_tag):
				print("Auto generated tag: ", slot, " contains ", item_tag)
				tags.append(slot)
	return tags


static func import(json_path:String,import_materials:=true):
	#load settings
	var settings = HumanizerResourceService.load_resource(json_path)
	var folder = json_path.get_base_dir()
	if import_materials:
		#generate material files
		HumanizerMaterialService.import_materials(folder)
	#load mhclo
	var mhclo := MHCLO.new()
	mhclo.parse_file(settings.mhclo)
	print('Importing asset ' + folder)
	# Build resource object
	var equip_type := HumanizerEquipmentType.new()
	# Mesh operations
	_build_import_mesh(folder, mhclo)

	equip_type.path = folder
	equip_type.resource_name = mhclo.resource_name
	equip_type.default_material = settings.default_material
	var save_path = folder.path_join(equip_type.resource_name + '.res')
	var mats = HumanizerMaterialService.search_for_materials(mhclo.mhclo_path)
	equip_type.textures = mats.materials
	equip_type.overlays = mats.overlays
	equip_type.display_name = settings.display_name

	equip_type.slots.clear()
	for slot in settings.slots:
		print("Added to slot: ", slot)
		equip_type.slots.append(slot)

	if equip_type.slots.is_empty():
		var tags = generate_tag_from_guess(equip_type.resource_name)
		equip_type.slots.append_array(tags)
		print("Auto generated tags: ", tags)

	if equip_type.slots.is_empty():
		printerr("Warning - " + equip_type.resource_name + " has no equipment slots, you can manually add them to the resource file.")

	if folder.contains("/skins/"):
		print("Detected Skin - Adding to the DefaultBody! ", folder)
		var body_path: String = "res://addons/humanizer/data/assets/equipment/body/Default/DefaultBody.res"
		var default_body: HumanizerEquipmentType = load(body_path)
		ResourceSaver.save(default_body, body_path)
	_calculate_bone_weights(mhclo,settings)
	
	HumanizerResourceService.save_resource(save_path,equip_type)

	#build rigged equipment
	if settings.rigged_glb != "":
		var rigged_resource : HumanizerEquipmentType = equip_type.duplicate()
		rigged_resource.display_name = equip_type.display_name + " (Rigged)"
		rigged_resource.resource_name = equip_type.resource_name + "_Rigged"
		rigged_resource.material_override = equip_type.resource_name
		_calculate_attached_bone_weights(mhclo,settings,rigged_resource)
		var rigged_filename = equip_type.resource_path.get_basename() + "_Rigged.res"
		HumanizerResourceService.save_resource(rigged_filename,rigged_resource)
		HumanizerRegistry.add_equipment_type(rigged_resource)
		
		
	#save after adding bone/weights to mhclo
	HumanizerResourceService.save_resource(equip_type.mhclo_path,mhclo)
	#add main resource to registry
	HumanizerRegistry.add_equipment_type(equip_type)	

static func get_import_settings_path(equip_id:String)->String:
	var json_path = "res://data/generated/equipment/" + equip_id + "/import_settings.json"
	#print(json_path)
	return json_path

static func get_equipment_resource_path(mhclo_path)->String:
	var res_path = mhclo_path.get_basename()
	res_path += ".res"
	return res_path

static func load_import_settings(mhclo_path:String):
	var json_path = get_import_settings_path(mhclo_path.get_file().get_basename())
	var settings := {}
	if FileAccess.file_exists(json_path):
		#print("loading json") 
		#if you already know the json path just use this line 
		settings = HumanizerResourceService.load_resource(json_path)
		if "version" not in settings:
			settings.version = 1.0
		var version = float(settings.version)
		
	else:
		settings.version = 1.0
		settings.mhclo = mhclo_path
		settings.slots = []
		settings.attach_bones = []
		var mhclo := MHCLO.new()
		mhclo.parse_file(mhclo_path)
		settings.material_override = search_for_material_override(mhclo_path)
		#print(settings.material_override)
		settings.default_material = HumanizerMaterialImportService.default_material_from_mhclo(mhclo)	
		settings.display_name = mhclo.display_name
		settings.rigged_glb = search_for_rigged_glb(mhclo_path)
				
	#override the slots from the folder - so if config changes they all update
	var slots_ovr = HumanizerImportConfig.get_folder_override_slots(mhclo_path)
	#print(slots_ovr)
	if not slots_ovr.is_empty():
		settings.slots = []
		settings.slots.append_array(slots_ovr)
	
	return settings

static func search_for_material_override(mhclo_path:String):
	# for equipment that shares materials, such as Left and Right (Eyes, Eyebrows..) and the Body Proxies, or outfits that have been separated
	#they have to be placed in the same input folder to be automatically detected, otherwise, manually set in the 'material_overide' dropdown
	for file in DirAccess.get_files_at( mhclo_path.get_base_dir()):
		#if this is not the first mhclo in the folder, set the material_override to the first mhclo
		if file.get_extension() == "mhclo":
			if file == mhclo_path.get_file():
				return ""
			else:
				return file.get_basename()

static func search_for_rigged_glb(mhclo_path:String)->String:
	var glb_path = mhclo_path.get_basename() + ".glb"
	#print(glb_path)
	if FileAccess.file_exists(glb_path):
		return glb_path
	return ""
	
static func import_all():
	print("Importing all Equipment")
	#first, look for mhclos without settings.json , want to copy those settings before deleting the resource
	scan_for_missing_import_settings("res://data/input/equipment")
		
	#now that all import_settings.json and folder has been created..
	for equip_id in get_generated_equipment_ids():
		import(get_import_settings_path(equip_id),true)

static func purge_generated():
	print("Purging Generated Resources - Keep import_settings.json")
	var files:Array = OSPath.get_files_recursive("res://data/generated/")
	files.append_array(OSPath.get_files_recursive("res://data/temp/"))
	for file_path:String in files:
		if file_path.ends_with("import_settings.json"):
			pass #dont delete
		else:
			DirAccess.remove_absolute(file_path)
	OSPath.delete_empty_folders("res://data/generated/")
	OSPath.delete_empty_folders("res://data/temp/")
			
static func get_generated_equipment_ids():
	var equip = []
	for filename:String in OSPath.get_files_recursive("res://data/generated/equipment"):
		if filename.get_file() == "import_settings.json":
			equip.append(filename.get_base_dir().get_file())
	return equip
		
static func import_folder(path):
	for folder in OSPath.get_dirs(path):
		import_folder(folder)
	
	for file in OSPath.get_files(path):
		if file.ends_with("import_settings.json"):
			import(file,false) #already generated materials			
	

static func scan_for_missing_import_settings(path):
	for folder in OSPath.get_dirs(path):
		scan_for_missing_import_settings(folder)
	for file in OSPath.get_files(path):
		if file.get_extension() == "mhclo":
			#need to rewrite json incase slots categories have been updated
			var equip_id = file.get_file().get_basename()
			var settings_path = get_import_settings_path(equip_id)
			var equip_settings = HumanizerEquipmentImportService.load_import_settings(file)
			HumanizerResourceService.save_resource(settings_path,equip_settings)
	
static func _calculate_bone_weights(mhclo:MHCLO,import_settings:Dictionary):
	for rig_name in HumanizerRegistry.rigs:
		var rig : HumanizerRig = HumanizerRegistry.rigs[rig_name]
		var skeleton_data = HumanizerRigService.init_skeleton_data(rig,false)
		HumanizerEquipmentService.interpolate_weights( mhclo,rig,skeleton_data)
			

static func _calculate_attached_bone_weights(mhclo:MHCLO,import_settings:Dictionary,equip_type:HumanizerEquipmentType):
	var rigged_bone_weights = _build_rigged_bone_arrays(mhclo,import_settings.rigged_glb)
	equip_type.rig_config = HumanizerEquipmentRigConfig.new()
	equip_type.rig_config.config = rigged_bone_weights.config
	equip_type.rig_config.attach_bones = import_settings.attach_bones
	if import_settings.attach_bones.is_empty():
		printerr("No attach bones for " + equip_type.display_name)
		
	for rig_name in HumanizerRegistry.rigs:
		var rig_bw = HumanizerEquipmentService.interpolate_rigged_weights(mhclo,rigged_bone_weights,rig_name)
		equip_type.rig_config.bones[rig_name] = rig_bw.bones
		equip_type.rig_config.weights[rig_name] = rig_bw.weights
	
static func _build_import_mesh(path: String, mhclo: MHCLO) -> ArrayMesh: 
	# build basis from obj file
	var obj_path = mhclo.mhclo_path.get_base_dir().path_join(mhclo.obj_file_name)
	var obj_mesh := ObjToMesh.new(obj_path).run()
	var mesh = obj_mesh.mesh
	mhclo.mh2gd_index = obj_mesh.mh2gd_index
	mhclo.uv_array = obj_mesh.sf_arrays[Mesh.ARRAY_TEX_UV]
	mhclo.index_array = obj_mesh.sf_arrays[Mesh.ARRAY_INDEX]
	mhclo.custom0_array = obj_mesh.sf_arrays[Mesh.ARRAY_CUSTOM0]
	return mesh

static func _build_rigged_bone_arrays(mhclo:MHCLO,glb:String) -> Dictionary:
	var gltf := GLTFDocument.new()
	var state := GLTFState.new()
	var error = gltf.append_from_file(glb, state)
	if error != OK:
		push_error('Failed to load glb : ' + glb)
		return {}
	var root = gltf.generate_scene(state)
	
	#var skeleton:Skeleton3D = root.get_child(0).get_child(0)
	var skeleton_nodes = root.find_children("*","Skeleton3D")
	if skeleton_nodes.size() < 1:
		printerr("couldnt find skeleton in GLB file " + glb)
		return {}
	elif skeleton_nodes.size() > 1:
		printerr("too many skeletons in GLB, there should only be one " + glb)
		return {}
	var skeleton : Skeleton3D = skeleton_nodes[0]
	
	var glb_arrays = (skeleton.get_child(0) as ImporterMeshInstance3D).mesh.get_surface_arrays(0)
	

	if glb_arrays == null:
		printerr("couldnt find mesh in GLB file " + glb)
		return {}
	
	var mh_to_glb_idx = []
	mh_to_glb_idx.resize(mhclo.mh2gd_index.size())
	
	var max_id = roundi(1 / glb_arrays[Mesh.ARRAY_TEX_UV2][0].y) 
	for glb_id in glb_arrays[Mesh.ARRAY_TEX_UV2].size():
		var uv2 = glb_arrays[Mesh.ARRAY_TEX_UV2][glb_id]
		var mh_id = roundi(uv2.x * max_id)
		if mh_to_glb_idx[mh_id] == null:
			mh_to_glb_idx[mh_id] = []
		mh_to_glb_idx[mh_id].append(glb_id)
	
	var bone_config = []
	for bone_id in skeleton.get_bone_count():
		#remove root bone, need to discuss
		var bone_name :String = skeleton.get_bone_name(bone_id)
		if bone_name.to_lower() in ["neutral_bone","root"]:
			continue
		bone_config.append({old_id=bone_id,name=bone_name})
	
	#remapping bones here to make it easier down the line, remove the root / neutral_bone
	for this_bone in bone_config:
		var bone_id = this_bone.old_id
		this_bone.transform = skeleton.get_bone_rest(bone_id) #for local bone rotation
		var old_parent_id = skeleton.get_bone_parent(bone_id)
		var parent_id = -1
		for p_bone_id in bone_config.size():
			if bone_config[p_bone_id].old_id == old_parent_id:
				parent_id = p_bone_id
		this_bone.parent = parent_id
		
		# This is ugly but it should work
		this_bone.vertices = {'ids': []}

		## Find nearest vertex to bone and then nearest vertex in opposite direction
		var vtx1: Vector3
		var vtx2: Vector3
		var min_distancesq: float = 1e11
		var min_id: int = -1
		var bone_pos: Vector3 = skeleton.get_bone_global_rest(bone_id).origin
		
		# Find closest distance squared
		for vtx in glb_arrays[Mesh.ARRAY_VERTEX].size():
			var distsq: float = bone_pos.distance_squared_to(glb_arrays[Mesh.ARRAY_VERTEX][vtx])
			if distsq < min_distancesq:
				min_distancesq = distsq
		# Now find vertex mh_id which is that far away
		for vtx in glb_arrays[Mesh.ARRAY_VERTEX].size():
			var distsq: float = bone_pos.distance_squared_to(glb_arrays[Mesh.ARRAY_VERTEX][vtx])
			if distsq == min_distancesq:  # Equal should be okay.  float math is deterministic on the same platform i think
				for mh_id in mh_to_glb_idx.size():
					if vtx in mh_to_glb_idx[mh_id]:
						min_id = mh_id
						vtx1 = glb_arrays[Mesh.ARRAY_VERTEX][vtx]
						break
			if min_id != -1:
				break
		# Add this id to the config
		this_bone.vertices['ids'].append(min_id)
		
		min_distancesq = 1e11
		min_id = -1
		var opposite_side = bone_pos + (bone_pos - vtx1)
		for vtx in glb_arrays[Mesh.ARRAY_VERTEX].size():
			var distsq: float = opposite_side.distance_squared_to(glb_arrays[Mesh.ARRAY_VERTEX][vtx])
			if distsq < min_distancesq:
				min_distancesq = distsq
		for vtx in glb_arrays[Mesh.ARRAY_VERTEX].size():
			var distsq: float = opposite_side.distance_squared_to(glb_arrays[Mesh.ARRAY_VERTEX][vtx])
			if distsq == min_distancesq:
				for mh_id in mh_to_glb_idx.size():
					if vtx in mh_to_glb_idx[mh_id]:
						min_id = mh_id
						vtx2 = glb_arrays[Mesh.ARRAY_VERTEX][vtx]
						break
			if min_id != -1:
				break
				
		this_bone.vertices['ids'].append(min_id)
		this_bone.vertices['offset'] = bone_pos - 0.5 * (vtx1 + vtx2)
		# Now when we build the skeleton we just set the global bone position to
		# 0.5 * (v1 + v2) + offset
	
	var weights_override = []
	weights_override.resize(mhclo.mh2gd_index.size())
	var bones_override = []
	bones_override.resize(mhclo.mh2gd_index.size())
	var bones_per_vtx = glb_arrays[Mesh.ARRAY_BONES].size()/glb_arrays[Mesh.ARRAY_VERTEX].size()

	for mh_id in mh_to_glb_idx.size():
		var glb_id = mh_to_glb_idx[mh_id][0]
		bones_override[mh_id] = glb_arrays[Mesh.ARRAY_BONES].slice(glb_id*bones_per_vtx,(glb_id+1) * bones_per_vtx)
		weights_override[mh_id] = glb_arrays[Mesh.ARRAY_WEIGHTS].slice(glb_id*bones_per_vtx,(glb_id+1) * bones_per_vtx)
	
	var rigged_bone_weights = {}
	rigged_bone_weights.bones = bones_override
	rigged_bone_weights.weights = weights_override
	rigged_bone_weights.config = bone_config
	return rigged_bone_weights
