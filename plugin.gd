@tool
extends EditorPlugin

# Thread for background tasks
var thread := Thread.new()

func _enter_tree():
	_add_tool_submenu()

func _exit_tree():
	remove_tool_menu_item('Humanizer Import')	
	if thread.is_started():
		thread.wait_to_finish()
	
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
	equipment_menu.add_item("Purge Generated")
	equipment_menu.set_item_metadata(equipment_menu.item_count-1,HumanizerEquipmentImportService.purge_generated)
	popup_menu.add_child(equipment_menu)
	popup_menu.add_submenu_item('Equipment', 'equipment')
	
	#preprocessing_popup.add_item('Read ShapeKey files', menu_ids.read_shapekeys)
	#preprocessing_popup.add_item('Set Up Skeleton Configs', menu_ids.rig_config)
	#
	
	popup_menu.add_item("Generate ZIP")
	popup_menu.set_item_metadata(popup_menu.item_count-1,generate_zip)
	add_tool_submenu_item('Humanizer Import', popup_menu)

	popup_menu.id_pressed.connect(handle_menu_event.bind(popup_menu))
	equipment_menu.id_pressed.connect(handle_menu_event.bind(equipment_menu))

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
		#Array([HumanizerFolderOverride.new("hair", ["Hair"]), 
			#HumanizerFolderOverride.new("body", ["Body"]),
			#HumanizerFolderOverride.new("teeth", ["Teeth"]),
			#HumanizerFolderOverride.new("tongue", ["Tongue"]),
			#HumanizerFolderOverride.new("eyes",["LeftEye","RightEye"], true), 
			#HumanizerFolderOverride.new("eyebrows",["LeftEyebrow","RightEyebrow"], true), 
			#HumanizerFolderOverride.new("eyelashes",["LeftEyelash","RightEyelash"], true)], 
		#TYPE_OBJECT, "Resource", HumanizerFolderOverride)),
	#
	#HumanizerSlotCategory.new("Clothing","Clothes",
		#PackedStringArray(['Head','Eyes','Mouth','Hands','Arms','Torso','Legs','Feet',]), 
		#Array([HumanizerFolderOverride.new("hats",["Head"]),
			#HumanizerFolderOverride.new("shoes",["Feet"])], 
		#TYPE_OBJECT, "Resource", HumanizerFolderOverride)),
	#
#]

#func get_folder_override_slots(mhclo_path:String):
	##print(mhclo_path)
	#var folder_path = mhclo_path
	#for import_path in asset_import_paths:
		#import_path = import_path.path_join("equipment")
		#if folder_path.begins_with(import_path):
			#folder_path = folder_path.replace(import_path,"")
			#continue
	#folder_path = folder_path.get_base_dir().path_join("") #add a slash on the end, so it can be searched for multi level folder names
	#folder_path = folder_path.to_lower()
	#mhclo_path = mhclo_path.to_lower()
	##print(mhclo_path)
	#var slots = []
	#for slot_cat in equipment_slots:
		#for folder_ovr in slot_cat.folder_overrides:
			#var fn = "/".path_join(folder_ovr.folder_name.to_lower()).path_join("") #slashes on both sides to eliminate false positives (in case one name is partially in another)
			#if fn in mhclo_path:
				#if folder_ovr.left_right:
					##print(mhclo_path.get_file())
					#var has_side
					#for side in ["left","right"]:
						#if mhclo_path.get_file().begins_with(side):
							#for slot in folder_ovr.slots:
								#slot += slot_cat.suffix
								#if slot.to_lower().begins_with(side) and slot not in slots:
									#slots.append(slot)
							#has_side = true
					#if not has_side: # assign to both sides, so they can add single equipment with both eyelashes	
						#for slot in folder_ovr.slots:
							#slot += slot_cat.suffix
							#if slot not in slots:
								#slots.append(slot)
				#else:
					#for slot in folder_ovr.slots:
						#slot += slot_cat.suffix
						#if slot not in slots:
							#slots.append(slot)
	#return slots	
