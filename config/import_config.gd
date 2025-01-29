@tool
extends Resource
class_name HumanizerImportConfig

static func init_settings():
	if not ProjectSettings.has_setting("addons/humanizer_import/slot_folder_config"):
		var folders : Dictionary = {
			hair = {slots=["hair"]},
			body = {slots=["body"]},
			teeth = {slots=["teeth"]},
			tongue = {slots=["tongue"]},
			eyes = {slots=["lefteye","righteye"],left_right = true},
			eyebrows = {slots=["lefteyebrow","righteyebrow"],left_right = true},
			eyelashes = {slots=["lefteyelash","righteyelash"],left_right = true},
			shoes = {slots=["feetclothes"]},
			hats = {slots=["headclothes"]},
			}
		ProjectSettings.set_setting("addons/humanizer_import/slot_folder_config",folders)
		ProjectSettings.save()

static func get_folder_override_slots(mhclo_path:String):
	#print(mhclo_path)
	var slots = []
	var slot_folder_name = mhclo_path.split("/",false)[4] #res://data/input/equipment/ "folder_name" /mhclo_file
	var folder_config = ProjectSettings.get_setting("addons/humanizer_import/slot_folder_config")[slot_folder_name]
	
	if "left_right" in folder_config and folder_config.left_right:
		#print(mhclo_path.get_file())
		var has_side = false
		for side in ["left","right"]:
			if mhclo_path.get_file().begins_with(side):
				for slot in folder_config.slots:
					if slot.to_lower().begins_with(side) and slot not in slots:
						slots.append(slot)
				has_side = true
		if not has_side: # assign to both sides, so they can add single equipment with both eyelashes	
			for slot in folder_config.slots:
				if slot not in slots:
					slots.append(slot)
	else:
		for slot in folder_config.slots:
			if slot not in slots:
				slots.append(slot)
	return slots	
