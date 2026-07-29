shader_type spatial;
render_mode cull_front, unshaded, depth_draw_always;

uniform vec4 outline_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float outline_thickness : hint_range(0.0, 1.0) = 0.075;

uniform float wave_speed : hint_range(0.0, 20.0) = 4.0;
uniform float wave_frequency : hint_range(0.0, 20.0) = 3.0;
uniform float wave_amplitude : hint_range(0.0, 1.0) = 0.0;
uniform float height_threshold : hint_range(-5.0, 10.0) = 0.4;
uniform float height_falloff : hint_range(0.01, 5.0) = 0.6;

void vertex() {
	if (wave_amplitude > 0.0) {
		float mask = clamp((VERTEX.y - height_threshold) / max(height_falloff, 0.001), 0.0, 1.0);
		float wave_x = sin(TIME * wave_speed + VERTEX.y * wave_frequency) * wave_amplitude * mask;
		float wave_z = cos(TIME * wave_speed * 0.8 + VERTEX.y * wave_frequency * 1.2) * wave_amplitude * 0.35 * mask;
		VERTEX.x += wave_x;
		VERTEX.z += wave_z;
	}
	VERTEX += NORMAL * outline_thickness;
}

void fragment() {
	ALBEDO = outline_color.rgb;
	ALPHA = outline_color.a;
}
