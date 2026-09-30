class_name PostFX
extends CanvasLayer
## Full-screen post effect (under the HUD): chromatic aberration kick on hits, shockwave
## ripple, red damage vignette that grows as the rift destabilises, and a halftone comic
## texture in the shadows. Everything is driven by three numbers and decays on its own.

const SHADER := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear, repeat_disable;
uniform float aberration = 0.0;
uniform float damage = 0.0;
uniform float halftone = 0.35;
uniform float ripple_t = 1.0;
uniform vec2 ripple_center = vec2(0.5, 0.5);
uniform float time = 0.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 to_c = uv - ripple_center;
	float rd = length(to_c * vec2(1.78, 1.0));
	float ring = exp(-pow((rd - ripple_t * 0.9) * 14.0, 2.0)) * (1.0 - ripple_t);
	uv += normalize(to_c + vec2(0.0001)) * ring * 0.02;
	vec2 dir = uv - vec2(0.5);
	float ab = aberration * 0.012;
	vec3 col;
	col.r = texture(screen_tex, uv + dir * ab).r;
	col.g = texture(screen_tex, uv).g;
	col.b = texture(screen_tex, uv - dir * ab).b;
	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	// halftone dots, strongest in the shadows
	vec2 res = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 g = fract(uv * res / 7.0) - 0.5;
	float dots = smoothstep(0.30 * (1.0 - lum) + 0.05, 0.0, length(g) - 0.15);
	col = mix(col, col * 0.72, dots * halftone * (1.0 - lum));
	// damage vignette
	float v = smoothstep(0.30, 0.95, length(dir) * 1.3);
	vec3 red = vec3(0.85, 0.05, 0.18);
	col = mix(col, red, v * damage * (0.55 + 0.25 * sin(time * 6.0)));
	COLOR = vec4(col, 1.0);
}
"""

var _rect: ColorRect
var _mat: ShaderMaterial
var _aberration := 0.0
var _damage := 0.0
var _damage_target := 0.0
var _ripple := 1.0
var _time := 0.0


func _ready() -> void:
	layer = 5
	var shader := Shader.new()
	shader.code = SHADER
	_mat = ShaderMaterial.new()
	_mat.shader = shader
	_rect = ColorRect.new()
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.material = _mat
	add_child(_rect)
	GameFeel.hit_fx.connect(_on_hit)
	GameFeel.miss_fx.connect(_on_miss)


func _exit_tree() -> void:
	if GameFeel.hit_fx.is_connected(_on_hit):
		GameFeel.hit_fx.disconnect(_on_hit)
	if GameFeel.miss_fx.is_connected(_on_miss):
		GameFeel.miss_fx.disconnect(_on_miss)


func reset() -> void:
	_aberration = 0.0
	_damage = 0.0
	_damage_target = 0.0
	_ripple = 1.0
	_apply()


## 0..1: how hurt the player is (drives the red vignette).
func set_damage(v: float) -> void:
	_damage_target = v


func kick(amount: float) -> void:
	_aberration = maxf(_aberration, amount * Settings.motion_scale())


func shock(screen_pos01: Vector2) -> void:
	if Settings.reduced_background:
		return
	_ripple = 0.0
	_mat.set_shader_parameter("ripple_center", screen_pos01)


func _on_hit(rating: int, _lane: int, _pos: Vector2, prof: Dictionary) -> void:
	kick(0.9 if rating == GameFeel.Rating.PERFECT else 0.35)


func _on_miss(_lane: int, _pos: Vector2) -> void:
	kick(1.3)


func _process(delta: float) -> void:
	_time += delta
	_aberration = maxf(_aberration - delta * 4.0, 0.0)
	_ripple = minf(_ripple + delta * 1.6, 1.0)
	_damage = lerpf(_damage, _damage_target, clampf(delta * 3.0, 0.0, 1.0))
	_apply()


func _apply() -> void:
	_rect.visible = Settings.post_effects
	_mat.set_shader_parameter("aberration", _aberration)
	_mat.set_shader_parameter("damage", _damage * (0.6 if Settings.reduced_animation else 1.0))
	_mat.set_shader_parameter("ripple_t", _ripple)
	_mat.set_shader_parameter("halftone", 0.15 if Settings.reduced_background else 0.4)
	_mat.set_shader_parameter("time", _time)
