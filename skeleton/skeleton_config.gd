class_name HumanizerSkeletonConfig
extends RefCounted

func run():
	print('Creating Skeleton Config')
	# Prepare data structures
	var vertex_groups = HumanizerResourceService.load_resource("res://addons/humanizer/data/resources/basemesh_vertex_groups.json")
	
	for path in ProjectSettings.get_setting_with_override("addons/humanizer/asset_import_paths") :
		for name in HumanizerRegistry.rigs:
			print('Importing rig ' + name)
			var rig: HumanizerRig = HumanizerRegistry.rigs[name]
			if rig.skeleton_path in [null, '']:
				printerr('Missing scene for skeleton')
				return
			if rig.rigged_mesh_path in [null, '']:
				printerr('You must extract the rigged mesh instance to a .res file')
				return
			var in_data: Dictionary
			var skeleton: Skeleton3D = null
			var dir: String = rig.mh_json_path.get_base_dir()
			in_data = HumanizerResourceService.load_resource(rig.mh_json_path)
			if in_data.has('bones'):  # Game Engine rig doesn't have bones key
				in_data = in_data['bones']
			skeleton = HumanizerResourceService.load_resource(rig.skeleton_path).instantiate()
			
			if in_data.size() == 0:
				printerr('Failed to load skeleton json from makehuman')
				return
			
			
			
			print('Finished creating skeleton config')
	
