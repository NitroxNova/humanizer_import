@tool
extends Resource
class_name HumanizerZipService

static var MAT3D_TEXTURES = get_material3d_texture_properties()

static func get_material3d_texture_properties():
	var t_props = []
	var blank_mat = StandardMaterial3D.new()
	for prop in blank_mat.get_property_list():
		if prop.class_name == "Texture2D":
			t_props.append(prop.name)
	return t_props

static func generate_zip(pack_name:String):
	var json_path = "res://data/pack".path_join(pack_name + ".json")
	var selected_files:Array = OSPath.read_json(json_path)
	
	#print("generating zip file")
	var writer := ZIPPacker.new()
	if not DirAccess.dir_exists_absolute("res://export"):
		DirAccess.make_dir_absolute("res://export")
	var zip_path = "res://export".path_join(pack_name+".zip")
	var err := writer.open(zip_path)
	if err != OK:
		return err
	for file_path:String in selected_files:
		if file_path.get_extension() == "data":
			zip_writer_copy_file(writer,file_path,file_path.replace("res://humanizer","humanizer"))
			continue
		var file_res = load(file_path)
		var input_folder = file_path.get_base_dir()
		if file_res is HumanizerEquipmentType:
			var equip_id = file_path.get_base_dir().get_file()
			var export_folder = "humanizer/equipment/".path_join(equip_id)
			for filename in DirAccess.get_files_at(input_folder):
				if filename != "import_settings.json":
					zip_writer_copy_file(writer,input_folder.path_join(filename),export_folder.path_join(filename))
		elif file_res is StandardMaterial3D:
			var equip_id = file_path.get_base_dir().get_file()
			var mat_id = file_path.get_file().get_basename()
			var export_folder = "humanizer/material/".path_join(equip_id)
			var mat_res = load("res://humanizer/material".path_join(equip_id).path_join(mat_id + ".res"))
			
			for texture_prop in MAT3D_TEXTURES:
				var texture = mat_res.get(texture_prop)
				if texture == null:
					continue
				var export_path = texture.resource_path.replace("res://humanizer","humanizer")
				zip_writer_copy_file(writer,texture.resource_path,export_path)
				#mat_res[texture_prop].take_over_path(texture.resource_path.replace("humanizer","humanizer"))
				
			var temp_path = "res://data/temp/material.res"
			
			HumanizerResourceService.save_resource(temp_path,mat_res)
			zip_writer_copy_file(writer,"res://data/temp/material.res",export_folder.path_join( file_path.get_file()))
		elif file_res is HumanizerOverlay:
			var equip_id = file_path.split("/",false)[4] #res://data/input/material/ Equip_ID
			#print(file_path)
			var export_folder = "humanizer/material/".path_join(equip_id)
			store_textures_from_overlay(writer,file_res,file_path.get_base_dir(),equip_id)
			zip_writer_copy_file(writer,file_path,export_folder.path_join( file_path.get_file()))
		elif file_res is HumanizerMaterial:
			var equip_id = file_path.split("/",false)[4] #res://data/input/material/ Equip_ID
			var export_folder = "humanizer/material/".path_join(equip_id)
			for overlay in file_res.overlays:
				store_textures_from_overlay(writer,overlay,file_path.get_base_dir(),equip_id)
			zip_writer_copy_file(writer,file_path,export_folder.path_join( file_path.get_file()))
		else:
			zip_writer_copy_file(writer,file_path,file_path.replace("res://humanizer","humanizer"))
	writer.close()
	print("pack saved to " + zip_path)
	#return OK

static func store_textures_from_overlay(writer:ZIPPacker ,overlay:HumanizerOverlay,input_folder:String,equip_id:String):
	var textures = ["albedo","normal","ao"]	
	for t in textures:
		var t_id = t + "_texture_path"
		var t_path = overlay.get(t_id)
		if t_path not in [null,""]:
			#see if theres an image in the folder with the same name, otherwise assume its imported in a different pack
			var local_texture_path = input_folder.path_join(t_path.get_file())
			for ext in ["png","jpg","jpeg"]:
				if FileAccess.file_exists(local_texture_path+"."+ext):
					var ctex_path = "res://humanizer/material/"+ equip_id.path_join(t_path.get_file()+".image.res")
					var new_texture_path = "humanizer/material/"+ equip_id.path_join(t_path.get_file()+".image.res")
					zip_writer_copy_file(writer,ctex_path,new_texture_path)
	
static func zip_writer_save_json(writer:ZIPPacker,data,new_path:String):
	writer.start_file(new_path)
	writer.write_file(JSON.stringify(data).to_utf8_buffer())
	writer.close_file()

static func zip_writer_copy_file(writer:ZIPPacker, old_path,new_path):
	writer.start_file(new_path)
	writer.write_file(FileAccess.get_file_as_bytes(old_path))
	writer.close_file()
