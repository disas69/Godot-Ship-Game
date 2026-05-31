shader_type particles;

render_mode keep_data, disable_force, disable_velocity;

void process() {
	float amount = LIFETIME;

	vec4 left_edge = EMISSION_TRANSFORM * vec4(-1.0, 0.0, 0.0, 1.0);
	vec4 right_edge = EMISSION_TRANSFORM * vec4(1.0, 0.0, 0.0, 1.0);

	if (CUSTOM.w == 0.0) {
		CUSTOM.w = float(INDEX) + 1.0;
		CUSTOM.z = amount;
		TRANSFORM = mat4(left_edge, left_edge, right_edge, right_edge);
	}

	if (CUSTOM.w == amount + 1.0) {
		CUSTOM.w = 1.0;
	}

	if (CUSTOM.w == 1.0) {
		TRANSFORM = mat4(left_edge, left_edge, right_edge, right_edge);
	}

	if (CUSTOM.w == 2.0) {
		TRANSFORM[1] = left_edge;
		TRANSFORM[2] = right_edge;
	}

	CUSTOM.w++;
}
