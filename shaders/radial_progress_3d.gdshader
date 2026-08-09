shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 fill_color : source_color = vec4(1.0, 1.0, 1.0, 0.9);
uniform vec4 background_color : source_color = vec4(0.0, 0.0, 0.0, 0.35);
uniform float inner_radius : hint_range(0.0, 1.0) = 0.58;
uniform float outer_radius : hint_range(0.0, 1.0) = 0.95;
uniform float edge_softness : hint_range(0.0, 0.1) = 0.02;

void vertex() {
	VERTEX.y += 0.02;
}

void fragment() {
	vec2 centered_uv = UV - vec2(0.5);
	float radius = length(centered_uv) * 2.0;
	float outer_mask = 1.0 - smoothstep(outer_radius, outer_radius + edge_softness, radius);
	float inner_mask = smoothstep(inner_radius - edge_softness, inner_radius, radius);
	float ring_mask = outer_mask * inner_mask;

	float angle = atan(centered_uv.y, centered_uv.x);
	float normalized_angle = fract((-angle - PI / 2.0) / TAU);
	float fill_mask = step(normalized_angle, progress);
	vec4 color = mix(background_color, fill_color, fill_mask);

	ALBEDO = clamp(color.rgb, vec3(0.0), vec3(1.0));
	ALPHA = color.a * ring_mask;
}
