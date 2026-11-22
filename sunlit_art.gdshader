shader_type canvas_item;
render_mode unshaded;

varying vec4 tint;

void vertex() {
	tint = COLOR;
}

void fragment() {
	vec4 art = texture(TEXTURE, UV);
	float light = smoothstep(0.16, 0.80, dot(art.rgb, vec3(0.2126, 0.7152, 0.0722)));
	float upper = 1.0 - smoothstep(0.09, 0.97, UV.y);
	vec3 mist = vec3(0.45, 0.61, 0.66);
	vec3 daylight = vec3(1.0, 0.91, 0.73);
	vec3 graded = mix(art.rgb, mist, 0.09 * (1.0 - light));
	graded = mix(graded, daylight, 0.10 * light * upper);
	COLOR = vec4(graded, art.a) * tint;
}
