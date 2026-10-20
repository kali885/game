extends Node2D

const BOARD_SIZE: int = 8
const CELL_GAP: float = 6.0
const PIECE_GAP: float = 4.0

const DRAG_OFFSET: Vector2 = Vector2(0, -90.0)
const SAVE_PATH: String = "user://highscore.save"

var board: Array = []
var pieces: Array = []

var cell_size: float = 48.0
var piece_cell_size: float = 28.0

var score: int = 0
var high_score: int = 0
var dragging: bool = false
var selected_piece: int = -1
var drag_position: Vector2 = Vector2.ZERO
var preview_cell: Vector2i = Vector2i(-1, -1)

# Анимации
var drag_scale: Vector2 = Vector2.ONE
var drag_tween: Tween

# Запас (Hold)
var hold_piece: Dictionary = {}
var can_hold: bool = true

# Game Over
var is_game_over: bool = false

# Музыка
var music_player: AudioStreamPlayer
var _app_paused: bool = false

# Эффекты
var clearing_cells: Dictionary = {}
var camera_offset: Vector2 = Vector2.ZERO
var pulse_timer: float = 0.0

var colors: Array[Color] = [
	Color("#4C83F5"), # Неоново-синий
	Color("#2ECC71"), # Изумрудный
	Color("#FFB020"), # Янтарный
	Color("#FF5252"), # Коралловый
	Color("#9B51E0"), # Фиолетовый
	Color("#00C9A7")  # Бирюзовый
]

var shapes: Array = [
	[Vector2i(0, 0)],
	[Vector2i(0, 0), Vector2i(1, 0)],
	[Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)],
	[Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1)],
	[Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)],
	[Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, 1)],
	[Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(1, 2)],
	[Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)],
	[Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 3)],
	[Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(0, 2)],
	[Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(2, 1), Vector2i(2, 2)],
	[Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(0, 2), Vector2i(1, 2)],
	[Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, 1), Vector2i(1, 2)],
	[Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(2, 2)],
	[Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)]
]

# Кэшированные графические стили для UI
var _style_cell_empty := StyleBoxFlat.new()
var _style_board_bg := StyleBoxFlat.new()
var _style_dialog := StyleBoxFlat.new()
var _style_btn := StyleBoxFlat.new()
var _background_gradient: GradientTexture2D

# Настройки игры
var sound_enabled: bool = true
var music_enabled: bool = true
var vibration_enabled: bool = true
var settings_open: bool = false
var settings_root: Control
var settings_panel: Panel
var sound_button: Button
var music_button: Button
var vibration_button: Button
var gear_button: Button

const SETTINGS_PATH: String = "user://block_nova_settings.cfg"

# Космический прогресс: объект меняется, когда поле полностью очищено.
const SPACE_NAMES: Array[String] = ["СОЛНЕЧНАЯ СИСТЕМА", "ЗЕМЛЯ", "ЛУНА", "МАРС", "ВЕНЕРА", "ЮПИТЕР", "САТУРН", "УРАН", "НЕПТУН", "ЧЁРНАЯ ДЫРА"]
const SPACE_PATHS: Array[String] = [
	"res://space_backgrounds/solar_system.png",
	"res://space_backgrounds/earth.png",
	"res://space_backgrounds/moon.png",
	"res://space_backgrounds/mars.png",
	"res://space_backgrounds/venus.png",
	"res://space_backgrounds/jupiter.png",
	"res://space_backgrounds/saturn.png",
	"res://space_backgrounds/uranus.png",
	"res://space_backgrounds/neptune.png",
	"res://space_backgrounds/black_hole.png"
]
var space_stage: int = 0
var space_background: Texture2D
var space_title: String = "СОЛНЕЧНАЯ СИСТЕМА"
var space_transition: float = 1.0


func _ready() -> void:
	_init_styles()
	_init_background_gradient()
	high_score = _load_highscore()
	_recalculate_sizes()
	_create_board()
	_create_pieces()
	_load_settings()
	_create_settings_ui()
	_apply_settings()
	_load_space_stage()
	queue_redraw()


func _init_background_gradient() -> void:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([
		Color("#12051F"),
		Color("#35105E"),
		Color("#6A2BA8"),
		Color("#21164F")
	])
	_background_gradient = GradientTexture2D.new()
	_background_gradient.gradient = gradient
	_background_gradient.width = 720
	_background_gradient.height = 1280
	_background_gradient.fill_from = Vector2(0.5, 0.0)
	_background_gradient.fill_to = Vector2(0.5, 1.0)


func _init_styles() -> void:
	_style_cell_empty.bg_color = Color(0.094, 0.133, 0.220, 0.20)
	_style_cell_empty.set_corner_radius_all(8)
	_style_cell_empty.set_border_width_all(1)
	_style_cell_empty.border_color = Color(0.16, 0.22, 0.33, 0.35)

	_style_board_bg.bg_color = Color(0.067, 0.102, 0.18, 0.24)
	_style_board_bg.set_corner_radius_all(16)
	_style_board_bg.set_border_width_all(2)
	_style_board_bg.border_color = Color(0.13, 0.18, 0.30, 0.45)

	_style_dialog.bg_color = Color("#181E29")
	_style_dialog.set_corner_radius_all(20)
	_style_dialog.set_border_width_all(3)
	_style_dialog.border_color = Color("#FF5252")

	_style_btn.bg_color = Color("#2ECC71")
	_style_btn.set_corner_radius_all(14)


func _process(delta: float) -> void:
	pulse_timer += delta * 4.0
	if space_transition < 1.0:
		space_transition = min(space_transition + delta * 2.5, 1.0)
	queue_redraw()


func _top_margin() -> float:
	var screen_h: float = get_viewport_rect().size.y
	return max(130.0, screen_h * 0.14)


