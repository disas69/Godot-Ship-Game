shader_type spatial;
render_mode cull_disabled;

uniform sampler2D albedo_texture : source_color, filter_nearest;
uniform vec4 color_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);

uniform float wave_speed : hint_range(0.0, 20.0) = 4.0;
uniform float wave_frequency : hint_range(0.0, 20.0) = 3.0;
uniform float wave_amplitude : hint_range(0.0, 1.0) = 0.15;
uniform float height_threshold : hint_range(-5.0, 10.0) = 0.4;
uniform float height_falloff : hint_range(0.01, 5.0) = 0.6;

void vertex() {
	// Mask the wave animation so it only affects the top part of the mesh (VERTEX.y > height_threshold)
	float mask = clamp((VERTEX.y - height_threshold) / max(height_falloff, 0.001), 0.0, 1.0);
	
	// Calculate sinusoidal wave displacement along X and Z axes
	float wave_x = sin(TIME * wave_speed + VERTEX.y * wave_frequency) * wave_amplitude * mask;
	float wave_z = cos(TIME * wave_speed * 0.8 + VERTEX.y * wave_frequency * 1.2) * wave_amplitude * 0.35 * mask;
	
	VERTEX.x += wave_x;
	VERTEX.z += wave_z;
}

void fragment() {
	vec4 tex_color = texture(albedo_texture, UV);
	ALBEDO = tex_color.rgb * color_tint.rgb;
}
