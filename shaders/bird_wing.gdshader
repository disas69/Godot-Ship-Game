shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

uniform vec4 albedo_color : source_color = vec4(0.2, 0.22, 0.25, 1.0);
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform bool use_texture = false;

uniform float flap_speed : hint_range(1.0, 30.0) = 12.0;
uniform float flap_amplitude : hint_range(0.0, 2.0) = 0.45;
uniform float flap_frequency : hint_range(0.1, 5.0) = 1.0;
uniform float phase_offset = 0.0;
uniform bool enable_flap_anim = true;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	if (enable_flap_anim) {
		// Flap wings up and down based on distance from center along local X axis and instance phase offset
		float inst_phase = phase_offset + float(INSTANCE_ID) * 1.618;
		float flap = sin(TIME * flap_speed + inst_phase + (world_pos.x + world_pos.z) * 0.1);
		VERTEX.y += flap * abs(VERTEX.x) * flap_amplitude;
	}
}

void fragment() {
	vec4 col = albedo_color;
	if (use_texture) {
		col *= texture(albedo_texture, UV);
	}
	ALBEDO = col.rgb;
	ALPHA = col.a;
	ROUGHNESS = 0.6;
}
