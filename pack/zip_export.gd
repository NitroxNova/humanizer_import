@tool
extends Resource
class_name HumanizerZipService


static func generate_zip(pack_name:String):
	var json_path = "res://data/pack".path_join(pack_name + ".json")
	var selected_folders:Array = OSPath.read_json(json_path)
	var contents = []
	for folder in selected_folders:
		contents.append_array(OSPath.get_files_recursive(folder))
	#print("generating zip file")
	var writer := ZIPPacker.new()
	var zip_path = "res://export".path_join(pack_name+".zip")
	var err := writer.open(zip_path)
	if err != OK:
		return err
	for file_path in contents:
		var local_path = file_path.replace("res://data/generated","humanizer")
		if file_path.get_file() == "import_settings.json":
			continue
		if file_path.get_file() == "standard_material.res":
			var material : StandardMaterial3D = load(file_path)
			var material_data := {}
			var blank_mat = StandardMaterial3D.new()
			for prop in material.get_property_list():
				var prop_value = material.get(prop.name)
				if prop_value != blank_mat.get(prop.name) and prop.name != "resource_path":
					if prop_value is CompressedTexture2D:
						var t_id = prop.name.replace("_texture","")
						var new_texture_path = local_path.get_base_dir().path_join(t_id+ ".png")
						zip_writer_copy_file(writer,prop_value.resource_path,new_texture_path)
						material_data[prop.name] = "res://" + new_texture_path
						
					else:
						material_data[prop.name] = prop_value
			zip_writer_save_json(writer,material_data,local_path.get_base_dir().path_join("standard_material.json"))
		else:
			zip_writer_copy_file(writer,file_path,local_path)
		
	writer.close()
	print("pack saved to " + zip_path)
	#return OK
	
static func zip_writer_save_json(writer:ZIPPacker,data,new_path:String):
	writer.start_file(new_path)
	writer.write_file(JSON.stringify(data).to_utf8_buffer())
	writer.close_file()

static func zip_writer_copy_file(writer:ZIPPacker, old_path,new_path):
	writer.start_file(new_path)
	writer.write_file(FileAccess.get_file_as_bytes(old_path))
	writer.close_file()
