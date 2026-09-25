shader_type spatial;
// Terraform ground: the flat-shaded, vertex-coloured terrain tinted from ground_start to ground_end,
// with moss blended in by a ragged mask that grows outward from the hub. Fed by TerraformView.apply().
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
	ALBEDO = mix(base, moss, m);
	ROUGHNESS = 1.0;
}
