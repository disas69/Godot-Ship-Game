class_name GameButton extends UiTweenButton

const TEX_GREY = preload("res://assets/ui_pirate/button_wood_normal.png")
const TEX_RED = preload("res://assets/ui_pirate/button_red_normal.png")

@export var label: String = "Button":
	set(value):
		label = value
		text = value

@export_enum("Positive", "Negative", "Primary", "Danger", "Neutral") var button_type: String = "Positive":
	set(value):
		button_type = value
		apply_button_style()


func _ready() -> void:
	text = label
	silent = false
	if hover_sfx_key.is_empty():
		hover_sfx_key = "ui_hover"
	if press_sfx_key.is_empty():
		press_sfx_key = "ui_click"
	apply_button_style()
	super._ready()



func apply_button_style() -> void:
	var tex: Texture2D = TEX_GREY
	var font_col := Color(0.98, 0.92, 0.78, 1)
	var mod_normal := Color(1, 1, 1, 1)

	match button_type:
		"Danger", "Negative":
			tex = TEX_RED
			mod_normal = Color(1, 1, 1, 1)
			font_col = Color(1.0, 0.88, 0.82, 1)
		_:
			tex = TEX_GREY
			mod_normal = Color(1, 1, 1, 1)
			font_col = Color(0.98, 0.92, 0.78, 1)

	var sb_normal := StyleBoxTexture.new()
	sb_normal.texture = tex
	sb_normal.texture_margin_left = 14.0
	sb_normal.texture_margin_top = 12.0
	sb_normal.texture_margin_right = 14.0
	sb_normal.texture_margin_bottom = 12.0
	sb_normal.modulate_color = mod_normal

	var sb_hover := StyleBoxTexture.new()
	sb_hover.texture = tex
	sb_hover.texture_margin_left = 14.0
	sb_hover.texture_margin_top = 12.0
	sb_hover.texture_margin_right = 14.0
	sb_hover.texture_margin_bottom = 12.0
	sb_hover.modulate_color = Color(minf(mod_normal.r * 1.15, 1.0), minf(mod_normal.g * 1.15, 1.0), minf(mod_normal.b * 1.15, 1.0), mod_normal.a)

	var sb_pressed := StyleBoxTexture.new()
	sb_pressed.texture = tex
	sb_pressed.texture_margin_left = 14.0
	sb_pressed.texture_margin_top = 12.0
	sb_pressed.texture_margin_right = 14.0
	sb_pressed.texture_margin_bottom = 12.0
	sb_pressed.modulate_color = Color(mod_normal.r * 0.85, mod_normal.g * 0.85, mod_normal.b * 0.85, mod_normal.a)

	var sb_disabled := StyleBoxTexture.new()
	sb_disabled.texture = tex
	sb_disabled.texture_margin_left = 14.0
	sb_disabled.texture_margin_top = 12.0
	sb_disabled.texture_margin_right = 14.0
	sb_disabled.texture_margin_bottom = 12.0
	sb_disabled.modulate_color = Color(mod_normal.r * 0.6, mod_normal.g * 0.6, mod_normal.b * 0.6, 0.6)

	add_theme_stylebox_override("normal", sb_normal)
	add_theme_stylebox_override("hover", sb_hover)
	add_theme_stylebox_override("pressed", sb_pressed)
	add_theme_stylebox_override("disabled", sb_disabled)

	add_theme_color_override("font_color", font_col)
	add_theme_color_override("font_hover_color", font_col)
	add_theme_color_override("font_pressed_color", font_col)
	add_theme_color_override("font_focus_color", font_col)
	add_theme_color_override("font_disabled_color", Color(font_col.r, font_col.g, font_col.b, 0.55))
	add_theme_color_override("font_outline_color", Color(0.12, 0.06, 0.02, 1))
	add_theme_constant_override("outline_size", 5)


