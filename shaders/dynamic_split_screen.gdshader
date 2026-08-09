shader_type canvas_item;
render_mode unshaded;

uniform vec2 viewport_size = vec2(1.0, 1.0);
uniform sampler2D viewport1 : filter_nearest;
uniform sampler2D viewport2 : filter_nearest;
uniform float split_amount : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform vec2 player1_position = vec2(0.5, 0.5);
uniform vec2 player2_position = vec2(0.5, 0.5);
uniform float split_line_thickness : hint_range(0.0, 32.0, 0.1) = 3.0;
uniform vec4 split_line_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

float distance_to_line(vec2 p1, vec2 p2, vec2 point) {
	float a = p1.y - p2.y;
	float b = p2.x - p1.x;
	return abs(a * point.x + b * point.y + p1.x * p2.y - p2.x * p1.y) / max(sqrt(a * a + b * b), 0.0001);
}

vec4 get_split_color(vec4 view1, vec4 view2, vec2 uv, float width, float height) {
	vec2 player_delta = player2_position - player1_position;
	float split_slope = 100000.0;
	if (abs(player_delta.y) > 0.0001) {
		split_slope = player_delta.x / player_delta.y;
	}

	vec2 split_origin = vec2(0.5, 0.5);
	float split_current_y = (split_origin.x - uv.x) * split_slope + split_origin.y;
	float split_player1_position_y = (split_origin.x - player1_position.x) * split_slope + split_origin.y;
	bool uv_below_line = uv.y > split_current_y;
	bool player1_below_line = player1_position.y > split_player1_position_y;

	vec4 color = (uv_below_line == player1_below_line) ? view1 : view2;

	float line_thickness = split_line_thickness * split_amount;
	if (line_thickness > 0.001) {
		vec2 split_line_start = vec2(0.0, height * ((split_origin.x - 0.0) * split_slope + split_origin.y));
		vec2 split_line_end = vec2(width, height * ((split_origin.x - 1.0) * split_slope + split_origin.y));
		float line_distance = distance_to_line(split_line_start, split_line_end, vec2(uv.x * width, uv.y * height));
		if (line_distance < line_thickness) {
			float line_alpha = split_line_color.a * (1.0 - smoothstep(0.0, line_thickness, line_distance));
			color.rgb = mix(color.rgb, split_line_color.rgb, line_alpha);
		}
	}

	return color;
}

void fragment() {
	vec4 view1 = texture(viewport1, UV);
	vec4 view2 = texture(viewport2, UV);
	float width = max(viewport_size.x, 1.0);
	float height = max(viewport_size.y, 1.0);
	vec4 split_color = get_split_color(view1, view2, UV, width, height);

	COLOR = mix(view1, split_color, split_amount);
	COLOR.a = 1.0;
}