func _recalculate_sizes() -> void:
	var screen: Vector2 = get_viewport_rect().size
	var side_margin: float = 24.0
	
	var available_width: float = screen.x - (side_margin * 2.0) - ((BOARD_SIZE - 1) * CELL_GAP)
	var w_cell_size: float = available_width / BOARD_SIZE

	var top_zone: float = _top_margin() + 180.0
	var bottom_zone: float = 210.0
	var available_height: float = screen.y - top_zone - bottom_zone - ((BOARD_SIZE - 1) * CELL_GAP)
	var h_cell_size: float = available_height / BOARD_SIZE

	cell_size = min(w_cell_size, h_cell_size)
	piece_cell_size = cell_size * 0.52


func _create_board() -> void:
	board.clear()
	for row in range(BOARD_SIZE):
		var line: Array = []
		for col in range(BOARD_SIZE):
			line.append(-1)
		board.append(line)

	# Стартовое поле: около 35% клеток уже занято.
	# Заполняем отдельными небольшими группами, чтобы игрок мог постепенно
	# достраивать линии и очищать поле, а не начинал с пустой доски.
	var start_shapes: Array = [
		[Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1)],
		[Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)],
		[Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1)],
		[Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, 1)],
		[Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2)]
	]

	var starts: Array[Vector2i] = [
		Vector2i(0, 0), Vector2i(5, 0), Vector2i(2, 2),
		Vector2i(5, 3), Vector2i(0, 5), Vector2i(4, 5)
	]

	for i in range(starts.size()):
		var shape: Array = start_shapes[i % start_shapes.size()]
		var pos: Vector2i = starts[i]
		if _can_place(shape, pos):
			_place_piece(shape, pos, colors[i % colors.size()])


func _create_pieces() -> void:
	pieces.clear()
	for i in range(3):
		pieces.append(_random_piece())


func _random_piece() -> Dictionary:
	var shape: Array = shapes[randi() % shapes.size()]
	var is_bomb: bool = (randf() < 0.18)
	var bomb_idx: int = randi() % shape.size() if is_bomb else -1

	return {
		"shape": shape,
		"color": colors[randi() % colors.size()],
		"is_bomb": is_bomb,
		"bomb_idx": bomb_idx
	}


func _board_size() -> float:
	return BOARD_SIZE * cell_size + (BOARD_SIZE - 1) * CELL_GAP


func _board_position() -> Vector2:
	_recalculate_sizes()
	var screen: Vector2 = get_viewport_rect().size
	var width: float = _board_size()
	
	var top_zone: float = _top_margin() + 180.0
	var bottom_zone: float = 210.0
	var available_height: float = screen.y - top_zone - bottom_zone
	var center_y: float = top_zone + (available_height - width) / 2.0
	
	return Vector2((screen.x - width) / 2.0, center_y) + camera_offset


func _cell_position(cell: Vector2i) -> Vector2:
	var board_pos: Vector2 = _board_position()
	return board_pos + Vector2(
		cell.x * (cell_size + CELL_GAP),
		cell.y * (cell_size + CELL_GAP)
	)


func _piece_position(index: int) -> Vector2:
	var screen: Vector2 = get_viewport_rect().size
	var board_bottom: float = _board_position().y + _board_size()
	var bottom_space: float = screen.y - board_bottom
	
	var spacing: float = screen.x / 3.0
	var pos_x: float = spacing * index + spacing / 2.0
	
	var hover_offset: float = sin(pulse_timer * 1.8 + index * 1.5) * 5.0
	var pos_y: float = board_bottom + (bottom_space / 2.0) + hover_offset
	
	return Vector2(pos_x, pos_y)


func _hold_box_rect() -> Rect2:
	var screen: Vector2 = get_viewport_rect().size
	var top_y: float = _top_margin()
	return Rect2(Vector2(screen.x - 155, top_y), Vector2(135, 110))


func _draw() -> void:
	var screen: Vector2 = get_viewport_rect().size
	var board_pos: Vector2 = _board_position()
	var board_width: float = _board_size()
	var top_y: float = _top_margin()

	# Космический фон текущего этапа. Игровое поле остаётся полупрозрачным.
	if space_background:
		var bg_modulate := Color(1.0, 1.0, 1.0, 0.94)
		draw_texture_rect(space_background, Rect2(Vector2.ZERO, screen), false, bg_modulate)
	else:
		if _background_gradient:
			draw_texture_rect(_background_gradient, Rect2(Vector2.ZERO, screen), false)

	# Название текущего космического этапа.
	draw_string(ThemeDB.fallback_font, Vector2(24, top_y + 34), space_title, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color("#E6D6FF"))
	draw_string(ThemeDB.fallback_font, Vector2(24, top_y + 80), "👑 " + str(high_score), HORIZONTAL_ALIGNMENT_LEFT, -1, 36, Color("#FFD966"))
	draw_string(ThemeDB.fallback_font, Vector2(0, top_y + 160), str(score), HORIZONTAL_ALIGNMENT_CENTER, screen.x, 86, Color.WHITE)

	# Увеличенный блок "ЗАПАС"
	var hold_rect: Rect2 = _hold_box_rect()
	var hold_bg := Color("#151D30") if can_hold else Color("#0E1422")
	var hold_border := Color("#2ECC71") if can_hold else Color("#2A3752")
	draw_rect(hold_rect, hold_bg, true)
	draw_rect(hold_rect, hold_border, false, 3.0)

	draw_string(ThemeDB.fallback_font, hold_rect.position + Vector2(0, 30), "ЗАПАС", HORIZONTAL_ALIGNMENT_CENTER, hold_rect.size.x, 20, Color("#8A93A0"))

	if not hold_piece.is_empty():
		_draw_custom_piece(hold_piece, hold_rect.get_center() + Vector2(0, 14), 26.0)

	# Подложка доски
	draw_style_box(_style_board_bg, Rect2(board_pos - Vector2(10, 10), Vector2(board_width + 20, board_width + 20)))

	# Клетки игрового поля
	for row in range(BOARD_SIZE):
		for col in range(BOARD_SIZE):
			var cell: Vector2i = Vector2i(col, row)
			var pos: Vector2 = _cell_position(cell)

			if cell in clearing_cells:
				var progress: float = clearing_cells[cell]
				var orig_color: Color = colors[board[row][col]] if board[row][col] != -1 else Color.WHITE
				var flash_color: Color = orig_color.lerp(Color.WHITE, 1.0 - progress)
				var shrink_size: float = cell_size * progress
				var offset: float = (cell_size - shrink_size) / 2.0
				_draw_board_cell(pos + Vector2(offset, offset), Vector2(shrink_size, shrink_size), flash_color, true)

			elif board[row][col] != -1:
				var cell_color: Color = colors[board[row][col]]
				_draw_board_cell(pos, Vector2(cell_size, cell_size), cell_color, true)
			else:
				_draw_board_cell(pos, Vector2(cell_size, cell_size), Color("#182238"), false)

	# Превью при перетаскивании
	if dragging and selected_piece >= 0 and preview_cell.x >= 0:
		_draw_preview()

	# Нижняя панель с фигурами
	for i in range(pieces.size()):
		if i == selected_piece and dragging:
			continue
		_draw_piece(i)

	# Перетаскиваемая фигура
	if dragging and selected_piece >= 0:
		_draw_dragged_piece(selected_piece)

	# Окно Game Over
	if is_game_over:
		_draw_game_over_overlay(screen)


