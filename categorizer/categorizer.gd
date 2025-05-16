@tool
extends Window
@export var itemSelect:OptionButton
@export var parentSelect:OptionButton
@export var newCatName: LineEdit
@export var linkArea:VBoxContainer
@export var linkButton:PackedScene
@export var demoArea: TabContainer

var relationships = {}
const default_parent = null
var selected_links = []
const tab = "  "
const root = "Root"

func _ready():
	init_options()

func init_options():
	#add Root this aways has to be availible
	parentSelect.add_item(root)
	#create a look up, when loading it  isnt possible to know if something is a slot or an empty category
	var potential_categories = []
	#load the previous save
	var dir = DirAccess.open("res://data/generated/")
	if dir.dir_exists("res://data/generated/menus"):
		if dir.file_exists("res://data/generated/menus/menu.json"):
			var save_file = FileAccess.open("res://data/generated/menus/menu.json",FileAccess.READ)
			var json = JSON.new()
			relationships = json.parse_string(save_file.get_line())
			#get all of the previously saved relationships
			for key in relationships.keys():
				#if it has a parent, create a link. All relationships should have a child in the directory and the child will have the parent
				if relationships[key]["parent"]==default_parent:
					#if there is no parent, this can be an item unless it is Root
					if key != root:
						itemSelect.add_item(key)
				else:
					#if it has a parent, it should not be an addable a item and needs to have an unlink buttong made
					relationships[key]["linkButton"] = make_link(relationships[key]["parent"],key)
				if len(relationships[key]["child"])>0 and key!= root:
					#if it has children it is a category.
					parentSelect.add_item(key)
				else:
					#hang on to the item. it could be a category or a slot. slots dont get added to be parrents
					potential_categories.append(key)
	else:
		#setup default
		relationships[root]={"parent":default_parent,"child":[]}
	#get all the slots to loop through
	var slot_folders = ProjectSettings.get_setting("addons/humanizer_import/slot_folder_config")
	for slot in slot_folders.keys():
		#if the slot is not in a relationship, it needs to be managed in the item selector
		if not(slot in relationships.keys()):
			itemSelect.add_item(slot)
			
		elif relationships[slot]["parent"] == default_parent:
			#if this isnt a new slot, it may have an empty relationship. in that case it needs to be added to itemSelect
			itemSelect.add_item(slot)
		#attempt to erase this if it is in the "potential categories"
		potential_categories.erase(slot)
	#now that all of the slots are loaded we know the remaining categories are actually orphaned categories.
	for category in potential_categories:
		parentSelect.add_item(category)
	update_example()


func _on_link_button_pressed() -> void:
	#links a parent to a child. adds menus and setups storage for later
	var parent = parentSelect.get_item_text(parentSelect.selected)
	var child = itemSelect.get_item_text(itemSelect.selected)
	#if you try and link a parent to itself we just escape. this has no meaning
	if parent == child:
		return
	#pop the item from the item select list. this tool assumes children can only have 1 parent. this prevents infinite loops
	itemSelect.remove_item(itemSelect.selected)
	itemSelect.select(-1)
	#build the partent child relationship
	if parent in relationships.keys():
		relationships[parent]["child"].append(child)
	else:
		relationships[parent]={"child":[child],"parent":default_parent, "linkButton":null}
	if child in relationships.keys():
		relationships[child]["parent"] = parent
		relationships[child]["linkButton"] = make_link(parent,child)
	else:
		relationships[child]={"child":[],"parent":parent,"linkButton":make_link(parent,child)}
	#update the example menus to reflect the change.
	update_example()

func make_link(parent,child):
	#Making a linked button. This is simply a button with extra properties to hold the parent/child keys
	var object = linkButton.instantiate()
	#test is just parent/child to make it easy to recognise 
	object.text = parent + " / " +child
	#these are the custom properties to make breaking relationships easy
	object.parent = parent
	object.child = child
	linkArea.add_child(object)
	#This is a custom function that will call back with the button itself and the state of toggling
	object.connect("export_selected",_on_link_button_toggled)
	#returns the object so it is easy to find the button as needed.
	return object


