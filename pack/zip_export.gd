@tool
extends Resource
class_name HumanizerZipService


static func generate_zip(pack_name:String):
	var json_path = "res://data/pack".path_join(pack_name + ".json")
	var selected_files:Array = OSPath.read_json(json_path)
	
	#print("generating zip file")
	var writer := ZIPPacker.new()
	var zip_path = "res://export".path_join(pack_name+".zip")
	var err := writer.open(zip_path)
	if err != OK:
		return err
	for file_path:String in selected_files:
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
			var mat_res = load("res://data/generated/material".path_join(equip_id).path_join(mat_id + ".res"))
			var material_data := {}
			var blank_mat = StandardMaterial3D.new()
			for prop in mat_res.get_property_list():
				var prop_value = mat_res.get(prop.name)
				if prop_value != blank_mat.get(prop.name) and prop.name != "resource_path":
					if prop_value is CompressedTexture2D:
						var t_id = prop.name.replace("_texture","")
						var new_texture_path = export_folder.path_join(prop_value.resource_path.get_file())
						zip_writer_copy_file(writer,prop_value.resource_path,new_texture_path)
						material_data[prop.name] = "res://" + new_texture_path
						
					else:
						material_data[prop.name] = prop_value
			zip_writer_save_json(writer,material_data,export_folder.path_join(mat_id + ".json"))
		elif file_res is HumanizerOverlay:
			var equip_id = file_path.split("/",false)[4] #res://data/input/material/ Equip_ID
			#print(file_path)
			var export_folder = "humanizer/material/".path_join(equip_id)
			store_textures_from_overlay(writer,file_res,file_path.get_base_dir(),export_folder)
			zip_writer_copy_file(writer,file_path,export_folder.path_join( file_path.get_file()))
		elif file_res is HumanizerMaterial:
			var equip_id = file_path.split("/",false)[4] #res://data/input/material/ Equip_ID
			var export_folder = "humanizer/material/".path_join(equip_id)
			for overlay in file_res.overlays:
				store_textures_from_overlay(writer,overlay,file_path.get_base_dir(),export_folder)
			zip_writer_copy_file(writer,file_path,export_folder.path_join( file_path.get_file()))
	writer.close()
	print("pack saved to " + zip_path)
	#return OK

static func store_textures_from_overlay(writer:ZIPPacker ,overlay:HumanizerOverlay,input_folder:String,export_folder:String):
	var textures = ["albedo","normal","ao"]	
	for t in textures:
		var t_id = t + "_texture_path"
		var t_path = overlay.get(t_id)
		if t_path not in [null,""]:
			#see if theres an image in the folder with the same name, otherwise assume its imported in a different pack
			var local_texture_path = input_folder.path_join(t_path.get_file())
			if FileAccess.file_exists(local_texture_path):
				var new_texture_path = export_folder.path_join( t_path.get_file())
				zip_writer_copy_file(writer,local_texture_path,new_texture_path)
	
static func zip_writer_save_json(writer:ZIPPacker,data,new_path:String):
	writer.start_file(new_path)
	writer.write_file(JSON.stringify(data).to_utf8_buffer())
	writer.close_file()

static func zip_writer_copy_file(writer:ZIPPacker, old_path,new_path):
	writer.start_file(new_path)
	writer.write_file(FileAccess.get_file_as_bytes(old_path))
	writer.close_file()
