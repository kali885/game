extends Control

# Путь к сцене с самой игрой
@export var game_scene_path: String = "res://Game.tscn"

# Автоматическое считывание узлов из сцены
@onready var color_rect: ColorRect = $ColorRect if has_node("ColorRect") else null
@onready var vbox: VBoxContainer = $VBoxContainer if has_node("VBoxContainer") else null
@onready var label: Label = $VBoxContainer/Label if has_node("VBoxContainer/Label") else null
@onready var play_button: Button = $VBoxContainer/PlayButton if has_node("VBoxContainer/PlayButton") else null
@onready var settings_button: Button = $VBoxContainer/SettingsButton if has_node("VBoxContainer/SettingsButton") else null
@onready var exit_button: Button = $VBoxContainer/ExitButton if has_node("VBoxContainer/ExitButton") else null

var background_video: VideoStreamPlayer = null
var time_passed: float = 0.0


func _ready() -> void:
	_setup_background_video()
	_setup_responsive_layout()
	_apply_blue_theme()
	_connect_signals()
	$MenuMusic.finished.connect(_on_menu_music_finished)
	
func _on_menu_music_finished():
	$MenuMusic.play()


func _process(delta: float) -> void:
	time_passed += delta * 3.0
	queue_redraw()

	# Небольшая пульсация кнопки "ИГРАТЬ" для привлечения внимания
	if play_button:
		var scale_val: float = 1.0 + sin(time_passed) * 0.03
		play_button.pivot_offset = play_button.size / 2.0
		play_button.scale = Vector2(scale_val, scale_val)


func _draw() -> void:
	# Запасной фон на случай, если видео еще не загрузилось.
	var screen_size: Vector2 = get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, screen_size), Color("#0B132B"), true)


func _setup_background_video() -> void:
	# Видео создаётся кодом, поэтому main_menu.tscn остаётся в исходном
	# формате проекта и не требует пересохранения новой версией Godot.
	var video_path: String = "res://assets/block_nova_menu.ogv"
	var video_stream = load(video_path)

	if video_stream == null:
		print("Не удалось загрузить фон видео: ", video_path)
		return

	background_video = VideoStreamPlayer.new()
	background_video.name = "BackgroundVideo"
	background_video.set_anchors_preset(Control.PRESET_FULL_RECT)
	background_video.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background_video.expand = true
	background_video.loop = true
	background_video.stream = video_stream

	add_child(background_video)
	move_child(background_video, 0)
	background_video.play()


func _setup_responsive_layout() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	if color_rect:
		color_rect.visible = false

	if vbox:
		vbox.set_anchors_preset(Control.PRESET_CENTER)
		vbox.grow_horizontal = Control.GROW_DIRECTION_BOTH
		vbox.grow_vertical = Control.GROW_DIRECTION_BOTH
		vbox.custom_minimum_size = Vector2(340, 0)
		vbox.add_theme_constant_override("separation", 22)


func _apply_blue_theme() -> void:
	if label:
		label.text = "BLOCK NOVA"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 90)
		label.add_theme_color_override("font_color", Color("#F8FAFC"))
		label.add_theme_color_override("font_shadow_color", Color("#1E40AF"))
		label.add_theme_constant_override("shadow_offset_x", 0)
		label.add_theme_constant_override("shadow_offset_y", 6)

	if play_button:
		play_button.text = "ИГРАТЬ"
		_style_single_button(play_button, Color("#2563EB"), Color("#3B82F6"), Color("#1D4ED8"), 28, 72)

	if settings_button:
		settings_button.text = "НАСТРОЙКИ"
		_style_single_button(settings_button, Color("#1E293B"), Color("#334155"), Color("#0F172A"), 22, 60)

	if exit_button:
		exit_button.text = "ВЫХОД"
		_style_single_button(exit_button, Color("#1E293B"), Color("#334155"), Color("#0F172A"), 22, 60)


func _style_single_button(btn: Button, bg_color: Color, hover_color: Color, pressed_color: Color, font_size: int, height: int) -> void:
	btn.custom_minimum_size = Vector2(300, height)
	btn.add_theme_font_size_override("font_size", font_size)
	btn.add_theme_color_override("font_color", Color.WHITE)

	var style_normal := StyleBoxFlat.new()
	style_normal.bg_color = bg_color
	style_normal.set_corner_radius_all(18)
	style_normal.set_border_width_all(2)
	style_normal.border_color = bg_color.lightened(0.25)

	var style_hover := StyleBoxFlat.new()
	style_hover.bg_color = hover_color
	style_hover.set_corner_radius_all(18)
	style_hover.set_border_width_all(2)
	style_hover.border_color = Color.WHITE

	var style_pressed := StyleBoxFlat.new()
	style_pressed.bg_color = pressed_color
	style_pressed.set_corner_radius_all(18)

	btn.add_theme_stylebox_override("normal", style_normal)
	btn.add_theme_stylebox_override("hover", style_hover)
	btn.add_theme_stylebox_override("pressed", style_pressed)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _connect_signals() -> void:
	if play_button and not play_button.pressed.is_connected(_on_play_pressed):
		play_button.pressed.connect(_on_play_pressed)

	if settings_button and not settings_button.pressed.is_connected(_on_settings_pressed):
		settings_button.pressed.connect(_on_settings_pressed)

	if exit_button and not exit_button.pressed.is_connected(_on_exit_pressed):
		exit_button.pressed.connect(_on_exit_pressed)


func _on_play_pressed() -> void:
	$ButtonSound.play()
	await get_tree().create_timer(0.1).timeout
	get_tree().change_scene_to_file(game_scene_path)


func _on_settings_pressed() -> void:
	$ButtonSound.play()
	$SettingsPanel.position = (get_viewport_rect().size - $SettingsPanel.size) / 2.0
	$SettingsPanel.visible = true


func _on_exit_pressed() -> void:
	$ButtonSound.play()
	await get_tree().create_timer(0.1).timeout
	get_tree().quit()


func _on_music_button_toggled(toggled_on: bool) -> void:
	if toggled_on:
		$MenuMusic.play()
	else:
		$MenuMusic.stop()
