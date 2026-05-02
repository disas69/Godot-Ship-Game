shader_type canvas_item;

uniform float dither_scale = 1.0;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;

void fragment() {
    vec3 screen_color = texture(screen_texture, UV).rgb;

    // 4x4 Bayer matrix
	vec2 p = FRAGCOORD.xy / dither_scale;
	int x = int(mod(p.x, 4.0));
	int y = int(mod(p.y, 4.0));

    float dither[16] = float[](
        0.0,  8.0,  2.0, 10.0,
        12.0, 4.0, 14.0, 6.0,
        3.0, 11.0, 1.0,  9.0,
        15.0, 7.0, 13.0, 5.0
    );

    float threshold = dither[y * 4 + x] / 16.0;

    // apply dithering before quantization
    vec3 dithered = screen_color + (threshold / 255.0);

    vec3 quantized_color = floor((dithered * 255.0) / 8.0) / 31.0;

    COLOR = vec4(quantized_color, 1.0);
}