@tool
extends Window
@export var slots_vbox:VBoxContainer
@export var folders_vbox:VBoxContainer
@export var folder_name_entry:LineEdit
@export var slot_name_entry: LineEdit
@export var slots_toggle_button:PackedScene
@export var folder_area:PackedScene
var selected = null 
var slots_menu = {}
var selected_folders 

func _on_about_to_popup():
	var folders = ProjectSettings.get_setting("addons/humanizer_import/slot_folder_config")
	for folder in folders.keys():
		for slot in folders[folder]["slots"]:
			var folder_button_set = folder_area.instantiate()
			folder_button_set.set_folder(folder)
			folder_button_set.folder_selected.connect(folder_selected)
			if "left_right" in folders[folder].keys():
				if folders[folder]["left_right"]:
					folder_button_set.set_left_right()
			if slot in slots_menu.keys():
				slots_menu[slot].linked_folders.append(folder_button_set)
			else:
				slots_menu[slot] = slots_toggle_button.instantiate()
				slots_menu[slot].linked_folders.append(folder_button_set)
				slots_menu[slot].set_slot_name(slot)
				slots_menu[slot].slots_selected.connect(slot_selected)
	for slot in slots_menu.keys():
		slots_vbox.add_child(slots_menu[slot])

func folder_selected(selected, folder):
	if  selected:
		selected_folders.append(folder)
	else:
		selected_folders.erase(folder)

func slot_selected(slot):
	setup_slot(slot)
	selected = slot.slot_name
	for slot_key in slots_menu.keys():
		if slots_menu[slot_key]!=slot:
			slots_menu[slot_key].clear_select()

func setup_slot(slot_buttton):
	for child in folders_vbox.get_children():
		child.clear_select()
		folders_vbox.remove_child(child)
	for folder in slot_buttton.linked_folders:
		folders_vbox.add_child(folder)
	selected_folders=[]

func _on_save_pressed() -> void:
	var slot_folder_config = {}
	for slot in slots_menu.keys():
		for folder in slots_menu[slot].linked_folders:
			var folder_name = folder.folder_name
			if folder_name in slot_folder_config.keys():
				slot_folder_config[folder_name]["slots"].append(slots_menu[slot].slot_name)
			else:
				slot_folder_config[folder_name] = {}
				slot_folder_config[folder_name]["slots"] = [slots_menu[slot].slot_name]
			if folder.left_right:
				slot_folder_config[folder_name]["left_right"] = folder.left_right
	ProjectSettings.set_setting("addons/humanizer_import/slot_folder_config",slot_folder_config)
	print("Project Settings Saved")


func _on_add_slot_pressed() -> void:
	var input_name = slot_name_entry.text
	if len(input_name)>0:
		if not(input_name in slots_menu.keys()):
			slots_menu[input_name] = slots_toggle_button.instantiate()
			slots_menu[input_name].set_slot_name(input_name)
			slots_vbox.add_child(slots_menu[input_name])
			slots_menu[input_name].slots_selected.connect(slot_selected)
		else:
			print("slot name rejected, already exists")
	else:
		print("slot name rejected, empty string")

func _on_remove_slot_pressed() -> void:
	if selected:
		slots_menu[selected].queue_free()
		slots_menu.erase(selected)
		selected = null
		for child in folders_vbox.get_children():
			child.queue_free()
	else:
		print("No slot selected.")


func _on_add_folder_pressed() -> void:
	var input_name = folder_name_entry.text
	if len(input_name)>0:
		if selected:
			var folder_exists=false
			for folder in slots_menu[selected].linked_folders:
				folder_exists = folder_exists or folder.folder_name == input_name
			if folder_exists:
				print("Folder already attached")
			else:
				var folder_button_set = folder_area.instantiate()
				folder_button_set.set_folder(input_name)
				slots_menu[selected].linked_folders.append(folder_button_set)
				folder_button_set.folder_selected.connect(folder_selected)
				slot_selected(slots_menu[selected])
	else:
		print("Folder name Rejected, Length 0")

func _on_remove_folder_pressed() -> void:
	if selected:
		for folder in selected_folders:
			slots_menu[selected].linked_folders.erase(folder)
			folder.queue_free()
		selected_folders=[]
	else:
		print("No Slot Selected")
		
func _on_close_requested() -> void:
	get_parent().remove_child(self)
	queue_free()
