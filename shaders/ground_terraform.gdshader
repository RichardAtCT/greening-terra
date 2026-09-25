shader_type spatial;
// Terraform ground: the flat-shaded, vertex-coloured terrain tinted from ground_start to ground_end,
// with moss blended in by a ragged mask that grows outward from the hub, and frost (Orrin b) that
// melts back from the hub and round burning Heat Towers. Fed by TerraformView.apply().
render_mode diffuse_lambert, specular_disabled;

uniform vec4 ground_tint : source_color = vec4(0.54, 0.29, 0.17, 1.0);
uniform vec4 moss_color : source_color = vec4(0.31, 0.48, 0.23, 1.0);
uniform vec2 hub = vec2(0.0);
// Distance from the hub (metres) the moss front has reached.
uniform float moss_reach = 0.0;
// Width of the ragged edge of the front, in metres.
uniform float moss_edge = 6.0;
// Share of the ground inside the front that is mossy (patchy early, full later).
uniform float moss_cover = 0.4;
uniform float moss_strength = 0.9;
uniform float noise_scale = 0.11;
// Frost cover (0..1), its colour, how far from the hub it has melted, and warm spots (x, z,
// radius, on) where Heat Towers melt it.
uniform float frost = 0.0;
uniform vec4 frost_color : source_color = vec4(0.9, 0.94, 0.97, 1.0);
uniform float frost_reach = 0.0;
uniform vec4 warm[4];

varying vec3 world_pos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// COLOR holds the per-triangle brightness that gives the faceted look.
	vec3 base = COLOR.rgb * ground_tint.rgb;
	vec2 p = world_pos.xz * noise_scale;
	float n = value_noise(p) * 0.65 + value_noise(p * 3.1 + 17.0) * 0.35;
	float d = length(world_pos.xz - hub);
	float front = smoothstep(0.0, moss_edge, moss_reach - d + (n - 0.5) * moss_edge * 2.0);
	float patches = smoothstep(1.0 - moss_cover - 0.12, 1.0 - moss_cover + 0.12, value_noise(p * 1.7 + 41.0));
	float m = front * patches * moss_strength;
	// Mossy ground keeps a little of the facet shading so it stays low-poly.
	vec3 moss = moss_color.rgb * mix(1.0, COLOR.r, 0.6) * (0.9 + 0.2 * n);
	vec3 col = mix(base, moss, m);
	if (frost > 0.001) {
		float melted = smoothstep(frost_reach - 4.0, frost_reach + 4.0, d + (n - 0.5) * 6.0);
		float f = frost * mix(0.35, 1.0, melted) * smoothstep(0.2, 0.7, value_noise(p * 2.3 + 7.0) * 0.5 + frost * 0.5);
		for (int i = 0; i < 4; i++) {
			float wd = length(world_pos.xz - warm[i].xy);
			f *= 1.0 - warm[i].w * (1.0 - smoothstep(warm[i].z * 0.45, warm[i].z * 0.9, wd + (n - 0.5) * 2.0));
		}
		col = mix(col, frost_color.rgb * mix(0.85, 1.05, n), f * 0.85);
		// A sparkle of ice crystals.
		float glint = step(0.975, hash(floor(world_pos.xz * 7.0)));
		col += glint * f * 0.35;
	}
	ALBEDO = col;
	ROUGHNESS = 1.0;
}
