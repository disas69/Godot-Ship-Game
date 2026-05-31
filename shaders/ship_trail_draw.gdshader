shader_type spatial;

render_mode unshaded, world_vertex_coords, cull_disabled, blend_mix, depth_draw_never;

uniform sampler2D foam_noise : repeat_enable, hint_default_white;
uniform sampler2D color_ramp : repeat_disable, source_color, hint_default_white;
uniform sampler2D width_curve : repeat_disable, hint_default_white;
uniform vec4 foam_color : source_color = vec4(1.0);
uniform float opacity : hint_range(0.0, 1.0) = 1.0;

varying float trail_progress;
varying vec2 trail_uv;
varying vec2 clip_overlap;
varying vec2 mesh_uv;

void vertex() {
	mesh_uv = UV;

	mat4 trail_transform = MODEL_MATRIX;
	vec3 left_previous = mix(trail_transform[1].xyz, trail_transform[0].xyz, UV.x);
	vec3 right_previous = mix(trail_transform[2].xyz, trail_transform[3].xyz, UV.x);

	UV.x = (UV.x + INSTANCE_CUSTOM.w - 3.0) / max(INSTANCE_CUSTOM.z - 1.0, 1.0);
	trail_progress = clamp(UV.x, 0.0, 1.0);

	float width = textureLod(width_curve, vec2(trail_progress, 0.0), 0.0).r;
	VERTEX = mix(left_previous, right_previous, (UV.y - 0.5) * width + 0.5);

	trail_uv = vec2(trail_progress, UV.y);

	clip_overlap.x = dot(
		VERTEX - INV_VIEW_MATRIX[3].xyz,
		cross(trail_transform[1].xyz - INV_VIEW_MATRIX[3].xyz, trail_transform[2].xyz - INV_VIEW_MATRIX[3].xyz)
	);
	clip_overlap.y = dot(
		VERTEX - INV_VIEW_MATRIX[3].xyz,
		cross(trail_transform[3].xyz - INV_VIEW_MATRIX[3].xyz, trail_transform[0].xyz - INV_VIEW_MATRIX[3].xyz)
	);
}

void fragment() {
	if (clip_overlap.x * clip_overlap.y < 0.0 && abs(mesh_uv.x - 0.5) < 0.5) {
		discard;
	}

	vec4 ramp = texture(color_ramp, vec2(trail_progress, 0.0));

	ALBEDO = vec3(1.0);
	ALPHA = ramp.a * opacity;
}
