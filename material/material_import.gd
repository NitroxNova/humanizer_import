extends Resource
class_name HumanizerMaterialImportService

static func import_materials(equip_id:String):
	var json_path = HumanizerEquipmentImportService.get_import_settings_path(equip_id)
	var settings = OSPath.read_json(json_path)
	if not settings.material_override == "":
		#materials will be imported by overriding equipment
		return
	var mhclo_path = settings.mhclo
	
	#var equip_path = "res://data/g/equipment".path_join(equip_id)
	for file_name in OSPath.get_files_recursive(mhclo_path.get_base_dir()):
		if file_name.get_extension() == "mhmat":
			var new_mat = mhmat_to_material(file_name,equip_id)
			var mat_id = file_name.get_file().get_basename()
			var mat_path = "res://data/generated/material/" + equip_id
			mat_path = mat_path.path_join(mat_id + ".res")
			HumanizerResourceService.save_resource(mat_path,new_mat)

static func search_for_materials(mhclo_path:String):
	var materials = {}
	var overlays = {}
	var equip_id = mhclo_path.get_file().get_basename() #get rid of both .mhclo.res extensions
	var sub_mats = get_manual_materials(equip_id)
	materials.merge(sub_mats.materials)
	overlays.merge(sub_mats.overlays)
	#search for the generated materials after, so custom materials are first in the list
	materials.merge(search_for_generated_materials(mhclo_path.get_base_dir()))
	return {materials=materials,overlays=overlays}	

static func get_manual_materials(equip_id:String): #custom defined materials
	var materials = {}
	var overlays = {}
	
	var materials_path = "res://data/input/material/" + equip_id
	if not DirAccess.dir_exists_absolute(materials_path):
		return {materials=materials,overlays=overlays}
	for mat_file in OSPath.get_files_recursive(materials_path):
		if mat_file.get_extension() == "res":
			var mat_res = load(mat_file)
			if mat_res is HumanizerMaterial or mat_res is StandardMaterial3D:
				materials[mat_file.get_file().get_basename().get_basename()] = mat_file
			elif mat_res is HumanizerOverlay:
				overlays[mat_file.get_file().get_basename()] = mat_file
	
	return {materials=materials,overlays=overlays}
	
static func search_for_generated_materials(folder:String)->Dictionary:
	var materials = {}
	for subfolder in OSPath.get_dirs(folder):
		materials.merge(search_for_generated_materials(subfolder))	
	# top folder should override if conflicts
	for file_name in OSPath.get_files(folder):
		if file_name.get_extension() == "mhmat":
			#may not have been imported yet, thats ok, just return what the filename will be
			var mat_res_path = file_name.replace(".mhmat",".material.res")
			materials[file_name.get_file().get_basename()] = mat_res_path
	return materials

static func default_material_from_mhclo(mhclo:MHCLO):
	var default_material = ""
	var material_path = mhclo.mhclo_path.get_base_dir().path_join(mhclo.default_material)
	if FileAccess.file_exists(material_path):
		default_material = mhclo.default_material.replace(".mhmat","")
	elif not mhclo.default_material == "":
		printerr(" warning - mhmat does not exist - " + material_path)
	#if default material is not set in mhclo (or if the name is invalid - most likely)
	#just fill in with the first material in the list, starting with manually defined materials at the top
	#its much easier for them to change it in the dropdown than to find the file and edit the text
	if default_material == "":
		var mat_list = search_for_materials(mhclo.mhclo_path)
		if mat_list.size() > 0:
			default_material = mat_list.materials.keys()[0]
	return default_material

static func make_portable_material(folder:String,file_name:String,equip_id:String,texture_prop:String,material:StandardMaterial3D):
	var image_path = folder.path_join(file_name)
	var image : Image = Image.load_from_file(image_path)
	var is_normal = (texture_prop=="normal_texture")
	image.generate_mipmaps(is_normal)
	var texture = PortableCompressedTexture2D.new()
	texture.create_from_image(image,PortableCompressedTexture2D.COMPRESSION_MODE_LOSSLESS) 
	var texture_path = "res://data/generated/material/"+equip_id
	if not DirAccess.dir_exists_absolute(texture_path):
		DirAccess.make_dir_recursive_absolute(texture_path)
	texture_path = texture_path.path_join(image_path.get_file().get_basename() + ".res")
	texture.take_over_path(texture_path)
	ResourceSaver.save(texture,texture_path)
	material[texture_prop] = texture
	#material[texture_prop].take_over_path(texture_path.replace("data/generated","humanizer"))
	#return texture
	
static func mhmat_to_material(path:String,equip_id:String)->StandardMaterial3D:
	var material = StandardMaterial3D.new()
	var file = FileAccess.open(path,FileAccess.READ)
	while file.get_position() < file.get_length():
		var line :String = file.get_line()
		if line.begins_with("name "):
			material.resource_name = line.split(" ",false,1)[1]
		elif line.begins_with("diffuseColor "):
			var color_f = line.split_floats(" ",false)
			var color = Color(color_f[1],color_f[2],color_f[3])
			material.albedo_color = color
		elif line.begins_with("shininess "):
			material.roughness = 1-(line.split_floats(" ",false)[1]*.5) 
		elif line.begins_with("transparent "):
			if line.split(" ")[1] == "True":
				material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
		elif line.begins_with("backfaceCull "):
			if line.split(" ")[1] == "False":
				material.cull_mode = BaseMaterial3D.CULL_DISABLED
		
		elif line.begins_with("diffuseTexture "):
			var diffuse_file = line.split(" ")[1].strip_edges()
			make_portable_material(path.get_base_dir(),diffuse_file,equip_id,"albedo_texture",material)
		
		elif line.begins_with("normalmapTexture "):
			var normal_path = line.split(" ")[1].strip_edges()
			make_portable_material(path.get_base_dir(),normal_path,equip_id,"normal_texture",material)
			material.normal_enabled = true
			
		elif line.begins_with("bumpTexture "):
			var bump_path = line.split(" ")[1].strip_edges()
			bump_path = path.get_base_dir().path_join(bump_path)
			var normal_texture : Image = load(bump_path).get_image().duplicate()
			normal_texture.bump_map_to_normal_map()
			bump_path = bump_path.replace('.png', '_normal.png')
			#normal_texture.save_png( bump_path)
			material.normal_texture = normal_texture
			material.normal_enabled = true
		
		elif line.begins_with("aomapTexture "):
			var ao_path = line.split(" ")[1].strip_edges()
			make_portable_material(path.get_base_dir(),ao_path,equip_id,"ao_texture",material)
			material.ao_enabled = true
			
		elif line.begins_with("specularTexture "):
			var spec_path = line.split(" ")[1].strip_edges()
			make_portable_material(path.get_base_dir(),spec_path,equip_id,"metallic_texture",material)
			material.metallic = 1
			printerr("specular texture not supported by Godot, using as metallic texture instead. You can manually create materials by adding them to the assets/materials/%asset_name% folder")
		
		elif line.begins_with("normalmapIntensity "):
			material.normal_scale = line.split_floats(" ",false,)[1]
		elif line.begins_with("aomapIntensity "):
			material.ao_light_affect = line.split_floats(" ",false,)[1]
		elif line.begins_with("shaderConfig "):
			pass
	return material
	
