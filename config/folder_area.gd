@tool
extends HBoxContainer
var selected = false
var left_right = false
signal folder_selected
signal left_right_toggled
@export var folder_name = ""
@export var select_button:Button
@export var left_right_check:CheckBox

func set_folder(name_string:String):
	select_button.text = name_string
	folder_name = name_string
	
func set_left_right():
	left_right_check.button_pressed = true
	left_right = true

func clear_select():
	select_button.button_pressed = false


func _on_button_toggled(toggled_on: bool) -> void:
	selected = toggled_on
	folder_selected.emit(toggled_on,self)



func _on_check_box_toggled(toggled_on: bool) -> void:
	left_right = toggled_on
	left_right_toggled.emit(toggled_on,self)
