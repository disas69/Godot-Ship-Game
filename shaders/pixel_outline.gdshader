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
uniform bool enable_dithering = true;

const mat4 BAYER_MATRIX_4X4 = mat4(
	vec4(-0.5, 0.0, -0.375, 0.125),
	vec4(0.25, -0.25, 0.375, -0.125),
	vec4(-0.3125, 0.1875, -0.4375, 0.0625),
	vec4(0.4375, -0.0625, 0.3125, -0.1875)
);

ivec2 clamp_pixel(ivec2 pixel, ivec2 texture_size) {
	return clamp(pixel, ivec2(0), texture_size - ivec2(1));
}

vec2 pixel_to_uv(ivec2 pixel, ivec2 texture_size) {
	return (vec2(pixel) + vec2(0.5)) / vec2(texture_size);
}

float get_depth(ivec2 pixel, mat4 inv_projection_matrix, ivec2 texture_size) {
	float depth = texelFetch(depth_texture, pixel, 0).r;
	vec2 screen_uv = pixel_to_uv(pixel, texture_size);
	vec3 ndc = vec3(screen_uv * 2.0 - 1.0, depth);
	vec4 view = inv_projection_matrix * vec4(ndc, 1.0);
	view.xyz /= view.w;
	return -view.z;
}

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

vec3 get_outlined_color(ivec2 screen_pixel, mat4 inv_projection_matrix, mat4 inv_view_matrix, ivec2 texture_size) {
	float depth = get_depth(screen_pixel, inv_projection_matrix, texture_size);
	vec3 normal = texelFetch(normal_texture, screen_pixel, 0).xyz * 2.0 - 1.0;
	int outline_offset = max(int(round(outline_thickness)), 1);

	ivec2 pixels[4];
	pixels[0] = clamp_pixel(screen_pixel + ivec2(0, outline_offset), texture_size);
	pixels[1] = clamp_pixel(screen_pixel - ivec2(0, outline_offset), texture_size);
	pixels[2] = clamp_pixel(screen_pixel + ivec2(outline_offset, 0), texture_size);
	pixels[3] = clamp_pixel(screen_pixel - ivec2(outline_offset, 0), texture_size);

	float depth_diff = 0.0;
	float depth_diff_reversed = 0.0;
	float nearest_depth = depth;
	ivec2 nearest_pixel = screen_pixel;

	float normal_sum = 0.0;
	for (int i = 0; i < 4; i++) {
		float d = get_depth(pixels[i], inv_projection_matrix, texture_size);
		depth_diff += depth - d;
		depth_diff_reversed += d - depth;

		if (d < nearest_depth) {
			nearest_depth = d;
			nearest_pixel = pixels[i];
		}

		vec3 n = texelFetch(normal_texture, pixels[i], 0).xyz * 2.0 - 1.0;
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

	vec3 original = texelFetch(screen_texture, screen_pixel, 0).rgb;
	vec3 nearest = texelFetch(screen_texture, nearest_pixel, 0).rgb;

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
	ivec2 texture_size = textureSize(screen_texture, 0);
	ivec2 screen_pixel = clamp_pixel(ivec2(floor(SCREEN_UV * vec2(texture_size))), texture_size);
	int sample_step = max(int(round(resolution_downsampling)), 1);
	ivec2 pixelated_pixel = clamp_pixel(
		ivec2(floor(vec2(screen_pixel) / float(sample_step)) * float(sample_step)) + ivec2(sample_step / 2),
		texture_size
	);
	vec3 color = get_outlined_color(pixelated_pixel, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX, texture_size);

	if (enable_dithering) {
		vec2 pixel_id = floor(vec2(screen_pixel) / float(sample_step));
		float bayer_shift = BAYER_MATRIX_4X4[int(mod(pixel_id.x, 4.0))][int(mod(pixel_id.y, 4.0))];
		float color_steps = max(bit_depth - 1.0, 1.0);
		color += vec3(bayer_shift / max(bit_depth, 1.0));
		color = round(color * color_steps) / color_steps;
	}

	ALBEDO = clamp(color, vec3(0.0), vec3(1.0));
	ALPHA = 1.0;
}
