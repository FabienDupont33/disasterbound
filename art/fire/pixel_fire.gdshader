shader_type canvas_item;
render_mode unshaded;

uniform sampler2D fire_data : filter_linear, repeat_disable;
uniform sampler2D terrain_mask : filter_nearest, repeat_disable;
uniform vec2 field_size;
uniform float flicker_time;
varying vec2 map_position;

float grain(vec2 p) {
	return fract(sin(dot(p, vec2(37.13, 113.57))) * 43758.54);
}

void vertex() {
	map_position = VERTEX;
}

// Une flammèche s'allonge puis se replie, avec une phase fixe par emplacement.
float tongue(vec2 p, float strength, float spacing, float phase_offset) {
	vec2 tile = floor(p / spacing);
	float seed = grain(tile + phase_offset);
	vec2 q = fract(p / spacing);
	float phase = flicker_time * (0.9 + seed * 0.3) + seed * 13.0;
	float rise = q.y - 0.81;
	float height = (0.23 + strength * 0.57) * (0.59 + seed * 0.37 + sin(phase) * 0.22);
	float bend = sin(phase + q.y * 4.0) * (0.2 - rise * 0.25);
	float width = (0.17 + strength * 0.22) * clamp(1.0 + rise / height, 0.0, 1.0);
	float center = 0.28 + seed * 0.4 + bend;
	float distance_to_core = abs(q.x - center);
	return step(-height, rise) * step(rise, 0.16) *
			(1.0 - smoothstep(width * 0.22, max(0.01, width), distance_to_core));
}

void fragment() {
	vec2 pixel = floor(map_position);
	vec2 uv = (pixel + 0.5) / field_size;
	vec3 field = texture(fire_data, uv).rgb;
	float mask = texture(terrain_mask, uv).r;
	if (max(max(field.r, field.g), field.b) < 0.015 || mask < 0.5) {
		discard;
	}
	float speck = grain(pixel);
	float patches = grain(floor(pixel / 3.0));
	float phase = floor(flicker_time * 12.0) / 12.0;
	float ash = smoothstep(0.07 + patches * 0.12, 0.88, field.g);
	vec3 ash_color = mix(vec3(0.125, 0.108, 0.115), vec3(0.36, 0.29, 0.25),
			speck * 0.26 + patches * 0.48);
	float heat = field.r;
	float contour = heat + (patches - 0.5) * min(0.16, heat * 0.75);
	float bed = smoothstep(0.12, 0.52, contour);
	vec2 draft = vec2(2.0 * sin(pixel.y * 0.21), 2.0 * sin(pixel.x * 0.16));
	float flames = max(tongue(pixel + floor(draft), heat, 7.0, 0.0) * (0.67 + patches * 0.33),
			tongue(pixel - floor(draft) + vec2(4.0, 2.0), heat, 11.0, 53.0) * 0.82);
	float glow = step(0.34, flames) * smoothstep(0.05, 0.37, heat);
	vec3 fire_color = mix(vec3(0.48, 0.105, 0.08), vec3(0.86, 0.24, 0.09), bed);
	fire_color = mix(fire_color, vec3(1.0, 0.51, 0.14), step(0.37, flames));
	fire_color = mix(fire_color, vec3(1.0, 0.79, 0.31), step(0.64, flames));
	float spark = step(0.96, speck) * step(0.58, heat) * step(0.66, sin(phase * 10.0 + speck * 140.0));
	fire_color = mix(fire_color, vec3(1.0, 0.95, 0.67), spark);
	float fire_alpha = max(bed * (0.48 + patches * 0.31), max(glow, spark));
	float ash_alpha = ash * (0.75 + patches * 0.13);
	float damp = smoothstep(0.015, 0.38, field.b) * (0.34 + speck * 0.13);
	float alpha = fire_alpha + ash_alpha * (1.0 - fire_alpha);
	vec3 color = fire_color * fire_alpha + ash_color * ash_alpha * (1.0 - fire_alpha);
	color += vec3(0.095, 0.28, 0.25) * damp * (1.0 - alpha);
	alpha += damp * (1.0 - alpha);
	COLOR = vec4(color / max(alpha, 0.001), alpha * mask);
}
