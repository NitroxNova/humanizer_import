extends RefCounted
class_name HumanizerBaseMeshReader


static func run():
	var obj_to_mesh = ObjToMesh.new("res://addons/humanizer_import/helpers/base.obj")
	obj_to_mesh.process_obj()
	var basis:PackedVector3Array = PackedVector3Array( obj_to_mesh.obj_arrays.vertex)
	for idx in basis.size():
		basis[idx] *= .1
	var foot_offset = HumanizerBodyService.get_foot_offset(basis)
	for idx in basis.size():
		basis[idx].y -= foot_offset
		
	var save_file_name = "res://data/generated/basis.data"
	if not DirAccess.dir_exists_absolute(save_file_name.get_base_dir()):
		DirAccess.make_dir_absolute(save_file_name.get_base_dir())
	var save_file = FileAccess.open(save_file_name,FileAccess.WRITE)
	save_file.store_var(basis)
	save_file.close()
