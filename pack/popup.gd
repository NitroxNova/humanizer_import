@tool
extends Window


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	fill_pack_names()
	fill_contents_tree([])

func fill_pack_names():
	%SelectPack.clear()
	%SelectPack.add_item(" -- New Pack -- ")
	%SelectPack.set_item_metadata(0,"")
	var pack_path = "res://data/pack"
	for pack_file in DirAccess.get_files_at(pack_path):
		%SelectPack.add_item(pack_file.get_basename())
		%SelectPack.set_item_metadata(%SelectPack.item_count-1,pack_path.path_join(pack_file))
	
func fill_contents_tree(selected:Array):
	var tree = %Contents_Tree
	tree.clear()
	tree.columns = 1
	var root = tree.create_item()
	tree.hide_root = true
	var equip_tree = tree.create_item(root)
	equip_tree.set_text(0,"Equipment / Materials")
	for equip_id in HumanizerEquipmentImportService.get_generated_equipment_ids():
		var equip:TreeItem = tree.create_item(equip_tree)
		equip.set_cell_mode(0,TreeItem.CELL_MODE_CHECK)
		equip.set_editable(0,true)
		equip.set_text(0,equip_id)
		var meta = "res://data/generated/equipment/" + equip_id + "/" + equip_id + ".res" 
		equip.set_metadata(0,meta)
		if meta in selected:
			equip.set_checked(0,true)
		var files = []
		var mat_path = "res://data/generated/material/" + equip_id
		if DirAccess.dir_exists_absolute(mat_path):
			files.append_array(OSPath.get_files_recursive(mat_path))
		mat_path = "res://data/input/material/" + equip_id
		if DirAccess.dir_exists_absolute(mat_path):
			files.append_array(OSPath.get_files_recursive(mat_path))
		for mat_file in files:
			if mat_file.get_extension() == "res":
				var resource = load(mat_file)
				#exclude compressed image resources
				if resource is StandardMaterial3D or resource is HumanizerMaterial or resource is HumanizerOverlay:
					var mat_id = mat_file.get_file().get_basename()
					var mat:TreeItem = tree.create_item(equip)
					mat.set_cell_mode(0,TreeItem.CELL_MODE_CHECK)
					mat.set_editable(0,true)
					mat.set_text(0,mat_id)
					var mat_meta = mat_file
					mat.set_metadata(0,mat_meta)
					if mat_meta in selected:
						mat.set_checked(0,true)
			
	var anim_tree = tree.create_item(root)
	anim_tree.set_text(0,"Animations")

func _on_close_requested() -> void:
	get_parent().remove_child(self)
	queue_free()

func _on_generate_pressed() -> void:
	if %Pack_Name.text == "":
		printerr("Pack Name cannot be blank")
		return
	if not %Pack_Name.text.is_valid_filename():
		printerr(%Pack_Name.text + " is not a valid file name")
		return
	var selected = []
	var curr_item : TreeItem =  %Contents_Tree.get_root()
	while curr_item.get_next_in_tree() != null:
		curr_item = curr_item.get_next_in_tree()
		if curr_item.is_checked(0):
			selected.append(curr_item.get_metadata(0))
	if not DirAccess.dir_exists_absolute("res://data/pack/"):
		DirAccess.make_dir_recursive_absolute("res://data/pack")
	var save_file = "res://data/pack/".path_join(%Pack_Name.text) + ".json"
	OSPath.save_json(save_file,selected)
	HumanizerZipService.generate_zip(%Pack_Name.text)


func _on_select_pack_item_selected(index: int) -> void:
	var json_path = %SelectPack.get_item_metadata(index)
	if json_path == "":
		%Pack_Name.text = ""
		fill_contents_tree([])
		return
	%Pack_Name.text = %SelectPack.get_item_text(index)
	var pack_settings = OSPath.read_json(json_path)
	fill_contents_tree(pack_settings)
