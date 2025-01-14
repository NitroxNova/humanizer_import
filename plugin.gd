@tool
extends EditorPlugin

func _enter_tree():
	_add_tool_submenu()

func _exit_tree():
	remove_tool_menu_item('Humanizer Import')
	
func _add_tool_submenu():
	var popup_menu = PopupMenu.new()
	popup_menu.add_item("Animations")
	popup_menu.set_item_metadata(popup_menu.item_count-1,run_animation_importer)
	popup_menu.add_item("Equipment")
	popup_menu.set_item_metadata(popup_menu.item_count-1,run_equipment_importer)
	popup_menu.add_item("Generate ZIP")
	popup_menu.set_item_metadata(popup_menu.item_count-1,generate_zip)
	add_tool_submenu_item('Humanizer Import', popup_menu)

	popup_menu.id_pressed.connect(handle_menu_event.bind(popup_menu))

func handle_menu_event(id:int,popup_menu:PopupMenu):
	var callable : Callable = popup_menu.get_item_metadata(id)
	callable.call()
	
func run_animation_importer():
	var popup = load("res://addons/humanizer_import/animation/menu_popup.tscn").instantiate()
	get_editor_interface().popup_dialog(popup)
	
func run_equipment_importer():
	var popup = load("res://addons/humanizer_import/equipment/menu_popup.tscn").instantiate()
	get_editor_interface().popup_dialog(popup)

func generate_zip():
	print("generating zip file")
	var writer := ZIPPacker.new()
	var err := writer.open("res://export/humanizer_mod.zip")
	if err != OK:
		return err
	var contents = _get_files_recursive("res://data/generated/")
	for file_path in contents:
		var local_path = file_path.replace("res://data/generated","humanizer")
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
	#return OK
	
func zip_writer_save_json(writer:ZIPPacker,data,new_path:String):
	writer.start_file(new_path)
	writer.write_file(JSON.stringify(data).to_utf8_buffer())
	writer.close_file()

func zip_writer_copy_file(writer:ZIPPacker, old_path,new_path):
	writer.start_file(new_path)
	writer.write_file(FileAccess.get_file_as_bytes(old_path))
	writer.close_file()
	
func _get_files_recursive(path:String):
	var paths = []
	for file in DirAccess.get_files_at(path):
		paths.append(path.path_join(file))
	for dir in DirAccess.get_directories_at(path):
		paths.append_array(_get_files_recursive(path.path_join(dir)))
	return paths
		
