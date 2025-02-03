extends RefCounted
class_name HumanizerBaseMeshReader


static func run():
	var obj_to_mesh = ObjToMesh.new("res://addons/humanizer_import/helpers/base.obj")
	obj_to_mesh.process_obj()
	var basis:PackedVector3Array = PackedVector3Array( obj_to_mesh.obj_arrays.vertex)
	for idx in basis.size():
		basis[idx] *= .1
	var save_file = FileAccess.open("res://data/generated/basis.data",FileAccess.WRITE)
	save_file.store_var(basis)
	save_file.close()