func _draw_piece(index: int) -> void:
	var piece: Dictionary = pieces[index]
	if piece.is_empty():
		return
	_draw_custom_piece(piece, _piece_position(index), piece_cell_size)


func _draw_custom_piece(piece: Dictionary, center: Vector2, block_size: float) -> void:
	var shape: Array = piece["shape"]
	var color: Color = piece["color"]
	var is_bomb: bool = piece.get("is_bomb", false)
	var bomb_idx: int = piece.get("bomb_idx", -1)
	var center_offset: Vector2 = _shape_center(shape)

	for idx in range(shape.size()):
		var cell: Vector2i = shape[idx]
		var cell_pos: Vector2 = center + Vector2(
			(cell.x - center_offset.x) * (block_size + 3.0),
			(cell.y - center_offset.y) * (block_size + 3.0)
		)
		var block_pos: Vector2 = cell_pos - Vector2(block_size, block_size) / 2.0

		if is_bomb and idx == bomb_idx:
			var pulse: float = (sin(pulse_timer * 2.0) + 1.0) / 2.0
			var bomb_color: Color = Color("#FF3366").lerp(Color("#FFCC00"), pulse)
			_draw_block(block_pos, Vector2(block_size, block_size), bomb_color)
			draw_string(ThemeDB.fallback_font, block_pos + Vector2(block_size * 0.1, block_size * 0.8), "💣", HORIZONTAL_ALIGNMENT_CENTER, -1, int(block_size * 0.75))
		else:
			_draw_block(block_pos, Vector2(block_size, block_size), color)
			if idx == 0 and not is_bomb:
				_draw_eyes(cell_pos, block_size, Vector2.ZERO, false)


func _draw_dragged_piece(index: int) -> void:
	var piece: Dictionary = pieces[index]
	var shape: Array = piece["shape"]
	var color: Color = piece["color"]
	var is_bomb: bool = piece.get("is_bomb", false)
	var bomb_idx: int = piece.get("bomb_idx", -1)

	var center_offset: Vector2 = _shape_center(shape)
	var active_pos: Vector2 = drag_position + DRAG_OFFSET

	for idx in range(shape.size()):
		var cell: Vector2i = shape[idx]
		var base_offset: Vector2 = Vector2(
			(cell.x - center_offset.x) * (cell_size + CELL_GAP),
			(cell.y - center_offset.y) * (cell_size + CELL_GAP)
		)
		var scaled_offset: Vector2 = base_offset * drag_scale
		var cell_pos: Vector2 = active_pos + scaled_offset
		var actual_size: Vector2 = Vector2(cell_size, cell_size) * drag_scale
		var block_pos: Vector2 = cell_pos - actual_size / 2.0

		if is_bomb and idx == bomb_idx:
			var pulse: float = (sin(pulse_timer * 3.0) + 1.0) / 2.0
			var bomb_color: Color = Color("#FF3366").lerp(Color("#FFCC00"), pulse)
			_draw_block(block_pos, actual_size, bomb_color)
			draw_string(ThemeDB.fallback_font, block_pos + Vector2(actual_size.x * 0.1, actual_size.y * 0.8), "💣", HORIZONTAL_ALIGNMENT_CENTER, -1, int(actual_size.x * 0.7))
		else:
			_draw_block(block_pos, actual_size, color)
			if idx == 0 and not is_bomb:
				_draw_eyes(cell_pos, actual_size.x, drag_position, true)


func _draw_eyes(center_pos: Vector2, block_size: float, look_target: Vector2, is_dragging: bool) -> void:
	var eye_spacing: float = block_size * 0.2
	var eye_radius: float = block_size * 0.12
	var pupil_radius: float = eye_radius * 0.55

	var left_eye: Vector2 = center_pos - Vector2(eye_spacing, block_size * 0.04)
	var right_eye: Vector2 = center_pos + Vector2(eye_spacing, -block_size * 0.04)

	var blink_val: float = sin(pulse_timer * 1.2)
	if blink_val > 0.96:
		draw_line(left_eye - Vector2(eye_radius, 0), left_eye + Vector2(eye_radius, 0), Color.WHITE, 2.0)
		draw_line(right_eye - Vector2(eye_radius, 0), right_eye + Vector2(eye_radius, 0), Color.WHITE, 2.0)
		return

	draw_circle(left_eye, eye_radius, Color.WHITE)
	draw_circle(right_eye, eye_radius, Color.WHITE)

	var pupil_offset: Vector2 = Vector2.ZERO
	if is_dragging and look_target != Vector2.ZERO:
		var dir: Vector2 = (look_target - center_pos).normalized()
		pupil_offset = dir * (eye_radius - pupil_radius)
	else:
		pupil_offset = Vector2(cos(pulse_timer * 1.5), sin(pulse_timer)) * 1.2

	draw_circle(left_eye + pupil_offset, pupil_radius, Color("#10141D"))
	draw_circle(right_eye + pupil_offset, pupil_radius, Color("#10141D"))

	draw_circle(left_eye + pupil_offset - Vector2(1, 1), pupil_radius * 0.4, Color.WHITE)
	draw_circle(right_eye + pupil_offset - Vector2(1, 1), pupil_radius * 0.4, Color.WHITE)


