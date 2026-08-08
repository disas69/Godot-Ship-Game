shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_always, cull_disabled;

uniform vec4 flash_color : source_color = vec4(1.0);
uniform float flash_strength : hint_range(0.0, 1.0) = 0.0;
uniform float alpha_fade : hint_range(0.0, 1.0) = 1.0;

void vertex() {
	VERTEX += NORMAL * 0.001;
}

void fragment() {
	ALBEDO = clamp(flash_color.rgb, vec3(0.0), vec3(1.0));
	ALPHA = flash_color.a * flash_strength * alpha_fade;
}
