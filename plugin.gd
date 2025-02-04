@tool
extends EditorPlugin

# Thread for background tasks
var thread := Thread.new()

func _enter_tree():
	_add_tool_submenu()
	HumanizerImportConfig.init_settings()

func _exit_tree():
	remove_tool_menu_item('Humanizer Import')	
	if thread.is_started():
		thread.wait_to_finish()
	
func _add_tool_submenu():
	var popup_menu = PopupMenu.new()
	popup_menu.add_item("Animations")
	popup_menu.set_item_metadata(popup_menu.item_count-1,run_animation_importer)
	
	
	var equipment_menu = PopupMenu.new()
	equipment_menu.add_item("Manual Import")
	equipment_menu.set_item_metadata(equipment_menu.item_count-1,run_equipment_importer)
	equipment_menu.add_item("Import All")
	equipment_menu.set_item_metadata(equipment_menu.item_count-1,HumanizerEquipmentImportService.import_all)
	equipment_menu.add_item("Purge Generated")
	equipment_menu.set_item_metadata(equipment_menu.item_count-1,HumanizerEquipmentImportService.purge_generated)
	popup_menu.add_submenu_node_item('Equipment', equipment_menu)
	
	popup_menu.add_item("Targets")
	popup_menu.set_item_metadata(popup_menu.item_count-1,run_target_importer)
	
	var internal_menu = PopupMenu.new()
	internal_menu.add_item("Generate Basis")
	internal_menu.set_item_metadata(internal_menu.item_count-1,HumanizerBaseMeshReader.run)
	
	popup_menu.add_submenu_node_item('Internal', internal_menu)
	
	#preprocessing_popup.add_item('Set Up Skeleton Configs', menu_ids.rig_config)
	#
	
	popup_menu.add_item("Generate ZIP")
	popup_menu.set_item_metadata(popup_menu.item_count-1,generate_zip)
	add_tool_submenu_item('Humanizer Import', popup_menu)

	popup_menu.id_pressed.connect(handle_menu_event.bind(popup_menu))
	equipment_menu.id_pressed.connect(handle_menu_event.bind(equipment_menu))
	internal_menu.id_pressed.connect(handle_menu_event.bind(internal_menu))

func handle_menu_event(id:int,popup_menu:PopupMenu):
	if thread.is_alive():
		printerr('Thread busy...  Try again after current task completes')
		return
	if thread.is_started():
		thread.wait_to_finish()

	var callable : Callable = popup_menu.get_item_metadata(id)
	#callable.call()
	thread.start(callable)
	
func run_animation_importer():
	var popup = load("res://addons/humanizer_import/animation/menu_popup.tscn").instantiate()
	get_editor_interface().call_deferred("popup_dialog",popup)
	
func run_equipment_importer():
	var popup = load("res://addons/humanizer_import/equipment/menu_popup.tscn").instantiate()
	get_editor_interface().call_deferred("popup_dialog",popup)
	#get_editor_interface().popup_dialog(popup)
	
func run_target_importer():
	var popup = load("res://addons/humanizer_import/target/menu_popup.tscn").instantiate()
	get_editor_interface().call_deferred("popup_dialog",popup)


func generate_zip():
	var popup = load("res://addons/humanizer_import/pack/popup.tscn").instantiate()
	get_editor_interface().call_deferred("popup_dialog",popup)

#func _process_raw_data() -> void:
	#print_debug('Running all preprocessing')
	#for task in [
		#
		#_read_shapekeys,
		#_rig_config
	#]:
		#thread.start(task)
		#while thread.is_alive():
			#await get_tree().create_timer(1).timeout
		#thread.wait_to_finish()
	#
#func _read_shapekeys() -> void:
	#ShapeKeyReader.new().run()
	#
#func _rig_config() -> void:
	#HumanizerSkeletonConfig.new().run()
	
	#@export var equipment_slots: Array[HumanizerSlotCategory] = [
	#
	#HumanizerSlotCategory.new("Body Parts","", 
		#PackedStringArray( ['Body', 'RightEye', 'LeftEye', 'RightEyebrow', 'LeftEyebrow', 'RightEyelash', 'LeftEyelash', 'Hair', 'Tongue', 'Teeth',]), 
		#Array([, 
		#TYPE_OBJECT, "Resource", HumanizerFolderOverride)),
	#
	#HumanizerSlotCategory.new("Clothing","Clothes",
		#PackedStringArray(['Head','Eyes','Mouth','Hands','Arms','Torso','Legs','Feet',]), 
		#Array([HumanizerFolderOverride.new("hats",["Head"]),
			#HumanizerFolderOverride.new("shoes",["Feet"])], 
		#TYPE_OBJECT, "Resource", HumanizerFolderOverride)),
	#
#]
