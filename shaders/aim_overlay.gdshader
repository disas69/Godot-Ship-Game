shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;

uniform bool use_texture = false;
uniform sampler2D albedo_tex : source_color, filter_linear, repeat_disable;
uniform vec4 tint_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float intensity = 1.0;

void vertex() {
	VERTEX.y += 0.02;
}

void fragment() {
	vec4 base = use_texture ? texture(albedo_tex, UV) : vec4(1.0);
	ALBEDO = clamp(base.rgb * tint_color.rgb * intensity, vec3(0.0), vec3(1.0));
	ALPHA = base.a * tint_color.a;
}