func _draw_block(pos: Vector2, size: Vector2, color: Color) -> void:
	var b: float = max(3.0, size.x * 0.15)

	var inner_rect := Rect2(pos + Vector2(b, b), size - Vector2(b * 2.0, b * 2.0))
	draw_rect(inner_rect, color, true)

	var top_poly := PackedVector2Array([
		pos,
		pos + Vector2(size.x, 0),
		pos + Vector2(size.x - b, b),
		pos + Vector2(b, b)
	])
	draw_polygon(top_poly, [color.lightened(0.38)])

	var left_poly := PackedVector2Array([
		pos,
		pos + Vector2(b, b),
		pos + Vector2(b, size.y - b),
		pos + Vector2(0, size.y)
	])
	draw_polygon(left_poly, [color.lightened(0.18)])

	var right_poly := PackedVector2Array([
		pos + Vector2(size.x, 0),
		pos + Vector2(size.x, size.y),
		pos + Vector2(size.x - b, size.y - b),
		pos + Vector2(size.x - b, b)
	])
	draw_polygon(right_poly, [color.darkened(0.28)])

	var bottom_poly := PackedVector2Array([
		pos + Vector2(0, size.y),
		pos + Vector2(b, size.y - b),
		pos + Vector2(size.x - b, size.y - b),
		pos + Vector2(size.x, size.y)
	])
	draw_polygon(bottom_poly, [color.darkened(0.42)])

	draw_rect(Rect2(pos, size), color.darkened(0.55), false, 1.5)
	draw_circle(pos + Vector2(b * 1.2, b * 1.2), b * 0.45, Color(1.0, 1.0, 1.0, 0.4))


func _draw_board_cell(pos: Vector2, size: Vector2, color: Color, filled: bool) -> void:
	if filled:
		_draw_block(pos, size, color)
	else:
		draw_style_box(_style_cell_empty, Rect2(pos, size))


func _draw_preview() -> void:
	var piece: Dictionary = pieces[selected_piece]
	var shape: Array = piece["shape"]
	var color: Color = piece["color"]

	var valid: bool = _can_place(shape, preview_cell)
	var bg_color := Color(color.r, color.g, color.b, 0.45 if valid else 0.18)
	var border_color := Color.WHITE if valid else Color("#FF3366")

	for cell: Vector2i in shape:
		var board_cell: Vector2i = preview_cell + cell
		if board_cell.x < 0 or board_cell.x >= BOARD_SIZE or board_cell.y < 0 or board_cell.y >= BOARD_SIZE:
			continue

		var rect := Rect2(_cell_position(board_cell), Vector2(cell_size, cell_size))
		draw_rect(rect, bg_color, true)
		draw_rect(rect, border_color, false, 2.0)


func _draw_game_over_overlay(screen: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, screen), Color(0, 0, 0, 0.82), true)

	# Увеличенное окно Game Over
	var box_w: float = min(screen.x - 32.0, 430.0)
	var box_h: float = 410.0
	var box_size: Vector2 = Vector2(box_w, box_h)
	var box_pos: Vector2 = (screen - box_size) / 2.0

	draw_style_box(_style_dialog, Rect2(box_pos, box_size))

	draw_string(ThemeDB.fallback_font, box_pos + Vector2(0, 72), "ИГРА ОКОНЧЕНА", HORIZONTAL_ALIGNMENT_CENTER, box_size.x, 36, Color("#FF5252"))
	draw_string(ThemeDB.fallback_font, box_pos + Vector2(0, 150), "Счёт: " + str(score), HORIZONTAL_ALIGNMENT_CENTER, box_size.x, 30, Color.WHITE)
	draw_string(ThemeDB.fallback_font, box_pos + Vector2(0, 205), "👑 Рекорд: " + str(high_score), HORIZONTAL_ALIGNMENT_CENTER, box_size.x, 26, Color("#FFD966"))

	var btn_w: float = box_w - 70.0
	var btn_rect: Rect2 = Rect2(box_pos + Vector2(35, 295), Vector2(btn_w, 66))
	draw_style_box(_style_btn, btn_rect)
	draw_string(ThemeDB.fallback_font, btn_rect.position + Vector2(0, 43), "ИГРАТЬ СНОВА", HORIZONTAL_ALIGNMENT_CENTER, btn_rect.size.x, 22, Color.BLACK)


func _input(event: InputEvent) -> void:
	if settings_open:
		return

	if is_game_over:
		if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed):
			_restart_game()
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_start_drag(event.position)
			else:
				_end_drag()

	elif event is InputEventMouseMotion:
		if dragging:
			_update_drag(event.position)

	elif event is InputEventScreenTouch:
		if event.pressed:
			_start_drag(event.position)
		else:
			_end_drag()

	elif event is InputEventScreenDrag:
		if dragging:
			_update_drag(event.position)


func _use_hold() -> void:
	if not can_hold or selected_piece < 0:
		return

	var current: Dictionary = pieces[selected_piece]
	if hold_piece.is_empty():
		hold_piece = current
		pieces[selected_piece] = _random_piece()
	else:
		var temp: Dictionary = hold_piece
		hold_piece = current
		pieces[selected_piece] = temp

	_play_sfx("place")
	can_hold = false
	dragging = false
	selected_piece = -1
	preview_cell = Vector2i(-1, -1)
	_check_game_over()
	queue_redraw()


