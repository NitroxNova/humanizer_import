# Reads mh target files to collect and cache data for all shapekeys
class_name HumanizerTargetReader
extends RefCounted

# Process the shape key data.
static func run(input_folder:String):	#need to put this in a thread
	var data : Dictionary[String,PackedVector4Array] = {}
	print('Collecting data from target files - ' + input_folder)
	for file_path:String in OSPath.get_files_recursive(input_folder):
		if file_path.get_extension() == "target":
			var target_array = process_target(file_path)
			var target_name = file_path.get_file().trim_suffix(".target")
			if "/expression/units" in file_path: # face expressions res://data/input/target/System_Targets/expression/units/caucasian/eyebrows-right-down.target
				var race = file_path.get_base_dir().get_file() # append race to duplicate "expression" targets
				target_name = race + "-" + target_name
			if target_name in data:
				printerr("Duplicate target name " + target_name)
				continue
			data[target_name] = target_array
			print("Added Target " + target_name)
			
	var save_file_name = "res://humanizer/target/" + input_folder.get_file() + ".data"
	if not DirAccess.dir_exists_absolute(save_file_name.get_base_dir()):
		DirAccess.make_dir_absolute(save_file_name.get_base_dir())
	var save_file = FileAccess.open(save_file_name,FileAccess.WRITE)
	save_file.store_var(data)
	save_file.close()
	print("Done Generating Targets") 
			
static func process_target(file_path:String):
	var data : PackedVector4Array = []  #xyz position and index
	var target_file = FileAccess.open(file_path, FileAccess.READ)
	while target_file.get_position() < target_file.get_length():
		var line = target_file.get_line()
		#print(line)
		if line.begins_with('#'):
			continue
		var floats = line.split_floats(" ")
		var line_data = Vector4(floats[1]*.1,floats[2]*.1,floats[3]*.1,floats[0])
		data.append(line_data)
	return data
		
