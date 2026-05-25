shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, depth_test_disabled, cull_disabled;

uniform sampler2D screen_texture : source_color, hint_screen_texture, filter_nearest;
uniform sampler2D depth_texture : source_color, hint_depth_texture, filter_nearest;
uniform sampler2D normal_texture : source_color, hint_normal_roughness_texture, filter_nearest;

uniform float depth_threshold : hint_range(0, 1) = 0.05;
uniform float reverse_depth_threshold : hint_range(0, 1) = 0.25;
uniform float normal_threshold : hint_range(0, 1) = 0.6;
uniform float outline_thickness : hint_range(0.5, 8.0, 0.5) = 1.0;

uniform float darken_amount : hint_range(0, 1, 0.01) = 0.3;
uniform float lighten_amount : hint_range(0, 10, 0.01) = 1.5;

uniform vec3 normal_edge_bias = vec3(1, 1, 1);
uniform vec3 light_direction = vec3(-0.96, -0.18, 0.2);

uniform float resolution_downsampling : hint_range(1.0, 8.0, 1.0) = 1.0;
uniform float bit_depth : hint_range(2.0, 64.0, 2.0) = 32.0;

const mat4 BAYER_MATRIX_4X4 = mat4(
	vec4(-0.5, 0.0, -0.375, 0.125),
	vec4(0.25, -0.25, 0.375, -0.125),
	vec4(-0.3125, 0.1875, -0.4375, 0.0625),
	vec4(0.4375, -0.0625, 0.3125, -0.1875)
);

float get_depth(vec2 screen_uv, mat4 inv_projection_matrix) {
	float depth = texture(depth_texture, screen_uv).r;
	vec3 ndc = vec3(screen_uv * 2.0 - 1.0, depth);
	vec4 view = inv_projection_matrix * vec4(ndc, 1.0);
	view.xyz /= view.w;
	return -view.z;
}

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

vec3 get_outlined_color(vec2 screen_uv, mat4 inv_projection_matrix, mat4 inv_view_matrix, vec2 viewport_size) {
	float depth = get_depth(screen_uv, inv_projection_matrix);
	vec3 normal = texture(normal_texture, screen_uv).xyz * 2.0 - 1.0;
	vec2 texel_size = outline_thickness / viewport_size;

	vec2 uvs[4];
	uvs[0] = vec2(screen_uv.x, min(1.0 - 0.001, screen_uv.y + texel_size.y));
	uvs[1] = vec2(screen_uv.x, max(0.0, screen_uv.y - texel_size.y));
	uvs[2] = vec2(min(1.0 - 0.001, screen_uv.x + texel_size.x), screen_uv.y);
	uvs[3] = vec2(max(0.0, screen_uv.x - texel_size.x), screen_uv.y);

	float depth_diff = 0.0;
	float depth_diff_reversed = 0.0;
	float nearest_depth = depth;
	vec2 nearest_uv = screen_uv;

	float normal_sum = 0.0;
	for (int i = 0; i < 4; i++) {
		float d = get_depth(uvs[i], inv_projection_matrix);
		depth_diff += depth - d;
		depth_diff_reversed += d - depth;

		if (d < nearest_depth) {
			nearest_depth = d;
			nearest_uv = uvs[i];
		}

		vec3 n = texture(normal_texture, uvs[i]).xyz * 2.0 - 1.0;
		vec3 normal_diff = normal - n;

		// Edge pixels should yield to the normal closest to the bias direction
		float normal_bias_diff = dot(normal_diff, normal_edge_bias);
		float normal_indicator = smoothstep(-0.01, 0.01, normal_bias_diff);

		normal_sum += dot(normal_diff, normal_diff) * normal_indicator;
	}
	float depth_edge = step(depth_threshold, depth_diff);

	// The reverse depth sum produces depth lines inside of the object, but they don't look as nice as the normal depth_diff
	// Instead, we can use this value to mask the normal edge along the outside of the object
	float reverse_depth_edge = step(reverse_depth_threshold, depth_diff_reversed);

	float indicator = sqrt(normal_sum);
	float normal_edge = step(normal_threshold, indicator - reverse_depth_edge);

	vec3 original = texture(screen_texture, screen_uv).rgb;
	vec3 nearest = texture(screen_texture, nearest_uv).rgb;

	mat3 view_to_world_normal_mat = mat3(
		inv_view_matrix[0].xyz,
		inv_view_matrix[1].xyz,
		inv_view_matrix[2].xyz
	);
	float ld = dot((view_to_world_normal_mat * normal), normalize(light_direction));

	vec3 depth_col = nearest * darken_amount;
	vec3 normal_col = original * (ld > 0.0 ? darken_amount : lighten_amount);
	vec3 edge_mix = mix(normal_col, depth_col, depth_edge);

	return mix(original, edge_mix, (depth_edge > 0.0 ? depth_edge : normal_edge));
}

void fragment() {
	vec2 pixel_size = resolution_downsampling / VIEWPORT_SIZE.xy;
	vec2 pixelated_uv = SCREEN_UV - mod(SCREEN_UV, pixel_size);
	vec2 pixel_id = SCREEN_UV / pixel_size;
	float bayer_shift = BAYER_MATRIX_4X4[int(mod(pixel_id.x, 4.0))][int(mod(pixel_id.y, 4.0))];
	float color_steps = max(bit_depth - 1.0, 1.0);

	vec3 dithered = get_outlined_color(pixelated_uv, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX, VIEWPORT_SIZE.xy);
	dithered += vec3(bayer_shift / max(bit_depth, 1.0));
	dithered = round(dithered * color_steps) / color_steps;

	ALBEDO = clamp(dithered, vec3(0.0), vec3(1.0));
	ALPHA = 1.0;
}
