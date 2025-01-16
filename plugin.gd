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
	
	
	var equipment_menu = PopupMenu.new()
	equipment_menu.name = "equipment"
	equipment_menu.add_item("Manual Import")
	equipment_menu.set_item_metadata(equipment_menu.item_count-1,run_equipment_importer)
	equipment_menu.add_item("Import All")
	equipment_menu.set_item_metadata(equipment_menu.item_count-1,HumanizerEquipmentImportService.import_all)
	popup_menu.add_child(equipment_menu)
	popup_menu.add_submenu_item('Equipment', 'equipment')
	
	popup_menu.add_item("Generate ZIP")
	popup_menu.set_item_metadata(popup_menu.item_count-1,generate_zip)
	add_tool_submenu_item('Humanizer Import', popup_menu)

	popup_menu.id_pressed.connect(handle_menu_event.bind(popup_menu))
	equipment_menu.id_pressed.connect(handle_menu_event.bind(equipment_menu))

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
	var popup = load("res://addons/humanizer_import/pack/popup.tscn").instantiate()
	get_editor_interface().popup_dialog(popup)
	
