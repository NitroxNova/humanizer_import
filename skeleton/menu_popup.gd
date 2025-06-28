@tool
extends Window

# can download rigs here - 
# http://www.makehumancommunity.org/rigs.html
#also from makehuman standalone, might be more there
# be sure to credit the authors! or try making your own ;)

var skeleton_folder = ""

func _on_close_requested() -> void:
	get_parent().remove_child(self)
	queue_free()


func _on_select_skeleton_button_pressed() -> void:
	%Skeleton_FileDialog.show()


func _on_skeleton_file_dialog_dir_selected(dir: String) -> void:
	%Skeleton_FileDialog.hide()
	#make sure theres only 2 files, because naming is ambiguous
	var contents = DirAccess.get_files_at(dir)
	if contents.size() > 2:
		%SkeletonName.text = "ERROR - More than 2 files in Folder"
		skeleton_folder = ""
		%ImportButton.disabled = true
	elif contents.size() < 2:
		%SkeletonName.text = "ERROR - Less than 2 files in Folder"
		skeleton_folder = ""
		%ImportButton.disabled = true
	elif contents.size() == 2:
		%SkeletonName.text = dir.get_file()
		skeleton_folder = dir
		%ImportButton.disabled = false


func _on_import_button_pressed() -> void:
	if skeleton_folder != "":
		run_import()
	
func run_import():
	print("importing skeleton")

	while %Skeleton.get_child_count() > 0:
		%Skeleton.remove_child(%Skeleton.get_child(0))
	
	var skel_reader = Skeleton_Reader.new(skeleton_folder)
	#need top level node and self didnt work?
	
	%Skeleton.add_child(skel_reader.skeleton)
	#have to add a mesh for gltf export, otherwise skeleton exports as node3Ds
	var mesh = MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	#mesh.hide()
	skel_reader.skeleton.add_child(mesh)
	HumanizerEditorUtils.set_node_owner( %Skeleton, self)
	
	# Save a new glTF scene.
	var gltf_path = "res://data/generated/skeleton/"
	if not DirAccess.dir_exists_absolute(gltf_path):
		DirAccess.make_dir_absolute(gltf_path)
	gltf_path += %SkeletonName.text + ".gltf"
	var gltf_document_save := GLTFDocument.new()
	var gltf_state_save := GLTFState.new()
	#need top level node for importer to work?
	gltf_document_save.append_from_scene(%Skeleton, gltf_state_save)
	# The file extension in the output `path` (`.gltf` or `.glb`) determines
	# whether the output uses text or binary format.
	# `GLTFDocument.generate_buffer()` is also available for saving to memory.
	gltf_document_save.write_to_filesystem(gltf_state_save, gltf_path)
	
	var ep = EditorPlugin.new()
	#register file in editor (otherwise you have to click out and back into godot)
	ep.get_editor_interface().get_resource_filesystem().update_file(gltf_path)
	#generate .import settings
	ep.get_editor_interface().get_resource_filesystem().reimport_files(PackedStringArray([gltf_path]))
	#return
	var import_file_path: String = gltf_path + ".import"
	var config := ConfigFile.new()
	var err := config.load(import_file_path)
	if err == OK:
		var subresources: Dictionary = config.get_value("params", "_subresources", {})
		if "nodes" not in subresources:
			subresources["nodes"] = {}
		if "PATH:Skeleton3D" not in subresources["nodes"]:
			subresources["nodes"]["PATH:Skeleton3D"] = {}

		# Update the specific settings for Skeleton3D
		var bone_map = BoneMap.new()
		bone_map.profile = SkeletonProfileHumanoid.new()
		for map_name in skel_reader.retarget_names:
			var bone_id = skel_reader.retarget_names[map_name]
			if map_name not in skel_reader.retarget_names:
				print(map_name)
			var bone_name = skel_reader.skeleton.get_bone_name(bone_id)
			bone_map.set_skeleton_bone_name(map_name,bone_name)
		subresources["nodes"]["PATH:Skeleton3D"]["retarget/bone_map"] = bone_map
		#subresources["nodes"]["retarget/rest_fixer/apply_node_transforms"] = false
		#subresources["nodes"]["retarget/rest_fixer/retarget_method"] = 0
		# Save the updated subresources back to the config
		config.set_value("params", "_subresources", subresources)
		
		# Save the changes to the .import file
		err = config.save(import_file_path)
		if err == OK:
			print("Import settings updated successfully for ", gltf_path)
			# Trigger reimport immediately after saving
			#_trigger_reimport(gltf_path)
			ep.get_editor_interface().get_resource_filesystem().reimport_files(PackedStringArray([gltf_path]))
			generate_skeleton_resource_from_gltf(gltf_path,skel_reader)
		else:
			print("Failed to save import settings for ", gltf_path)
	else:
		print("Failed to load import file for editing: ", gltf_path)

func generate_skeleton_resource_from_gltf(gltf_path,skel_reader : Skeleton_Reader):
	var rt_gltf = load(gltf_path).instantiate()
	var rt_res = HumanizerRig.new()
	rt_res.retargeted = true
	var rt_res_path = "res://humanizer/skeleton/"
	rt_res_path += gltf_path.get_file().get_basename()+"-RETARGETED.res"
	var rt_skel3d:Skeleton3D = rt_gltf.get_child(0)
	
	var original_skeleton : Skeleton3D = skel_reader.skeleton
	
	var retarget_index = []
	retarget_index.resize(original_skeleton.get_bone_count())
	for rt_bone_name in skel_reader.retarget_names:
		var orig_bone_id = skel_reader.retarget_names[rt_bone_name]
		if not orig_bone_id in [-1,null]:
			var rt_bone_id = rt_skel3d.find_bone(rt_bone_name)
			retarget_index[orig_bone_id] = rt_bone_id
	for orig_bone_id in retarget_index.size():
		var rt_bone_id = retarget_index[orig_bone_id]
		if rt_bone_id in [-1,null]:
			var orig_bone_name = original_skeleton.get_bone_name(orig_bone_id)
			rt_bone_id = rt_skel3d.find_bone(orig_bone_name)
			retarget_index[orig_bone_id] = rt_bone_id
			
	rt_res.weights =  skel_reader.rig.weights.duplicate(true)
	for v_id in rt_res.weights.size():
		for bw_id in rt_res.weights[v_id].size():
			var rt_v_id = retarget_index[rt_res.weights[v_id][bw_id][0]]
			rt_res.weights[v_id][bw_id][0] = rt_v_id
	rt_res.config = []
	rt_res.config.resize(retarget_index.size())
	for orig_bone_id in skel_reader.rig.config.size():
		var bone_config = skel_reader.rig.config[orig_bone_id].duplicate(true)
		var rt_bone_id = retarget_index[orig_bone_id]
		if bone_config.parent != -1:
			var rt_parent_id = retarget_index[bone_config.parent]
			bone_config.parent = rt_parent_id
		rt_res.config[rt_bone_id] = bone_config
	var packed_skeleton = PackedScene.new()
	#skeleton.owner = skeleton
	packed_skeleton.pack(rt_skel3d)
	rt_res.skeleton = packed_skeleton
	ResourceSaver.save(rt_res,rt_res_path)