func _on_remove_category_pressed() -> void:
	#this function allows for the deletion of dummy categories. It will not allow for the deletion of root
	var category = parentSelect.get_item_text(parentSelect.selected)
	if category == root:
		return
	#if this was previously used, all relationships must be broken and buttons freed.
	if category in relationships:
		for child in relationships[category]["child"]:
			relationships[child]["parent"]=default_parent
			itemSelect.add_item(child)
			#removes the button if it was selected to prevent errors.
			selected_links.erase(relationships[child]["linkButton"])
			if relationships[child]["linkButton"]:
				relationships[child]["linkButton"].queue_free()
	relationships.erase(category)
	parentSelect.remove_item(parentSelect.selected)
	#remove the category from the itemselect list if possible
	for idx in range(itemSelect.item_count):
		if itemSelect.get_item_text(idx) == category:
			itemSelect.remove_item(idx)
			break


func _on_link_button_toggled(state:bool,button) ->void:
	#this is a call back used by the button to set the toggle state.
	if state:
		#the whole object is added to the list... this allows for keeping relationships and the items to queue free
		selected_links.append(button)
	else:
		selected_links.erase(button)

func _on_create_category_pressed() -> void:
	#creates a dummy category to use sort of as a "folder" this is purely for dyanmic structures
	var category_name = newCatName.text
	newCatName.text = ""
	#looping to disallow duplicate items. this would break dictionaries and json.
	for idx in range(parentSelect.item_count):
		if category_name == parentSelect.get_item_text(idx):
			return
	#add it to both the parent and items list to allow for full relationship building
	parentSelect.add_item(category_name)
	itemSelect.add_item(category_name)


func _on_remove_link_pressed() -> void:
	#grab all of the selected links
	for link in selected_links:
		var child = link.child
		var parent = link.parent
		#erase the child from the parent relationship
		relationships[parent]["child"].erase(child)
		#Add back the child to the drop down
		itemSelect.add_item(child)
		#delete the button for selecting the relationship
		relationships[child]["linkButton"].queue_free()
		#set the parent to default.
		relationships[child]["parent"]=default_parent
	#clear the selection list
	selected_links=[]
	#update the side menue as a bunch of links may have just changed.
	update_example()


func _on_export_pressed() -> void:
	var data = CategoryData.new()
	data.category_dictorary = _generate_tree(root)
	ResourceSaver.save(data,"res://data/generated/menus/menu.res")


func _generate_tree(parent:String):
	var links = []
	for child in relationships[parent]["child"]:
		if len(relationships[child]["child"]) == 0:
			links.append(child)
		else:
			links.append({child:_generate_tree(child)})
	return links


func make_child_tabs(parent:VBoxContainer,item:String,prefix:String):
	#a method that simply makes labels with tab indents. each recursion layer gets more tabs.
	var parent_label = Label.new()
	parent.add_child(parent_label)
	parent_label.text = prefix + item
	for child in relationships[item]["child"]:
		make_child_tabs(parent,child,prefix+tab)


func update_example():
	#remove all the old lables and old tabs.
	for categories in demoArea.get_children():
		if categories.name in relationships[root]["child"]:
			for label in categories.get_children():
				label.queue_free()
		else:
			categories.queue_free()
	#adding back the new tabs. specifically only adding in tabs that are related to root
	for parent in relationships[root]["child"]:
		var category = null
		#finding the correct tab because for some reason find_node failed me
		for child in demoArea.get_children():
			if child.name == parent:
				category=child
				break
		#add all the lables
		if category:
			for child in relationships[parent]["child"]:
				#doing this recursively... because i couldn't figure out a better way
				make_child_tabs(category,child,"")
		else:
			#if a the category VBOX doesnt exist make it 
			category = VBoxContainer.new()
			category.name=parent
			demoArea.add_child(category)
			for child in relationships[parent]["child"]:
				make_child_tabs(category,child,"")


func _on_save_pressed() -> void:
	var dir = DirAccess.open("res://data/generated/")
	if not(dir.dir_exists("res://data/generated/menus")):
		dir.make_dir("res://data/generated/menus")
	var save_file = FileAccess.open("res://data/generated/menus/menu.json",FileAccess.WRITE)
	save_file.store_line(JSON.stringify(relationships))

func _on_close_requested() -> void:
	get_parent().remove_child(self)
	queue_free()
