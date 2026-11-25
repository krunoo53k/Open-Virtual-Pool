@tool
extends SceneTree

## Dev tool: regenerates resources/ui_theme.theme from the palette below.
## Run: godot --headless --path . --script tools/build_ui_theme.gd

const OUT := "res://resources/ui_theme.theme"
const PALETTE := {
	"felt_deep": "#0B231B",
	"felt": "#123A2B",
	"felt_light": "#1C5440",
	"walnut_deep": "#24160E",
	"walnut": "#3B2417",
	"walnut_light": "#563723",
	"brass": "#D4AF37",
	"brass_dim": "#8C7127",
	"ivory": "#F4EBDD",
	"muted": "#A6B2A7",
	"foul": "#CE6047",
}


func _initialize() -> void:
	var c := {}
	for key in PALETTE.keys():
		c[key] = Color(String(PALETTE[key]))
	var theme := Theme.new()
	var regular: Font = load("res://assets/fonts/BarlowCondensed-Regular.ttf")
	var semibold: Font = load("res://assets/fonts/BarlowCondensed-SemiBold.ttf")

	theme.default_font = regular
	theme.default_font_size = 20

	_standard(theme, c, regular, semibold)
	_variation(theme, "Title", "Label", semibold, 68, c["brass"])
	_variation(theme, "Heading", "Label", semibold, 32, c["brass"])
	_variation(theme, "Caption", "Label", regular, 17, c["muted"])
	_variation(theme, "Status", "Label", semibold, 24, c["ivory"])
	_variation(theme, "GroupTag", "Label", semibold, 22, c["ivory"])

	theme.set_stylebox("panel", "PanelContainer", _panel(c))
	theme.set_color("font_color", "LineEdit", c["ivory"])

	var err := ResourceSaver.save(theme, OUT)
	if err != OK:
		push_error("build_ui_theme: save failed (%d)" % err)
		quit(1)
		return
	print("build_ui_theme: wrote %s" % OUT)
	quit(0)


func _standard(theme: Theme, c: Dictionary, regular: Font, semibold: Font) -> void:
	theme.set_font("font", "Button", semibold)
	theme.set_font_size("font_size", "Button", 26)
	theme.set_color("font_color", "Button", c["ivory"])
	theme.set_color("font_hover_color", "Button", c["brass"])
	theme.set_color("font_pressed_color", "Button", c["felt_deep"])
	theme.set_color("font_disabled_color", "Button", c["muted"])
	theme.set_stylebox("normal", "Button", _button(c["walnut"], c["brass_dim"]))
	theme.set_stylebox("hover", "Button", _button(c["walnut_light"], c["brass"]))
	theme.set_stylebox("pressed", "Button", _button(c["brass"], c["brass"]))
	theme.set_stylebox("focus", "Button", _button(c["walnut_light"], c["brass"], 3))
	theme.set_stylebox("disabled", "Button", _button(c["walnut_deep"], c["walnut_light"]))

	theme.set_font("font", "Label", regular)
	theme.set_font_size("font_size", "Label", 20)
	theme.set_color("font_color", "Label", c["ivory"])

	theme.set_font("font", "OptionButton", semibold)
	theme.set_font_size("font_size", "OptionButton", 22)
	theme.set_color("font_color", "OptionButton", c["ivory"])
	theme.set_color("font_hover_color", "OptionButton", c["brass"])
	theme.set_stylebox("normal", "OptionButton", _button(c["walnut"], c["brass_dim"]))
	theme.set_stylebox("hover", "OptionButton", _button(c["walnut_light"], c["brass"]))
	theme.set_stylebox("focus", "OptionButton", _button(c["walnut_light"], c["brass"], 3))


func _variation(theme: Theme, name: String, base: String, font: Font, size: int, color: Color) -> void:
	theme.set_type_variation(name, base)
	theme.set_font("font", name, font)
	theme.set_font_size("font_size", name, size)
	theme.set_color("font_color", name, color)


func _button(bg: Color, border: Color, width: int = 2) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_border_width_all(width)
	sb.border_color = border
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(10)
	sb.content_margin_left = 18.0
	sb.content_margin_right = 18.0
	return sb


func _panel(c: Dictionary) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(c["walnut_deep"].r, c["walnut_deep"].g, c["walnut_deep"].b, 0.94)
	sb.set_border_width_all(2)
	sb.border_color = c["brass_dim"]
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(18)
	return sb
