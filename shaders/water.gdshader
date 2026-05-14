/**
* Ported from the original unity shader by Erik Roystan Ross
* https://roystan.net/articles/toon-water.html
* https://github.com/IronWarrior/ToonWaterShader
* Camera Depth taken from Bastiaan Olij's video on: https://www.youtube.com/watch?v=Jq3he9Lbj7M
*/

shader_type spatial;
render_mode blend_mix, depth_draw_never;

const float SMOOTHSTEP_AA = 0.01;

uniform sampler2D surfaceNoise;
uniform sampler2D distortNoise;
uniform sampler2D depth_texture : hint_depth_texture;

uniform float beer_factor = 0.8;

uniform float foam_distance = 0.01;
uniform float foam_max_distance = 0.4;
uniform float foam_min_distance = 0.04;
uniform vec4 foam_color: source_color  = vec4(1.0);

uniform vec2 surface_noise_tiling = vec2(1.0, 4.0);
uniform vec3 surface_noise_scroll = vec3(0.03, 0.03, 0.0);
uniform float surface_noise_cutoff: hint_range(0, 1) = 0.777;
uniform float surface_distortion_amount: hint_range(0, 10) = 0.27;
uniform vec2 wave_noise_tiling = vec2(1.8, 1.8);
uniform vec2 wave_noise_scroll = vec2(0.025, 0.018);
uniform float wave_noise_cutoff: hint_range(0, 1) = 0.6;
uniform float wave_noise_softness: hint_range(0.001, 0.3) = 0.05;
uniform float wave_distortion_amount: hint_range(0, 10) = 0.2;
uniform vec4 wave_color: source_color = vec4(1.0, 1.0, 1.0, 0.2);
uniform float wave_strength: hint_range(0, 1) = 0.4;

uniform vec4 _DepthGradientShallow: source_color = vec4(0.325, 0.807, 0.971, 0.725);
uniform vec4 _DepthGradientDeep: source_color = vec4(0.086, 0.407, 1, 0.749);
uniform float _DepthMaxDistance: hint_range(0, 1) = 1.0;
uniform float _DepthFactor = 1.0;

varying vec2 noiseUV;
varying vec2 distortUV;
varying vec2 waveNoiseUV;
varying vec3 viewNormal;

vec4 alphaBlend(vec4 top, vec4 bottom)
{
	vec3 color = (top.rgb * top.a) + (bottom.rgb * (1.0 - top.a));
	float alpha = top.a + bottom.a * (1.0 - top.a);
	
	return vec4(color, alpha);
}

void vertex() {
	viewNormal = (MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
	noiseUV = UV * surface_noise_tiling;
	distortUV = UV;
	waveNoiseUV = UV * wave_noise_tiling;
}

void fragment(){
	float scene_depth_raw = texture(depth_texture, SCREEN_UV).x;
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, scene_depth_raw);
	vec4 scene_view_pos = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	scene_view_pos.xyz /= scene_view_pos.w;

	float scene_depth = -scene_view_pos.z;
	float water_depth = -VERTEX.z;
	float depth_difference = max(scene_depth - water_depth, 0.0);
	float depth = 1.0 - exp(-depth_difference * max(beer_factor, 0.0001));
	
	// Still unsure how to get properly the NORMAL from the camera
	// this was my best attempt
	vec3 existingNormal = vec3(dFdx(depth_difference), dFdy(depth_difference), 0.0);
	
	float normalDot = clamp(dot(existingNormal.xyz, viewNormal), 0.0, 1.0);
	float foamDistance = mix(foam_max_distance, foam_min_distance, normalDot);
	
	float foamDepth = clamp(depth_difference / max(foamDistance, 0.0001), 0.0, 1.0);
	float surfaceNoiseCutoff = foamDepth * surface_noise_cutoff;
	
	vec4 distortNoiseSample = texture(distortNoise, distortUV);
	vec2 distortAmount = (distortNoiseSample.xy * 2.0 -1.0) * surface_distortion_amount;
	
	vec2 noise_uv = vec2(
		(noiseUV.x + TIME * surface_noise_scroll.x) + distortAmount.x , 
		(noiseUV.y + TIME * surface_noise_scroll.y + distortAmount.y)
	);
	float surfaceNoiseSample = texture(surfaceNoise, noise_uv).r;
	float surfaceNoiseAmount = smoothstep(surfaceNoiseCutoff - SMOOTHSTEP_AA, surfaceNoiseCutoff + SMOOTHSTEP_AA, surfaceNoiseSample);

	vec2 wave_distort_amount = (distortNoiseSample.xy * 2.0 - 1.0) * wave_distortion_amount;
	vec2 wave_noise_uv = vec2(
		(waveNoiseUV.x + TIME * wave_noise_scroll.x) + wave_distort_amount.x,
		(waveNoiseUV.y + TIME * wave_noise_scroll.y) + wave_distort_amount.y
	);
	float wave_noise_sample = texture(surfaceNoise, wave_noise_uv).r;
	float wave_noise_amount = smoothstep(
		wave_noise_cutoff - wave_noise_softness,
		wave_noise_cutoff + wave_noise_softness,
		wave_noise_sample
	) * wave_strength;
	
	float waterDepth = clamp(depth / _DepthMaxDistance, 0.0, 1.0) * _DepthFactor;
	vec4 waterColor = mix(_DepthGradientShallow, _DepthGradientDeep, waterDepth);
	vec4 waveColor = wave_color;
	waveColor.a *= wave_noise_amount;

	vec4 surfaceNoiseColor = foam_color;
	surfaceNoiseColor.a *= surfaceNoiseAmount;
	vec4 baseColor = alphaBlend(waveColor, waterColor);
	vec4 color = alphaBlend(surfaceNoiseColor, baseColor);
	
	ALBEDO = color.rgb;
	ALPHA = color.a;
}