func _start_drag(position: Vector2) -> void:
	for i in range(pieces.size()):
		if _is_inside_piece(i, position):
			selected_piece = i
			dragging = true
			drag_position = position
			_play_sfx("select")
			
			if drag_tween and drag_tween.is_valid():
				drag_tween.kill()
			drag_scale = Vector2(0.85, 1.15)
			drag_tween = create_tween()
			drag_tween.tween_property(self, "drag_scale", Vector2(1.0, 1.0), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

			_update_preview(position)
			queue_redraw()
			return


func _update_drag(position: Vector2) -> void:
	drag_position = position
	_update_preview(position)
	queue_redraw()


func _update_preview(position: Vector2) -> void:
	if selected_piece < 0:
		return

	var shape: Array = pieces[selected_piece]["shape"]
	var center_offset: Vector2 = _shape_center(shape)
	var board_pos: Vector2 = _board_position()

	var target_pos: Vector2 = position + DRAG_OFFSET

	var x: int = int(round((target_pos.x - board_pos.x) / (cell_size + CELL_GAP) - center_offset.x))
	var y: int = int(round((target_pos.y - board_pos.y) / (cell_size + CELL_GAP) - center_offset.y))

	preview_cell = Vector2i(x, y)


func _shape_center(shape: Array) -> Vector2:
	var min_x: float = 1000.0
	var max_x: float = -1000.0
	var min_y: float = 1000.0
	var max_y: float = -1000.0

	for cell: Vector2i in shape:
		min_x = min(min_x, float(cell.x))
		max_x = max(max_x, float(cell.x))
		min_y = min(min_y, float(cell.y))
		max_y = max(max_y, float(cell.y))

	return Vector2((min_x + max_x) / 2.0, (min_y + max_y) / 2.0)


func _is_inside_piece(index: int, position: Vector2) -> bool:
	var piece: Dictionary = pieces[index]
	if piece.is_empty():
		return false

	var shape: Array = piece["shape"]
	var center: Vector2 = _piece_position(index)
	var center_offset: Vector2 = _shape_center(shape)

	for cell: Vector2i in shape:
		var cell_pos: Vector2 = center + Vector2(
			(cell.x - center_offset.x) * (piece_cell_size + PIECE_GAP),
			(cell.y - center_offset.y) * (piece_cell_size + PIECE_GAP)
		)
		var rect: Rect2 = Rect2(
			cell_pos - Vector2(piece_cell_size, piece_cell_size) / 2.0,
			Vector2(piece_cell_size, piece_cell_size)
		)
		if rect.has_point(position):
			return true

	return false


func _end_drag() -> void:
	if not dragging:
		return

	if selected_piece >= 0:
		if _hold_box_rect().has_point(drag_position):
			_use_hold()
			return

		if preview_cell.x >= 0 and preview_cell.y >= 0 and preview_cell.x < BOARD_SIZE and preview_cell.y < BOARD_SIZE:
			var piece: Dictionary = pieces[selected_piece]
			var shape: Array = piece["shape"]

			if _can_place(shape, preview_cell):
				_vibrate(25)
				_place_piece(shape, preview_cell, piece["color"])
				_play_sfx("place")

				var added_score: int = shape.size()
				score += added_score

				if score > high_score:
					high_score = score
					_save_highscore()

				var spawn_pos: Vector2 = _cell_position(preview_cell)
				_spawn_floating_text("+" + str(added_score), spawn_pos, Color("#2ECC71"))

				if piece.get("is_bomb", false):
					var bomb_offset: Vector2i = shape[piece["bomb_idx"]]
					var bomb_cell: Vector2i = preview_cell + bomb_offset
					await _explode_bomb(bomb_cell)

				pieces[selected_piece] = _random_piece()
				can_hold = true

				_clear_lines()

	dragging = false
	selected_piece = -1
	preview_cell = Vector2i(-1, -1)
	queue_redraw()


func _explode_bomb(center_cell: Vector2i) -> void:
	Input.vibrate_handheld(80)
	_shake_screen(12.0)
	_play_sfx("bomb")

	var cells_to_clear: Array[Vector2i] = []

	# Весь горизонтальный ряд
	for x in range(BOARD_SIZE):
		cells_to_clear.append(Vector2i(x, center_cell.y))

	# Весь вертикальный ряд
	for y in range(BOARD_SIZE):
		var cell := Vector2i(center_cell.x, y)
		if not cell in cells_to_clear:
			cells_to_clear.append(cell)

	var exploded_count: int = 0

	# Считаем очки заранее, но сами клетки удаляем после анимации.
	for cell in cells_to_clear:
		if cell.x >= 0 and cell.x < BOARD_SIZE and cell.y >= 0 and cell.y < BOARD_SIZE:
			if board[cell.y][cell.x] != -1:
				exploded_count += 1

	var bomb_points: int = exploded_count * 15 + 50
	score += bomb_points

	if score > high_score:
		high_score = score
		_save_highscore()

	var bomb_pos: Vector2 = _cell_position(center_cell)

	_spawn_floating_text(
		"ВЗРЫВ! +" + str(bomb_points),
		bomb_pos,
		Color("#FF3366")
	)

	# Волна идёт от центра бомбы по четырём направлениям.
	# Каждая следующая клетка начинает исчезать чуть позже предыдущей.
	var wave_tween: Tween = create_tween()
	var max_distance: int = BOARD_SIZE - 1

	for distance in range(max_distance + 1):
		var wave_cells: Array[Vector2i] = []

		if distance == 0:
			wave_cells.append(center_cell)
		else:
			wave_cells.append(center_cell + Vector2i(-distance, 0))
			wave_cells.append(center_cell + Vector2i(distance, 0))
			wave_cells.append(center_cell + Vector2i(0, -distance))
			wave_cells.append(center_cell + Vector2i(0, distance))

		wave_tween.set_parallel(true)

		for cell in wave_cells:
			if cell.x >= 0 and cell.x < BOARD_SIZE and cell.y >= 0 and cell.y < BOARD_SIZE:
				if board[cell.y][cell.x] != -1:
					clearing_cells[cell] = 1.0
					var c_color: Color = colors[board[cell.y][cell.x]]
					_spawn_particles(
						_cell_position(cell) + Vector2(cell_size / 2.0, cell_size / 2.0),
						c_color
					)

					wave_tween.tween_method(func(val: float):
						clearing_cells[cell] = val
						queue_redraw()
					, 1.0, 0.0, 0.20)

		wave_tween.set_parallel(false)
		if distance < max_distance:
			wave_tween.tween_interval(0.045)

	await wave_tween.finished

	# После завершения волны окончательно удаляем клетки.
	for cell in cells_to_clear:
		if cell.x >= 0 and cell.x < BOARD_SIZE and cell.y >= 0 and cell.y < BOARD_SIZE:
			board[cell.y][cell.x] = -1
			clearing_cells.erase(cell)

	# Если бомба полностью очистила поле — переходим к следующему этапу космоса.
	if _is_board_empty():
		_advance_space_stage()

	queue_redraw()


func _can_place(shape: Array, start: Vector2i) -> bool:
	for cell: Vector2i in shape:
		var x: int = start.x + cell.x
		var y: int = start.y + cell.y

		if x < 0 or x >= BOARD_SIZE or y < 0 or y >= BOARD_SIZE:
			return false
		if board[y][x] != -1:
			return false

	return true


func _place_piece(shape: Array, start: Vector2i, color: Color) -> void:
	var color_index: int = colors.find(color)
	for cell: Vector2i in shape:
		var x: int = start.x + cell.x
		var y: int = start.y + cell.y
		board[y][x] = color_index


func _clear_lines() -> void:
	var rows_to_clear: Array[int] = []
	var cols_to_clear: Array[int] = []

	for row in range(BOARD_SIZE):
		var full: bool = true
		for col in range(BOARD_SIZE):
			if board[row][col] == -1:
				full = false
				break
		if full:
			rows_to_clear.append(row)

	for col in range(BOARD_SIZE):
		var full: bool = true
		for row in range(BOARD_SIZE):
			if board[row][col] == -1:
				full = false
				break
		if full:
			cols_to_clear.append(col)

	var total_cleared: int = rows_to_clear.size() + cols_to_clear.size()
	if total_cleared == 0:
		_check_game_over()
		return

	_vibrate(80)
	_play_sfx("clear")

	var cells_to_animate: Array[Vector2i] = []
	for row in rows_to_clear:
		for col in range(BOARD_SIZE):
			var c: Vector2i = Vector2i(col, row)
			if not c in cells_to_animate:
				cells_to_animate.append(c)

	for col in cols_to_clear:
		for row in range(BOARD_SIZE):
			var c: Vector2i = Vector2i(col, row)
			if not c in cells_to_animate:
				cells_to_animate.append(c)

	var combo_mult: int = total_cleared
	var points: int = total_cleared * 10 * combo_mult
	score += points

	if score > high_score:
		high_score = score
		_save_highscore()

	_shake_screen(5.0 * total_cleared)

	var clear_center: Vector2 = _cell_position(cells_to_animate[0])
	if total_cleared > 1:
		_spawn_floating_text("COMBO x" + str(combo_mult) + "!\n+" + str(points), clear_center, Color("#FFD966"))
	else:
		_spawn_floating_text("+" + str(points), clear_center, Color("#FFB020"))

	var tween: Tween = create_tween().set_parallel(true)
	for c in cells_to_animate:
		clearing_cells[c] = 1.0
		var c_color: Color = colors[board[c.y][c.x]] if board[c.y][c.x] != -1 else Color.WHITE
		_spawn_particles(_cell_position(c) + Vector2(cell_size / 2.0, cell_size / 2.0), c_color)

		tween.tween_method(func(val: float):
			clearing_cells[c] = val
			queue_redraw()
		, 1.0, 0.0, 0.22)

	tween.chain().tween_callback(func():
		for c in cells_to_animate:
			board[c.y][c.x] = -1
			clearing_cells.erase(c)
		if _is_board_empty():
			_advance_space_stage()
		_check_game_over()
		queue_redraw()
	)


func _spawn_particles(pos: Vector2, color: Color) -> void:
	var particles: CPUParticles2D = CPUParticles2D.new()
	particles.position = pos
	particles.emitting = true
	particles.one_shot = true
	particles.amount = 18
	particles.lifetime = 0.5
	particles.explosiveness = 0.9
	particles.spread = 180.0
	particles.gravity = Vector2(0, 320)
	particles.initial_velocity_min = 90.0
	particles.initial_velocity_max = 170.0
	particles.scale_amount_min = 4.0
	particles.scale_amount_max = 9.0
	particles.color = color

	add_child(particles)

	var timer: SceneTreeTimer = get_tree().create_timer(0.6)
	timer.timeout.connect(particles.queue_free)


func _shake_screen(intensity: float = 6.0) -> void:
	var tween: Tween = create_tween()
	for i in range(4):
		var rand_offset: Vector2 = Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity))
		tween.tween_property(self, "camera_offset", rand_offset, 0.03)
	tween.tween_property(self, "camera_offset", Vector2.ZERO, 0.03)


