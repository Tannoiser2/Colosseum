class_name UI
extends RefCounted
## Helper grafici condivisi. Tema «Anfiteatro Flavio»: il travertino caldo e la sabbia del tabellone,
## il rosso pompeiano e l'oro delle corone d'alloro, il verde acqua dei mosaici della piazza.
## Caratteri liberi (OFL): Cinzel Decorative per il titolo e Cinzel per le intestazioni (le capitali
## romane delle tessere Spettacolo), EB Garamond per i testi.

const D = preload("res://scripts/data/cs_data.gd")

const BG := Color("#1c130d")
const BG_L := Color("#2b1d13")
const PANEL := Color("#2a1c12")
const PANEL_L := Color("#3b2a1c")
const STONE := Color("#e8dcc2")
const STONE_D := Color("#cdbb98")
const SAND := Color("#d9b98a")
const GOLD := Color("#d9a441")
const GOLD_L := Color("#f3cf72")
const TERRA := Color("#b5502f")
const TERRA_D := Color("#7a2f1a")
const TEAL := Color("#3f8f8a")
const TEAL_L := Color("#7cc4bd")
const INK := Color("#2b1a10")
const TEXT := Color("#f3e9d2")
const MUTED := Color("#a8957a")
const RED := Color("#d2492f")
const GREEN := Color("#8fbf5a")
const PURPLE := Color("#5a4fa0")

static var _tex := {}
static var font_title: Font
static var font_head: Font
static var font_head_r: Font
static var font_body: Font
static var font_semi: Font
static var font_bold: Font
static var font_italic: Font


static func _var(path: String, w: int) -> Font:
	var base: FontFile = load(path)
	var fv := FontVariation.new()
	fv.base_font = base
	var tag := TextServerManager.get_primary_interface().name_to_tag("wght")
	fv.variation_opentype = {tag: w}
	return fv


static func init_fonts() -> void:
	if font_title != null:
		return
	font_title = load("res://assets/fonts/CinzelDecorative-Bold.ttf")
	font_head = _var("res://assets/fonts/Cinzel.ttf", 700)
	font_head_r = _var("res://assets/fonts/Cinzel.ttf", 500)
	font_body = _var("res://assets/fonts/EBGaramond.ttf", 450)
	font_semi = _var("res://assets/fonts/EBGaramond.ttf", 600)
	font_bold = _var("res://assets/fonts/EBGaramond.ttf", 750)
	font_italic = _var("res://assets/fonts/EBGaramond-Italic.ttf", 500)


static func tex(path: String) -> Texture2D:
	if not _tex.has(path):
		_tex[path] = load(path) if ResourceLoader.exists(path) else null
	return _tex[path]


static func tile_tex(t: String) -> Texture2D:
	return tex("res://assets/artisti/%s.png" % t)


static func star_tex(t: String) -> Texture2D:
	return tex("res://assets/stelle/%s.png" % t)


static func spect_tex(id: String, art := false) -> Texture2D:
	return tex("res://assets/spettacoli/%s_%s.jpg" % [id, "arte" if art else "piano"])


static func pcolor(e, p: int) -> Color:
	return D.COLORS[e.pcol(p)]["col"]


static func pdark(e, p: int) -> Color:
	return D.COLORS[e.pcol(p)]["dark"]


static func wreath_tex(e, p: int) -> Texture2D:
	return tex("res://assets/segnalini/corona_%s.png" % D.COLORS[e.pcol(p)]["key"])


static func panel_style(bg: Color, border: Color = GOLD, bw := 2, radius := 6) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(12)
	return sb


static func dark_style(radius := 8, alpha := 0.95) -> StyleBoxFlat:
	var sb := panel_style(Color(PANEL, alpha), Color(GOLD, 0.75), 2, radius)
	sb.shadow_color = Color(0, 0, 0, 0.55)
	sb.shadow_size = 10
	return sb


## pergamena chiara, come il fondo delle tessere
static func stone_style(radius := 6) -> StyleBoxFlat:
	var sb := panel_style(STONE, Color(TERRA_D, 0.9), 2, radius)
	sb.set_content_margin_all(10)
	return sb


static func label(text: String, size := 20, col := TEXT, font: Font = null) -> Label:
	init_fonts()
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if font != null:
		l.add_theme_font_override("font", font)
	return l


## titolo come il logo: oro con ombra scura
static func title(text: String, size := 48, col := GOLD_L) -> Label:
	init_fonts()
	var l := label(text, size, col, font_title)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("shadow_offset_x", maxi(2, size / 20))
	l.add_theme_constant_override("shadow_offset_y", maxi(2, size / 16))
	return l


static func heading(text: String, size := 22, col := GOLD_L) -> Label:
	init_fonts()
	return label(text, size, col, font_head)


static func wrap(l: Label, w: float) -> Label:
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = w
	return l


static func icon_rect(t: Texture2D, sz: Vector2) -> TextureRect:
	var r := TextureRect.new()
	r.texture = t
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = sz
	r.size = sz
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


static func button(text: String, w := 200.0, h := 46.0, size := 20) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(w, h)
	b.add_theme_font_size_override("font_size", size)
	return b


