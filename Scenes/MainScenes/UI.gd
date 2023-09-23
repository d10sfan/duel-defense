extends CanvasLayer

@onready var money = get_node("HUD/InfoBar/M/H/Money")

@onready var wave_wrapper = get_node("HUD/WaveContainer")
@onready var wave = get_node("HUD/WaveContainer/WaveWrapper/Wave")
@onready var wave_label = get_node("HUD/WaveContainer/WaveWrapper/WaveLabel")
@onready var remaining = get_node("HUD/WaveContainer/WaveWrapper/Remaining")
@onready var next_wave = get_node("HUD/WaveContainer/WaveWrapper/NextWave")

@onready var info_bar = get_node("HUD/InfoBar")
@onready var build_bar = get_node("HUD/InfoBar/M/H/BuildBar")
@onready var upgrade_bar = get_node("HUD/InfoBar/M/H/UpgradeBar")

@onready var interface_effects = get_parent().get_node("InterfaceEffects")

@onready var pause_play_button = get_node("HUD/InfoBar/M/H/GameControls/PausePlay")
@onready var speed_up_button = get_node("HUD/InfoBar/M/H/GameControls/SpeedUp")

var money_number = 0
var remaining_number

var bar_focus = false

var cooldown_timers = []

func _ready():
	for i in upgrade_bar.get_children():
		i.connect("pressed", Callable(self, "upgrade_requested").bind(i.get_name()))
		
	Console.add_command("list_towers", on_list_towers)
	Console.add_command("list_tower_data", on_list_tower_data, 1)
	Console.add_command("toggle_play", on_toggle_play)
	
func _physics_process(_delta):
	if Input.is_action_just_pressed("ui_fastforward"):
		_on_SpeedUp_pressed()
	if Input.is_action_just_pressed("ui_play"):
		_on_PausePlay_pressed()
	
	for timer_metadata in cooldown_timers:
		if not timer_metadata.timer.is_stopped():
			var timer_percentage = (timer_metadata.timer.time_left / timer_metadata.total_time) * 100
			update_cooldown_progress(timer_percentage, timer_metadata)
	
### UI controller functions

func ui_bar_focus_toggle(force_off = false, bar = build_bar):
	if force_off:
		bar_focus = false
	else:
		bar_focus = !bar_focus
	if bar_focus:
		info_bar.self_modulate = "000000b4"
		var build_bar_children = bar.get_children()
		if len(build_bar_children):
			build_bar_children[0].grab_focus()
	else:
		info_bar.self_modulate = "00000078"
		bar.visible = false
		bar.visible = true

### build functions

func set_tower_preview(tower_type, mouse_position):
	var drag_tower = load("res://Scenes/Turrets/" + GameData.config.tower_data[tower_type].scene_name + ".tscn").instantiate()
	drag_tower.set_name("DragTower")
	drag_tower.modulate = Color("a3a3e4", 0.4)
	drag_tower.type = tower_type
	
	var range_texture = Sprite2D.new()
	range_texture.set_name("RangeTexture")
	range_texture.position = Vector2(0,0)
	var scaling = GameData.config.tower_data[tower_type].range / 100
	range_texture.scale = Vector2(scaling, scaling)
	var texture = load("res://Assets/UI/circle.svg")
	range_texture.texture = texture
	range_texture.modulate = Color("a3a3e4", 0.4)
	
	var control	= Control.new()
	control.add_child(drag_tower, true)
	control.add_child(range_texture, true)
	control.position = mouse_position
	control.set_name("TowerPreview")
	add_child(control, true)
	move_child(get_node("TowerPreview"), 0)

func update_tower_preview(new_position, color):
	get_node("TowerPreview").position = new_position
	if get_node("TowerPreview/DragTower").modulate != Color(color, 0.4):
		get_node("TowerPreview/DragTower").modulate = Color(color, 0.4)
		get_node("TowerPreview/RangeTexture").modulate = Color(color, 0.4)

### game control functions

func _on_PausePlay_pressed():
	GameData.play_button_sound(interface_effects)
	if get_parent().build_mode:
		get_parent().cancel_build_mode()
	if get_tree().is_paused():
		get_tree().paused = false
		pause_play_button.text = MaterialIconsDB.get_icon_char("pause")
		GodotLogger.info("game resumed")
	elif get_parent().current_wave == 0:
		GodotLogger.info("game started")
		pause_play_button.text = MaterialIconsDB.get_icon_char("pause")
		get_parent().start_next_wave()
	else:
		pause_play_button.text = MaterialIconsDB.get_icon_char("play")
		GodotLogger.info("game paused")
		get_tree().paused = true


func _on_SpeedUp_pressed():
	GameData.play_button_sound(interface_effects)
	if get_parent().build_mode:
		get_parent().cancel_build_mode()
	if Engine.get_time_scale() != 1.0:
		speed_up_button.set("theme_override_colors/font_color", Color.WHITE)
		speed_up_button.set("theme_override_colors/font_focus_color", Color.WHITE)
		Engine.set_time_scale(1.0)
	else:
		speed_up_button.set("theme_override_colors/font_color", Color.YELLOW)
		speed_up_button.set("theme_override_colors/font_focus_color", Color.YELLOW)
		Engine.set_time_scale(2.0)

