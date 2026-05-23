shader_type canvas_item;
// Adapted from the MIT-licensed halftone transition shader on Godot Shaders:
// https://godotshaders.com/shader/halftone-directional-fading-transition/

uniform bool transparent_dot = false;
uniform float aspect_ratio = 1.5;
uniform float dots = 18.0;
uniform float min_density = 0.0;
uniform float max_density = 1.0;
uniform float height = -1.0;
uniform vec4 fade_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);


void fragment() {
	vec3 uv_grid = fract(vec3(UV, 0.0) * vec3(aspect_ratio * dots, dots, 0.0));
	float grid = distance(uv_grid, vec3(0.5, 0.5, 0.5));
	vec3 raw_image = vec3(1.0) * (UV.y + height);
	vec3 grayscale = vec3(max(max(raw_image.r, raw_image.g), raw_image.b));
	vec3 clamped = clamp(grayscale, vec3(min_density), vec3(max_density));

	bool black_dot_grid = grid > dot(vec3(1.0) - clamped, vec3(0.333333));
	bool white_dot_grid = grid < dot(clamped, vec3(0.333333));
	vec4 grid_result = transparent_dot ? (black_dot_grid ? fade_color : vec4(0.0)) : (white_dot_grid ? fade_color : vec4(0.0));

	COLOR = grid_result;
}
