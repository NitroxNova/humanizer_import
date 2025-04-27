class_name LanguageCollector

var language_data = {}
var languages = PackedStringArray(["en"])
const lang_file = "res://data/generated/languages.csv"
func _init()->void:
	_load_language_file()

func _load_language_file()->void:
	if FileAccess.file_exists(lang_file):
		var csv_read = FileAccess.open(lang_file,FileAccess.READ)
		var headder = csv_read.get_csv_line(",")
		headder.remove_at(headder.find("keys",0))
		languages = headder
		while !csv_read.eof_reached():
			var line = csv_read.get_csv_line(",")
			var string_name = line.get(0)
			if len(string_name)>0:
				language_data[string_name]={}
				line.remove_at(0)
				for i in len(languages):
					language_data[string_name][languages[i]]=line.get(i)

func check_if_key_exists(string_key:String)->bool:
	return language_data.has(string_key)

func add_item(string_key:String)->void:
	if check_if_key_exists(string_key):
		push_warning("%s already exists in database. Skipping." % [string_key])
		return
	else:
		language_data[string_key]={"en":string_key}
		

func purge_language_file()->void:
	languages = PackedStringArray(["en"])
	language_data = {}
	if FileAccess.file_exists(lang_file):
		var dir = DirAccess.open(lang_file)
		dir.remove(lang_file)

func save_language_file()->void:
	var line_to_write = PackedStringArray(["keys"])
	line_to_write.append_array(languages)
	var file_obj = FileAccess.open(lang_file, FileAccess.WRITE)
	file_obj.store_csv_line(line_to_write)
	for string_key in language_data.keys():
		line_to_write = PackedStringArray([string_key])
		for lang in languages:
			if lang in language_data[string_key].keys():
				line_to_write.append(language_data[string_key][lang])
			else:
				line_to_write.append("")
		file_obj.store_csv_line(line_to_write)
	