func update_money(current_money, immediate = false):
	if immediate:
		money.text = str(current_money)
		money_number = current_money
	else:
		var tween = get_tree().create_tween()
		tween.tween_method(on_money_tween_step, int(money.text), current_money, 0.7)
		
func on_money_tween_step(value):
	if money:
		money.text = str(int(value))
	
func update_wave_data(enemies_in_wave, current_wave):
	if not wave_wrapper.visible:
		wave_wrapper.visible = true
		
	wave_label.visible = true
	wave.visible = true
	next_wave.visible = false
	remaining.visible = true
	wave_label.text = "WAVE"
	
	if wave.text != str(current_wave):
		wave.text = str(current_wave)
	
	if remaining.text != str(enemies_in_wave):
		remaining.text = str(enemies_in_wave)
		
func wave_completed():
	remaining.visible = false
	wave.visible = false
	next_wave.visible = true
	next_wave.value = 100
	wave_label.text = "WAVE COMPLETE!"
	
func update_next_wave_progress(progress):
	next_wave.value = progress
	
func show_upgrade_bar(upgrades):
	build_bar.visible = false
	upgrade_bar.visible = true
	var new_tower_data = {}
	for upgrade_name in upgrades:
		new_tower_data[upgrade_name] = GameData.config.tower_data[upgrade_name]
	setup_build_buttons(new_tower_data, upgrade_bar, true, "upgrade_requested")
	bar_focus = false
	ui_bar_focus_toggle(false, upgrade_bar)

func hide_upgrade_bar():
	upgrade_bar.visible = false
	build_bar.visible = true
	ui_bar_focus_toggle(true)

func upgrade_requested(upgrade_name):
	get_parent().upgrade_requested(upgrade_name)
	
func setup_build_buttons(buttons, parent_node, show_regardless = false, func_name = "initiate_build_mode"):
	for child in parent_node.get_children():
		child.free()
		
	var font = preload("res://Assets/UI/OperationNapalm-Regular.ttf")
	
	for button_name in buttons:
		var item = buttons[button_name]
		if show_regardless or ('in_build_menu' in item and item.in_build_menu):
			var button = Button.new()
			button.name = button_name
			button.custom_minimum_size = Vector2(80, 80)
			button.size_flags_horizontal = TextureButton.SIZE_SHRINK_CENTER
			button.size_flags_vertical = TextureButton.SIZE_SHRINK_CENTER
			button.offset_left = 10
			button.connect("pressed", Callable(get_parent(), func_name).bind(button.get_name()))
			
			var icon = load("res://Scenes/Turrets/" + item.scene_name + ".tscn").instantiate()
			icon.name = button_name
			icon.type = button_name
			icon.scale = Vector2(0.7, 0.7)
			icon.position = Vector2(40, 40)
			icon.icon_mode = true
				
			button.add_child(icon)
			
			var label = Label.new()
			if func_name == "upgrade_requested":
				label.text = "$%s" % item.upgrade_cost
			else:
				label.text = "$%s" % item.cost
			label.set("theme_override_fonts/font", font)
			button.add_child(label)
			
			parent_node.add_child(button)
			
func start_button_cooldown(build_type):
	for button in build_bar.get_children():
		if button.name == build_type:
			GodotLogger.debug("start_button_cooldown, found button for %s" % build_type)
			
			var progress_scene = load("res://Scenes/SupportScenes/ProgressCircle.tscn").instantiate()
			button.add_child(progress_scene)
			button.disabled = true
			
			var timer = Timer.new()
			timer.one_shot = true
			timer.autostart = false
			timer.name = build_type
			add_child(timer)
			
			var total_time = GameData.config.tower_data[build_type]["cooldown"]
			var metadata = {"timer": timer, "total_time": total_time, "build_type": build_type, "progress_scene": progress_scene}
			cooldown_timers.append(metadata)
			
			timer.start(total_time); await timer.timeout
			progress_scene.queue_free()
			button.disabled = false
			timer.queue_free()
			cooldown_timers.erase(metadata)
			
			break
			
func update_cooldown_progress(timer_percentage, timer_metadata):
	timer_metadata.progress_scene.value = timer_percentage

# console commands related to UI

func on_list_towers():
	var tower_types = []
	for tower_type in GameData.config.tower_data:
		tower_types.append(tower_type)
	
	Console.print_line(JSON.stringify(tower_types))
	
func on_list_tower_data(tower_type):
	if not tower_type:
		Console.print_line("list_tower_data <tower_type>")
		return
		
	if not tower_type in GameData.config.tower_data:
		Console.print_line("list_tower_data <tower_type>, tower_type is invalid")
		return
		
	Console.print_line(JSON.stringify(GameData.config.tower_data[tower_type], "\t"))

func on_toggle_play():
	_on_PausePlay_pressed()