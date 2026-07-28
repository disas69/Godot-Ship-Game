shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;

uniform bool use_texture = false;
uniform sampler2D albedo_tex : source_color, filter_linear, repeat_disable;
uniform vec4 tint_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float intensity = 1.0;
uniform float radial_scroll_speed = 0.35;
uniform float radial_tiling = 1.0;

void vertex() {
	VERTEX.y += 0.02;
}

void fragment() {
	vec2 centered_uv = UV - vec2(0.5);
	float radius = length(centered_uv);
	float radial_coord = radius * 2.0;
	float safe_radius = max(radius, 0.0001);
	vec2 direction = centered_uv / safe_radius;
	float scrolled_radial_coord = fract(radial_coord * radial_tiling - TIME * radial_scroll_speed) / max(radial_tiling, 0.0001);
	vec2 scrolled_uv = vec2(0.5) + direction * scrolled_radial_coord * 0.5;

	vec4 mask = use_texture ? texture(albedo_tex, UV) : vec4(1.0);
	vec4 base = use_texture ? texture(albedo_tex, scrolled_uv) : vec4(1.0);

	ALBEDO = clamp(base.rgb * tint_color.rgb * intensity, vec3(0.0), vec3(1.0));
	ALPHA = base.a * mask.a * tint_color.a;
}
