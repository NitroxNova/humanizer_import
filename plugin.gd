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
	var err := writer.open("res://humanizer_mod.zip")
	if err != OK:
		return err
	var contents = _get_files_recursive("res://humanizer/")
	for file in contents:
		var local_path = file.replace("res://","")
		writer.start_file(local_path)
		writer.write_file(FileAccess.get_file_as_bytes(file))
		writer.close_file()
	writer.close()
	#return OK
	
func _get_files_recursive(path:String):
	var paths = []
	for file in DirAccess.get_files_at(path):
		paths.append(path.path_join(file))
	for dir in DirAccess.get_directories_at(path):
		paths.append_array(_get_files_recursive(path.path_join(dir)))
	return paths
		
