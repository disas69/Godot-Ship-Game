shader_type spatial;
render_mode unshaded, depth_draw_opaque, cull_back;

uniform vec4 albedo_color : source_color = vec4(0.02, 0.03, 0.04, 1.0);
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform bool use_texture = false;

uniform float swim_speed : hint_range(1.0, 30.0) = 8.0;
uniform float wiggle_amplitude : hint_range(0.0, 1.0) = 0.25;
uniform float wiggle_frequency : hint_range(0.5, 10.0) = 3.0;
uniform float phase_offset = 0.0;
uniform bool enable_wiggle_anim = true;

void vertex() {
	if (enable_wiggle_anim) {
		// Head is towards -Z (forward) and tail extends towards +Z (backward).
		// Bends X displacement stronger toward the rear (+Z).
		float rear_factor = clamp(VERTEX.z + 0.1, 0.0, 1.0);
		float inst_phase = phase_offset + float(INSTANCE_ID) * 2.39996;
		float wiggle = sin(TIME * swim_speed + inst_phase - VERTEX.z * wiggle_frequency);
		VERTEX.x += wiggle * rear_factor * wiggle_amplitude;
	}
}

void fragment() {
	vec4 col = albedo_color;
	if (use_texture) {
		col *= texture(albedo_texture, UV);
	}
	ALBEDO = col.rgb;
}
