@tool
extends Button
@export var parent:String
@export var child:String
signal export_selected


func _on_toggled(toggled_on: bool) -> void:
	export_selected.emit(toggled_on,self)
