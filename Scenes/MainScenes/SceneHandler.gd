extends Node

var last_map_name
var current_map
var interface_effects
var in_game_for_menu = false

func _ready():
	link_main_menu()
	link_setting_change()
	check_fps_monitor()
	process_audio_settings()
	
	Console.add_command("open_editor", on_open_editor)
	Console.add_command("map", on_load_map, 1)
	
	check_autoexec()
	
func check_autoexec():
	if "autoexec" in GameData.config:
		var autoexecArray = GameData.config.autoexec
		for line in autoexecArray:
			if line:
				Console.on_text_entered(line)
	
func _input(event):
	if event.is_action_pressed("ui_menu"):
		var game_scene = get_node_or_null("GameScene")
		if !game_scene.main_menu_mode:
			if get_node_or_null("MainMenu"):
				on_resume_game_pressed()			
			else:
				load_main_menu(true)
				get_tree().paused = true
	
func link_setting_change():
	# warning-ignore:return_value_discarded
	GameData.connect("setting_updated", Callable(self, "setting_change"))
	# warning-ignore:return_value_discarded
	GameData.connect("config_updated", Callable(self, "config_element_update"))

func check_fps_monitor():
	if GameData.config.settings.show_fps_monitor:
		DebugMenu.style = DebugMenu.Style.VISIBLE_COMPACT
	else:
		DebugMenu.style = DebugMenu.Style.HIDDEN
		
func setting_change(setting_key, _value):
	get_node("ConfigurationManager").write_config('settings')
		
	if setting_key == "show_fps_monitor":
		check_fps_monitor()
	elif setting_key in GameData.config.settings_map and 'audio_bus' in GameData.config.settings_map[setting_key]:
		process_audio_bus_change(setting_key)
		
func process_audio_settings():
	for key in GameData.config.settings_map:
		var settings_map_data = GameData.config.settings_map[key]
		if 'audio_bus' in settings_map_data:
			process_audio_bus_change(key)
		
func process_audio_bus_change(setting_key):
	var settings_map_data = GameData.config.settings_map[setting_key]
	var percent_value = GameData.config.settings[setting_key]
	var value = percent_value / 100
	
	var bus_index = AudioServer.get_bus_index(settings_map_data.audio_bus)
	if bus_index != -1:
		AudioServer.set_bus_volume_db(bus_index, linear_to_db(value))
		
func config_element_update(key):
	get_node("ConfigurationManager").write_config(key)
	
func load_main_menu(in_game = false):
	var congrats_menu = get_node_or_null("CongratsMenu")
	if congrats_menu and is_instance_valid(congrats_menu):
		congrats_menu.queue_free()
	var main_menu = load("res://Scenes/UIScenes/MainMenu.tscn").instantiate()
	in_game_for_menu = in_game
	add_child(main_menu)
	link_main_menu()
	
func load_congrats_menu(result):
	var congrats_menu = load("res://Scenes/UIScenes/CongratsMenu.tscn").instantiate()
	congrats_menu.result = result
	add_child(congrats_menu)
	# warning-ignore:return_value_discarded
	get_node("CongratsMenu/Container/VBoxContainer/MainMenu").connect("pressed", Callable(self, "on_congrats_main_menu"))
	# warning-ignore:return_value_discarded
	get_node("CongratsMenu/Container/VBoxContainer/Quit").connect("pressed", Callable(self, "on_quit_pressed"))
	
	last_map_name = current_map
	
	var last_map_data = GameData.config.maps[last_map_name]
	if "next_map" not in last_map_data:
		get_node("CongratsMenu/Container/VBoxContainer/Continue").visible = false
	else:
		# warning-ignore:return_value_discarded
		get_node("CongratsMenu/Container/VBoxContainer/Continue").connect("pressed", Callable(self, "on_continue_pressed"))