func _spawn_floating_text(text: String, global_pos: Vector2, color: Color = Color.WHITE) -> void:
	var label: Label = Label.new()
	label.text = text
	label.position = global_pos
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", 26)
	label.z_index = 100
	add_child(label)

	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 60.0, 0.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.65).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(label.queue_free)


func _check_game_over() -> void:
	for piece in pieces:
		if piece.is_empty():
			continue
		var shape: Array = piece["shape"]
		for row in range(BOARD_SIZE):
			for col in range(BOARD_SIZE):
				if _can_place(shape, Vector2i(col, row)):
					return

	if can_hold:
		if not hold_piece.is_empty():
			var shape: Array = hold_piece["shape"]
			for row in range(BOARD_SIZE):
				for col in range(BOARD_SIZE):
					if _can_place(shape, Vector2i(col, row)):
						return
		else:
			return

	is_game_over = true
	_play_sfx("game_over")
	queue_redraw()


func _restart_game() -> void:
	score = 0
	is_game_over = false
	hold_piece = {}
	can_hold = true
	_create_board()
	_create_pieces()
	queue_redraw()


func _is_board_empty() -> bool:
	for row in board:
		for value in row:
			if value != -1:
				return false
	return true


func _load_space_stage() -> void:
	space_stage = clampi(space_stage, 0, SPACE_NAMES.size() - 1)
	space_title = SPACE_NAMES[space_stage]
	space_background = load(SPACE_PATHS[space_stage]) as Texture2D
	space_transition = 1.0


