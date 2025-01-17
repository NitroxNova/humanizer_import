@tool
extends Window

var slot_boxes = {}
var import_settings := {}

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	init_options()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_close_requested() -> void:
	get_parent().remove_child(self)
	queue_free()

func init_options():
	slot_boxes = {}
	for slots_cat:HumanizerSlotCategory in HumanizerGlobalConfig.config.equipment_slots:
		var label = Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.text = "--- " + slots_cat.category + " ---"
		%SlotsContainer.add_child(label)
		var container = HFlowContainer.new()
		for slot in slots_cat.slots:
			var checkbox = CheckBox.new()
			checkbox.text = slot
			container.add_child(checkbox)
			slot_boxes[slot+slots_cat.suffix] = checkbox
		%SlotsContainer.add_child(container)
	
	if not %MHCLO_FileLoader.file_selected.is_connected(fill_options):
		%MHCLO_FileLoader.file_selected.connect(fill_options)
	%MHCLO_FileLoader.current_dir = HumanizerGlobalConfig.config.asset_import_paths[-1].path_join("equipment")
	
	%SkeletonOptions.clear()
	%SkeletonOptions.add_item(" -- Select Skeleton --")
	var rigs = HumanizerRegistry.rigs
	for rig in rigs:
		if rigs[rig].skeleton_retargeted_path != '':
			%SkeletonOptions.add_item(rig + '-RETARGETED')
		if rigs[rig].skeleton_path != '':
			%SkeletonOptions.add_item(rig)
	%SkeletonOptions.item_selected.connect(fill_bone_options)		
	#fill_options()
	
	%MHCLO_Button.pressed.connect(%MHCLO_FileLoader.show)
	%GLB_Button.pressed.connect(%LoadRiggedGLB.show)
	%AddBoneButton.pressed.connect(_add_bone_pressed)
	%ImportButton.pressed.connect(import_asset)

func _add_bone_pressed():
	var selected = %BoneOptions.get_selected()
	add_attach_bone(%BoneOptions.get_item_text(selected))

func add_attach_bone(text):
	var hbox = HBoxContainer.new()
	var label = Label.new()
	label.name = "Label"
	label.text = text
	hbox.add_child(label)
	var button = Button.new()
	button.text = " Remove "
	button.size_flags_horizontal = Control.SIZE_SHRINK_END + Control.SIZE_EXPAND
	button.pressed.connect(_remove_bone_pressed.bind(hbox))
	hbox.add_child(button)
	%BoneList.add_child(hbox)

func _remove_bone_pressed(node:Control):
	%BoneList.remove_child(node)

func fill_bone_options(idx:int):
	%BoneOptions.clear()
	if idx == 0: #  -- select skeleton -- 
		return
		
	var rig_name = %SkeletonOptions.get_item_text(idx)
	var retargeted: bool = rig_name.ends_with('-RETARGETED')
	var rig = HumanizerRigService.get_rig(rig_name)
	var skeleton_data = HumanizerRigService.init_skeleton_data(rig,retargeted)
	for bone_name in skeleton_data:
		%BoneOptions.add_item(bone_name)

func fill_material_options():
	var options :OptionButton = %DefaultMaterial
	options.clear()
	options.add_item(" -- None (Random) --")
	options.set_item_metadata(0,"")
	var mat_list = HumanizerMaterialImportService.search_for_materials(get_mhclo_path())
	mat_list = mat_list.materials
	#print(mat_list)
	for mat_id in mat_list:
		#var mat_res = HumanizerResourceService.load_resource(mat_list[mat_id])
		var mat_name = mat_id # because materials wont have been loaded yet
		var idx = options.item_count
		options.add_item(mat_name)
		options.set_item_metadata(idx,mat_id)
	
	for idx in options.get_item_count():
		var mat_id = options.get_item_metadata(idx)
		if mat_id == import_settings.default_material:
			options.selected = idx

func fill_material_override_options():
	var options: OptionButton = %MaterialOverride
	options.clear()
	options.add_item("")
	var file_list = OSPath.get_files_recursive("res://data/input/equipment")
	for file_name in file_list:
		if file_name.get_extension() == "mhclo":
			var equip_id = file_name.get_file().get_basename()
			options.add_item(equip_id)
			if import_settings.material_override == equip_id:
				options.selected = options.item_count - 1
		
func fill_options(mhclo_path:String=""):
	#print("fill options")
	%MHCLO_Label.text = mhclo_path
	for box in slot_boxes.values():
		box.button_pressed = false
	
	for child in %BoneList.get_children():
		child.get_parent().remove_child(child)
		child.queue_free()
	%GLB_Label.text = ""
	%LoadRiggedGLB.current_dir = mhclo_path.get_base_dir()
	import_settings = HumanizerEquipmentImportService.load_import_settings(mhclo_path)
	fill_material_options()
	fill_material_override_options()
	var folder_override = HumanizerGlobalConfig.config.get_folder_override_slots(mhclo_path)
	
	if folder_override.is_empty():
		%SlotsDisabledLabel.hide()
		for slot in import_settings.slots:
			slot_boxes[slot].button_pressed = true 
		for slot in slot_boxes:	
			slot_boxes[slot].disabled = false
	else:
		%SlotsDisabledLabel.show()
		for slot in folder_override:
			slot_boxes[slot].button_pressed = true 
		for slot in slot_boxes:	
			slot_boxes[slot].disabled = true
	%DisplayName.text = import_settings.display_name
	%GLB_Label.text = import_settings.rigged_glb
	for bone in import_settings.attach_bones:
		add_attach_bone(bone)
	%DisplayName.text = import_settings.display_name
	if %GLB_Label.text == "":
		%GLB_Label.text = HumanizerEquipmentImportService.search_for_rigged_glb(mhclo_path)	
		
func get_mhclo_path():
	return %MHCLO_Label.text

func import_asset():
	#print("importing asset")
	var slot_list = []
	for slot_name in slot_boxes:
		if slot_boxes[slot_name].button_pressed:
			slot_list.append(slot_name)
	import_settings.slots = slot_list
	import_settings.mhclo = %MHCLO_Label.text 
	import_settings.display_name = %DisplayName.text 
	var string_id = import_settings.mhclo.get_basename().get_file()
	if import_settings.display_name.strip_edges() == "":
		printerr("No display name set, using string ID " + string_id) 
	var select_material = %DefaultMaterial.selected
	import_settings.default_material = %DefaultMaterial.get_item_metadata(select_material)
	import_settings.rigged_glb = %GLB_Label.text
	import_settings.attach_bones = []
	for hbox in %BoneList.get_children():
		var label = hbox.get_node("Label")
		import_settings.attach_bones.append(label.text)
	#var save_file = HumanizerEquipmentImportService.get_import_settings_path(get_mhclo_path())
	
	var save_path:String = HumanizerEquipmentImportService.get_import_settings_path(get_mhclo_path().get_file().get_basename())
	if not DirAccess.dir_exists_absolute(save_path.get_base_dir()):
		DirAccess.make_dir_absolute(save_path.get_base_dir())
	HumanizerResourceService.save_resource(save_path,import_settings)
	HumanizerEquipmentImportService.import(save_path)
	#HumanizerRegistry.load_all()