func link_main_menu():
	# warning-ignore:return_value_discarded
	get_node("MainMenu/Container/VBoxContainer/NewGame").connect("pressed", Callable(self, "on_new_game_pressed"))
	# warning-ignore:return_value_discarded
	get_node("MainMenu/Container/VBoxContainer/ResumeGame").connect("pressed", Callable(self, "on_resume_game_pressed"))
	# warning-ignore:return_value_discarded
	get_node("MainMenu/Container/VBoxContainer/Settings").connect("pressed", Callable(self, "on_settings_pressed"))
	# warning-ignore:return_value_discarded
	get_node("MainMenu/Container/VBoxContainer/Editor").connect("pressed", Callable(self, "on_editor_pressed"))
	# warning-ignore:return_value_discarded
	get_node("MainMenu/Container/VBoxContainer/About").connect("pressed", Callable(self, "on_about_pressed"))
	# warning-ignore:return_value_discarded
	get_node("MainMenu/Container/VBoxContainer/Quit").connect("pressed", Callable(self, "on_quit_pressed"))
	# warning-ignore:return_value_discarded
	get_node("MainMenu/Container/VBoxContainer/MainMenu").connect("pressed", Callable(self, "on_main_menu_pressed"))
	interface_effects = get_node("MainMenu/InterfaceEffects")
	
	if in_game_for_menu:
		get_node("MainMenu/Container/TitleContainer").visible = false
		get_node("MainMenu/Container/VBoxContainer/ResumeGame").visible = true
		get_node("MainMenu/Container/VBoxContainer/MainMenu").visible = true
		get_node("MainMenu/BackgroundMusic").autoplay = false
		get_node("MainMenu/BackgroundMusic").playing = false
		get_node("MainMenu/BackgroundMusic").volume_db = -100
		get_node("MainMenu/Container/VBoxContainer/ResumeGame").grab_focus()
	else:
		var map_name = GameData.config.settings.main_menu_map
		var game_scene = load("res://Scenes/MainScenes/GameScene.tscn").instantiate()
		game_scene.map_name = map_name
		game_scene.main_menu_mode = true
		game_scene.process_mode = Node.PROCESS_MODE_PAUSABLE
		add_child(game_scene)
		move_child(game_scene, 0)
		get_node("MainMenu/Container/VBoxContainer/NewGame").grab_focus()
		
func on_main_menu_pressed():
	var main_menu = get_node_or_null("MainMenu")
	if main_menu:
		get_node("GameScene").free()
		main_menu.free()
	on_congrats_main_menu()

func on_new_game_pressed():
	get_node("GameScene").free()
	GameData.play_button_sound(interface_effects)
	last_map_name = null
	get_node("MainMenu").queue_free()
	load_game_scene()
	in_game_for_menu = false
	
func on_resume_game_pressed():
	GameData.play_button_sound(interface_effects)
	get_node("MainMenu").queue_free()
	in_game_for_menu = false
	get_tree().paused = false
	
func on_settings_pressed():
	GameData.play_button_sound(interface_effects)
	get_node("SettingsPopup").open_popup()
	
func on_editor_pressed(disable_sound = false):
	if not disable_sound:
		GameData.play_button_sound(interface_effects)
	get_node("EditorPopup").open_popup()
	
func on_about_pressed():
	GameData.play_button_sound(interface_effects)
	get_node("AboutPopup").open_popup()
	
func on_continue_pressed():
	GameData.play_button_sound(interface_effects)
	var last_map_data = GameData.config.maps[last_map_name]
	if "next_map" in last_map_data:
		get_node("CongratsMenu").queue_free()
		var new_map = last_map_data.next_map
		load_game_scene(new_map)
		
func on_congrats_main_menu():
	unload_game(null, current_map, true)
	load_main_menu()
	
func load_game_scene(map_name = null):
	if current_map:
		unload_game(null, current_map, true)
	
	if not map_name:
		map_name = GameData.config.settings.starting_map
		
	var game_scene = load("res://Scenes/MainScenes/GameScene.tscn").instantiate()
	game_scene.map_name = map_name
	game_scene.connect("game_finished", Callable(self, 'unload_game'))
	game_scene.process_mode = Node.PROCESS_MODE_PAUSABLE
	game_scene.set_name("GameScene")
	add_child(game_scene)
	current_map = map_name
	interface_effects = get_node("GameScene/InterfaceEffects")
	
func on_quit_pressed():
	GameData.play_button_sound(interface_effects)
	get_tree().quit()

func unload_game(result, map_name, skip_load = false):
	if result:
		return load_congrats_menu(result)
	
	last_map_name = map_name
	current_map = null
	
	var game_scene = get_node_or_null("GameScene")
	if game_scene:
		game_scene.free()
	
	if not skip_load:
		if not result:
			load_main_menu()

# console commands related to the menu/game behavior

func on_open_editor():
	Console.toggle_console()
	on_editor_pressed(true)

func on_load_map(map_name):
	if not map_name:
		Console.print_line("map <map_name>")
		return
		
	var main_menu = get_node_or_null("MainMenu")
	if main_menu:
		get_node("GameScene").free()
		main_menu.free()
	
	if current_map:
		unload_game(null, current_map, true)
	
	load_game_scene(map_name)