static func primary(b: Button) -> Button:
	init_fonts()
	b.add_theme_stylebox_override("normal", _btn(TERRA, GOLD))
	b.add_theme_stylebox_override("hover", _btn(Color("#cc6440"), GOLD_L))
	b.add_theme_stylebox_override("pressed", _btn(GOLD, INK))
	b.add_theme_stylebox_override("disabled", _btn(Color("#4a352a"), Color("#2a1e18")))
	b.add_theme_color_override("font_color", STONE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", INK)
	b.add_theme_font_override("font", font_head)
	return b


static func _btn(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(5)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 3
	sb.content_margin_bottom = 5
	return sb


static func make_theme() -> Theme:
	init_fonts()
	var th := Theme.new()
	th.default_font = font_semi
	th.default_font_size = 21
	var sb := _btn(Color("#3a2819"), Color("#8a6a3a"))
	th.set_stylebox("normal", "Button", sb)
	th.set_stylebox("hover", "Button", _btn(Color("#4c3520"), GOLD))
	th.set_stylebox("pressed", "Button", _btn(GOLD, GOLD_L))
	th.set_stylebox("disabled", "Button", _btn(Color("#24180f"), Color("#3a2c1e")))
	th.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	th.set_color("font_color", "Button", TEXT)
	th.set_color("font_hover_color", "Button", GOLD_L)
	th.set_color("font_pressed_color", "Button", INK)
	th.set_color("font_hover_pressed_color", "Button", INK)
	th.set_color("font_disabled_color", "Button", Color("#6b5a46"))
	th.set_font("font", "Button", font_semi)
	th.set_font_size("font_size", "Button", 21)
	th.set_color("font_color", "Label", TEXT)
	var pn := StyleBoxFlat.new()
	pn.bg_color = PANEL
	th.set_stylebox("panel", "Panel", pn)
	th.set_stylebox("panel", "PanelContainer", pn)
	th.set_font("normal_font", "RichTextLabel", font_body)
	th.set_font("bold_font", "RichTextLabel", font_bold)
	th.set_font("italics_font", "RichTextLabel", font_italic)
	th.set_font("mono_font", "RichTextLabel", font_head_r)
	for k in ["normal_font_size", "bold_font_size", "italics_font_size", "mono_font_size"]:
		th.set_font_size(k, "RichTextLabel", 21)
	th.set_color("default_color", "RichTextLabel", TEXT)
	th.set_font("font", "LineEdit", font_semi)
	th.set_font_size("font_size", "LineEdit", 24)
	th.set_color("font_color", "LineEdit", INK)
	th.set_color("font_placeholder_color", "LineEdit", Color("#8a7a62"))
	th.set_color("caret_color", "LineEdit", INK)
	th.set_stylebox("normal", "LineEdit", panel_style(STONE, TERRA_D, 2, 4))
	th.set_stylebox("focus", "LineEdit", panel_style(Color("#fff6df"), GOLD, 2, 4))
	th.set_font("font", "TooltipLabel", font_body)
	th.set_font_size("font_size", "TooltipLabel", 19)
	th.set_color("font_color", "TooltipLabel", INK)
	var tp := panel_style(STONE, TERRA_D, 2, 4)
	tp.set_content_margin_all(8)
	th.set_stylebox("panel", "TooltipPanel", tp)
	var sc := StyleBoxFlat.new()
	sc.bg_color = Color(GOLD, 0.85)
	sc.set_corner_radius_all(3)
	for k in ["grabber", "grabber_highlight", "grabber_pressed"]:
		th.set_stylebox(k, "VScrollBar", sc)
		th.set_stylebox(k, "HSlider", sc)
	var sct := StyleBoxFlat.new()
	sct.bg_color = Color(1, 1, 1, 0.06)
	th.set_stylebox("scroll", "VScrollBar", sct)
	var sl := StyleBoxFlat.new()
	sl.bg_color = Color(TERRA_D, 0.8)
	sl.content_margin_top = 4
	sl.content_margin_bottom = 4
	th.set_stylebox("slider", "HSlider", sl)
	return th


## Sfondo: travertino scuro con il fregio a meandro in alto e in basso (disegnato, nessuna immagine).
class Backdrop extends Control:
	var frieze := true

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		resized.connect(queue_redraw)

	func _draw() -> void:
		var n := 24
		for i in n:
			var c := UI.BG.lerp(UI.BG_L, sin(PI * float(i) / n) * 0.9)
			draw_rect(Rect2(0, size.y * i / n, size.x, size.y / n + 1), c)
		if frieze:
			for y in [10.0, size.y - 30.0]:
				_meander(y)

	func _meander(y: float) -> void:
		var s := 20.0
		var col := Color(UI.GOLD, 0.16)
		var x := 0.0
		while x < size.x:
			var pts := PackedVector2Array([Vector2(x, y + s), Vector2(x, y), Vector2(x + s, y), Vector2(x + s, y + s * 0.66),
				Vector2(x + s * 0.33, y + s * 0.66), Vector2(x + s * 0.33, y + s * 0.33), Vector2(x + s * 0.66, y + s * 0.33)])
			draw_polyline(pts, col, 2.0)
			draw_line(Vector2(x, y + s), Vector2(x + s * 1.3, y + s), col, 2.0)
			x += s * 1.3