func _advance_space_stage() -> void:
	space_stage = min(space_stage + 1, SPACE_NAMES.size() - 1)
	space_title = SPACE_NAMES[space_stage]
	var next_background := load(SPACE_PATHS[space_stage]) as Texture2D
	if next_background:
		space_background = next_background
	else:
		# Пока отдельная фотография этапа не добавлена, оставляем космический фон.
		space_background = load(SPACE_PATHS[0]) as Texture2D
	space_transition = 0.0
	_save_settings()


func _save_highscore() -> void:
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_32(high_score)


func _load_highscore() -> int:
	if FileAccess.file_exists(SAVE_PATH):
		var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file:
			return file.get_32()
	return 0


func _play_sfx(type: String) -> void:
	if not sound_enabled:
		return

	var sample_rate: int = 22050
	var bytes: PackedByteArray = PackedByteArray()
	var duration: float = 0.12

	if type == "select":
		$SelectSound.play()
		return

	elif type == "place":
		$PlaceSound.play()
		return

	elif type == "clear":
		$ClearSound.play()
		return

	elif type == "bomb":
		$BombSound.play()
		return

	elif type == "game_over":
		$GameoverSound.play()
		return

	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = sample_rate
	stream.data = bytes

	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.stream = stream
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)


func _vibrate(duration_ms: int) -> void:
	if vibration_enabled:
		Input.vibrate_handheld(duration_ms)

func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		sound_enabled = bool(cfg.get_value("audio", "sound", true))
		music_enabled = bool(cfg.get_value("audio", "music", true))
		vibration_enabled = bool(cfg.get_value("audio", "vibration", true))
		space_stage = int(cfg.get_value("progress", "space_stage", 0))

func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "sound", sound_enabled)
	cfg.set_value("audio", "music", music_enabled)
	cfg.set_value("audio", "vibration", vibration_enabled)
	cfg.set_value("progress", "space_stage", space_stage)
	cfg.save(SETTINGS_PATH)

func _apply_settings() -> void:
	for node_name in ["PlaceSound", "ClearSound", "BombSound", "GameoverSound", "SelectSound"]:
		if has_node(node_name):
			var player := get_node(node_name) as AudioStreamPlayer
			player.volume_db = 0.0 if sound_enabled else -80.0
	_apply_music()


# Включает или выключает фоновую музыку в зависимости от настройки.
# Раньше кнопка "🎵" только сохраняла флаг, а узел GameMusic продолжал играть,
# поэтому звук не отключался.
func _apply_music() -> void:
	if music_player == null:
		music_player = get_node_or_null("GameMusic") as AudioStreamPlayer
	if music_player == null:
		return

	if music_player.stream is AudioStreamOggVorbis:
		# В .import файла loop=false, из-за чего трек заканчивался и тишина
		# оставалась до конца партии. Включаем зацикливание прямо в коде.
		(music_player.stream as AudioStreamOggVorbis).loop = true

	if music_enabled and not _app_paused:
		if not music_player.playing:
			music_player.play()
	else:
		if music_player.playing:
			music_player.stop()


# На телефоне при сворачивании приложения музыка ставится на паузу,
# а при возврате продолжает играть, если она включена в настройках.
# NOTIFICATION_APPLICATION_FOCUS_* — это те же значения, что и
# NOTIFICATION_WM_WINDOW_FOCUS_*, поэтому обрабатываем их один раз.
func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			_app_paused = true
			_apply_music()
		NOTIFICATION_APPLICATION_FOCUS_IN:
			_app_paused = false
			_apply_music()

func _make_button_style(bg: Color, border: Color, radius: int = 16) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.set_corner_radius_all(radius)
	style.set_border_width_all(2)
	style.border_color = border
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	return style

func _make_toggle_style(bg: Color, border: Color, radius: int = 18) -> StyleBoxFlat:
	return _make_button_style(bg, border, radius)

func _style_settings_button(btn: Button, bg: Color = Color("#24324F"), hover: Color = Color("#31508A")) -> void:
	btn.add_theme_font_size_override("font_size", 22)
	btn.add_theme_color_override("font_color", Color("#F8FAFC"))
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_stylebox_override("normal", _make_button_style(bg, Color("#4C83F5")))
	btn.add_theme_stylebox_override("hover", _make_button_style(hover, Color("#8DB4FF")))
	btn.add_theme_stylebox_override("pressed", _make_button_style(Color("#18253D"), Color("#FF5252")))
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

func _style_toggle_button(btn: CheckButton, enabled: bool) -> void:
	var border := Color("#FF5252") if enabled else Color("#4C83F5")
	var hover_border := Color("#FF7A7A") if enabled else Color("#8DB4FF")
	btn.add_theme_font_size_override("font_size", 54)
	btn.add_theme_color_override("font_color", Color("#F8FAFC"))
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_stylebox_override("normal", _make_toggle_style(Color("#1A2742"), border, 20))
	btn.add_theme_stylebox_override("hover", _make_toggle_style(Color("#263B62"), hover_border, 20))
	btn.add_theme_stylebox_override("pressed", _make_toggle_style(Color("#202D48"), Color("#FF5252"), 20))
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

