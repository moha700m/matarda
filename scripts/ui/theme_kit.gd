extends RefCounted
class_name ThemeKit

const NAVY := Color("0B1220")
const PANEL := Color(0.055, 0.075, 0.12, 0.94)
const ORANGE := Color("FF7A1A")
const CREAM := Color("F4F1EA")
const MUTED := Color("A8B0C2")
const POLICE := Color("2F6FED")
const CRIMINAL := Color("E85D04")

static var _regular: Font
static var _bold: Font

static func font_regular() -> Font:
	if _regular == null:
		_regular = load("res://assets/fonts/IBMPlexSansArabic-Regular.ttf")
	return _regular

static func font_bold() -> Font:
	if _bold == null:
		_bold = load("res://assets/fonts/IBMPlexSansArabic-Bold.ttf")
	return _bold

static func make_theme() -> Theme:
	var theme := Theme.new()
	var regular := font_regular()
	if regular:
		theme.default_font = regular
	theme.default_font_size = 18
	theme.set_color("font_color", "Label", CREAM)
	theme.set_color("font_color", "Button", CREAM)
	theme.set_color("font_color", "LineEdit", CREAM)
	theme.set_color("font_placeholder_color", "LineEdit", MUTED)
	return theme

static func panel() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL
	style.border_color = Color(1, 0.48, 0.1, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(18)
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 18
	style.content_margin_bottom = 18
	return style

static func button_style(filled: bool, hovered: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	if filled:
		style.bg_color = ORANGE.lightened(0.08) if hovered else ORANGE
	else:
		style.bg_color = Color(0.1, 0.13, 0.2, 0.92) if not hovered else Color(0.16, 0.2, 0.3, 0.95)
	style.border_color = ORANGE
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style

static func line_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.045, 0.08, 0.95)
	style.border_color = Color(0.35, 0.42, 0.55)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style

static func style_button(button: Button, filled: bool = false) -> void:
	button.add_theme_stylebox_override("normal", button_style(filled, false))
	button.add_theme_stylebox_override("hover", button_style(filled, true))
	button.add_theme_stylebox_override("pressed", button_style(true, true))
	button.add_theme_stylebox_override("focus", button_style(filled, true))
	button.add_theme_color_override("font_color", Color("1B120C") if filled else CREAM)
	button.add_theme_color_override("font_hover_color", Color("1B120C") if filled else Color("FFFFFF"))
	button.add_theme_font_size_override("font_size", 20)
	if font_bold():
		button.add_theme_font_override("font", font_bold())
	button.custom_minimum_size = Vector2(0, 52)
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	if not button.pressed.is_connected(_click):
		button.pressed.connect(_click)

static func _click() -> void:
	AudioDirector.play("ui_click")

static func make_label(text: String, size: int, center: bool = false, bold: bool = false) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", CREAM)
	if bold and font_bold():
		label.add_theme_font_override("font", font_bold())
	elif font_regular():
		label.add_theme_font_override("font", font_regular())
	label.text_direction = Locale.direction()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if center else (HORIZONTAL_ALIGNMENT_RIGHT if Locale.is_rtl() else HORIZONTAL_ALIGNMENT_LEFT)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label

static func backdrop(parent: Node) -> void:
	var bg := ColorRect.new()
	bg.color = NAVY
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bg)
	var wash := ColorRect.new()
	wash.color = Color(0.95, 0.4, 0.18, 0.16)
	wash.set_anchors_preset(Control.PRESET_FULL_RECT)
	wash.offset_top = 280
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(wash)
	var bar := ColorRect.new()
	bar.color = ORANGE
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_bottom = 6
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bar)
