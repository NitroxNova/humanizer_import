@tool
extends Window


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_close_requested() -> void:
	get_parent().remove_child(self)
	queue_free()

func _on_run_pressed() -> void:
	var anim_import := Animation_Importer.new()
	anim_import.input_folder = get_node("%Input_Folder").text
	anim_import.output_folder = get_node("%Output_Folder").text
	anim_import.add_root = get_node("%Root_Bone").button_pressed
	anim_import.output_name = get_node("%Library_Name").text
	anim_import.run()


func _on_input_dir_selected(dir: String) -> void:
	%Input_Folder.text = dir
	%Library_Name.text = dir.get_file()
