extends Window
@export var itemSelect:OptionButton
@export var parentSelect:OptionButton
@export var newCatName: TextEdit
@export var linkArea:VBoxContainer
@export var linkButton:PackedScene
@export var demoArea: TabContainer

var relationships = {}
const default_parent = null
var selected_links = []
const tab = "  "

func _ready():
	relationships["Root"]={"parent":default_parent,"child":[]}
	parentSelect.add_item("Root")
	var slot_folders = ProjectSettings.get_setting("addons/humanizer_import/slot_folder_config")
	for slot in slot_folders.keys():
		itemSelect.add_item(slot)


func _on_link_button_pressed() -> void:
	var parent = parentSelect.get_item_text(parentSelect.selected)
	var child = itemSelect.get_item_text(itemSelect.selected)
	if parent == child:
		return
	itemSelect.remove_item(itemSelect.selected)
	itemSelect.select(-1)
	if parent in relationships.keys():
		relationships[parent]["child"].append(child)
	else:
		relationships[parent]={"child":[child],"parent":default_parent, "linkButton":null}
	if child in relationships.keys():
		relationships[child]["parent"] = parent
		relationships[child]["linkButton"] = make_link(parent,child)
	else:
		relationships[child]={"child":[],"parent":parent,"linkButton":make_link(parent,child)}
	update_example()

func make_link(parent,child):
	var object = linkButton.instantiate()
	object.text = parent + " / "+child
	object.parent = parent
	object.child = child
	linkArea.add_child(object)
	object.connect("export_selected",_on_link_button_toggled)
	return object


func _on_remove_category_pressed() -> void:
	var category = parentSelect.get_item_text(parentSelect.selected)
	if category == "Root":
		return
	if category in relationships:
		for child in relationships[category]["child"]:
			relationships[child]["parent"]=default_parent
			itemSelect.add_item(child)
			if relationships[child]["linkButton"]:
				relationships[child]["linkButton"].queue_free()
	relationships.erase(category)
	parentSelect.remove_item(parentSelect.selected)
	for idx in range(itemSelect.item_count):
		if itemSelect.get_item_text(idx) == category:
			itemSelect.remove_item(idx)
			break


func _on_link_button_toggled(state:bool,button) ->void:
	if state:
		selected_links.append(button)
	else:
		selected_links.erase(button)

func _on_create_category_pressed() -> void:
	var category_name = newCatName.text
	newCatName.text = ""
	for idx in range(parentSelect.item_count):
		if category_name == parentSelect.get_item_text(idx):
			return
	parentSelect.add_item(category_name)
	itemSelect.add_item(category_name)


func _on_remove_link_pressed() -> void:
	for link in selected_links:
		var child = link.child
		var parent = link.parent
		relationships[parent]["child"].erase(child)
		itemSelect.add_item(child)
		relationships[child]["linkButton"].queue_free()
		relationships[child]["parent"]=default_parent
	selected_links=[]
	update_example()


func _on_export_pressed() -> void:
	pass # Replace with function body.

func make_child_tabs(parent:VBoxContainer,item:String,prefix:String):
	var parent_label = Label.new()
	parent.add_child(parent_label)
	parent_label.text = prefix + item
	for child in relationships[item]["child"]:
		make_child_tabs(parent,child,prefix+tab)

func update_example():
	for categories in demoArea.get_children():
		if categories.name in relationships["Root"]["child"]:
			for label in categories.get_children():
				label.queue_free()
		else:
			categories.queue_free()
	for parent in relationships["Root"]["child"]:
		
		var category = null
		for child in demoArea.get_children():
			if child.name == parent:
				category=child
				break
		print(category)
		if category:
			for child in relationships[parent]["child"]:
				make_child_tabs(category,child,"")
		else:
			category = VBoxContainer.new()
			category.name=parent
			demoArea.add_child(category)
			for child in relationships[parent]["child"]:
				make_child_tabs(category,child,"")
