shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;

uniform vec4 flash_color : source_color = vec4(1.0);
uniform float flash_strength : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	ALBEDO = flash_color.rgb;
	ALPHA = flash_color.a * flash_strength;
}
