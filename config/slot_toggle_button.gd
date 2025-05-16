@tool
extends Button

@export var linked_folders = []
signal slots_selected
@export var slot_name = ""
@export var categories = []

func _on_toggled(toggled_on: bool) -> void:
	if toggled_on:
		slots_selected.emit(self)

func set_slot_name(slot_text:String):
	slot_name = slot_text
	text = slot_name 
	
func clear_select():
	button_pressed = false
