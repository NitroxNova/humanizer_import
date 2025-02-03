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


func _on_input_folder_button_pressed() -> void:
	%InputFolderDialog.show()


func _on_input_folder_dialog_dir_selected(dir: String) -> void:
	%Input_Folder.text = dir
	%Output_File.text = "res://data/generated/target/" + dir.get_file() + ".res"