func _create_settings_ui() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "SettingsCanvas"
	canvas.layer = 50
	add_child(canvas)

	gear_button = Button.new()
	gear_button.name = "SettingsGear"
	gear_button.text = "⚙"
	gear_button.tooltip_text = "Настройки"
	gear_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	gear_button.offset_left = -122.0
	gear_button.offset_top = 170.0
	gear_button.offset_right = -26.0
	gear_button.offset_bottom = 266.0
	_style_settings_button(gear_button, Color("#17223A"), Color("#2A416F"))
	gear_button.add_theme_font_size_override("font_size", 58)
	canvas.add_child(gear_button)
	gear_button.pressed.connect(_open_settings)

	settings_root = Control.new()
	settings_root.name = "SettingsOverlay"
	settings_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	settings_root.mouse_filter = Control.MOUSE_FILTER_STOP
	settings_root.visible = false
	canvas.add_child(settings_root)

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.01, 0.02, 0.06, 0.78)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	settings_root.add_child(dim)

	settings_panel = Panel.new()
	settings_panel.name = "SettingsPanel"
	settings_panel.size = Vector2(600, 700)
	settings_panel.position = Vector2(-300, -350)
	settings_panel.set_anchors_preset(Control.PRESET_CENTER)
	settings_panel.add_theme_stylebox_override("panel", _make_button_style(Color("#111A2E"), Color("#4C83F5"), 28))
	settings_root.add_child(settings_panel)

	var title := Label.new()
	title.text = "НАСТРОЙКИ"
	title.position = Vector2(25, 28)
	title.size = Vector2(550, 65)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", Color("#E6D6FF"))
	settings_panel.add_child(title)

	var icons := HBoxContainer.new()
	icons.position = Vector2(35, 120)
	icons.size = Vector2(530, 145)
	icons.add_theme_constant_override("separation", 17)
	settings_panel.add_child(icons)

	sound_button = CheckButton.new()
	sound_button.text = "🔊"
	sound_button.custom_minimum_size = Vector2(165, 135)
	sound_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_toggle_button(sound_button, sound_enabled)
	icons.add_child(sound_button)
	sound_button.toggled.connect(_on_sound_toggled)

	music_button = CheckButton.new()
	music_button.text = "🎵"
	music_button.custom_minimum_size = Vector2(165, 135)
	music_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_toggle_button(music_button, music_enabled)
	icons.add_child(music_button)
	music_button.toggled.connect(_on_music_toggled)

	vibration_button = CheckButton.new()
	vibration_button.text = "📳"
	vibration_button.custom_minimum_size = Vector2(165, 135)
	vibration_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_toggle_button(vibration_button, vibration_enabled)
	icons.add_child(vibration_button)
	vibration_button.toggled.connect(_on_vibration_toggled)

	var play := Button.new()
	play.text = "▶  ПРОДОЛЖИТЬ"
	play.position = Vector2(60, 315)
	play.size = Vector2(480, 72)
	_style_settings_button(play, Color("#2ECC71"), Color("#3BE47E"))
	play.add_theme_color_override("font_color", Color("#07140B"))
	play.add_theme_font_size_override("font_size", 25)
	settings_panel.add_child(play)
	play.pressed.connect(_close_settings)

	var restart := Button.new()
	restart.text = "↻  ЗАНОВО"
	restart.position = Vector2(60, 405)
	restart.size = Vector2(480, 72)
	_style_settings_button(restart, Color("#24324F"), Color("#31508A"))
	restart.add_theme_font_size_override("font_size", 25)
	settings_panel.add_child(restart)
	restart.pressed.connect(_restart_from_settings)

	var menu := Button.new()
	menu.text = "⌂  ГЛАВНЫЙ МЕНЮ"
	menu.position = Vector2(60, 495)
	menu.size = Vector2(480, 72)
	_style_settings_button(menu)
	menu.add_theme_font_size_override("font_size", 25)
	settings_panel.add_child(menu)
	menu.pressed.connect(_go_to_main_menu)

	var exit := Button.new()
	exit.text = "✕  ВЫХОД"
	exit.position = Vector2(60, 585)
	exit.size = Vector2(480, 72)
	_style_settings_button(exit, Color("#3A1E2B"), Color("#5A273A"))
	exit.add_theme_font_size_override("font_size", 25)
	settings_panel.add_child(exit)
	exit.pressed.connect(_exit_game)

	var close := Button.new()
	close.text = "×"
	close.position = Vector2(525, 20)
	close.size = Vector2(52, 52)
	_style_settings_button(close, Color("#2A1D2B"), Color("#4A2940"))
	close.add_theme_font_size_override("font_size", 32)
	settings_panel.add_child(close)
	close.pressed.connect(_close_settings)

	_update_settings_buttons()

func _update_settings_buttons() -> void:
	if sound_button:
		sound_button.button_pressed = sound_enabled
		_style_toggle_button(sound_button, sound_enabled)
	if music_button:
		music_button.button_pressed = music_enabled
		_style_toggle_button(music_button, music_enabled)
	if vibration_button:
		vibration_button.button_pressed = vibration_enabled
		_style_toggle_button(vibration_button, vibration_enabled)

func _open_settings() -> void:
	settings_open = true
	settings_root.visible = true
	gear_button.visible = false
	_update_settings_buttons()

func _close_settings() -> void:
	settings_open = false
	settings_root.visible = false
	gear_button.visible = true

func _on_sound_toggled(value: bool) -> void:
	sound_enabled = value
	_apply_settings()
	_style_toggle_button(sound_button, sound_enabled)
	_save_settings()

func _on_music_toggled(value: bool) -> void:
	music_enabled = value
	_apply_music()
	_style_toggle_button(music_button, music_enabled)
	_save_settings()

func _on_vibration_toggled(value: bool) -> void:
	vibration_enabled = value
	_style_toggle_button(vibration_button, vibration_enabled)
	_save_settings()

func _restart_from_settings() -> void:
	space_stage = 0
	space_title = SPACE_NAMES[0]
	space_background = load(SPACE_PATHS[0]) as Texture2D
	space_transition = 1.0
	score = 0
	is_game_over = false
	hold_piece = {}
	can_hold = true
	_create_board()
	_create_pieces()
	_save_settings()
	_close_settings()
	queue_redraw()

func _go_to_main_menu() -> void:
	_save_settings()
	get_tree().change_scene_to_file("res://main_menu.tscn")

func _exit_game() -> void:
	_save_settings()
	get_tree().quit()
