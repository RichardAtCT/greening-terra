shader_type spatial;
// Steam and heat haze rising from Kessik's vents, animated entirely on the GPU. Each instance is a
// camera-facing puff; INSTANCE_CUSTOM.xyz is its vent (x, z) and phase (0..1), .w its drift angle.
// A puff rises, swells and fades over `life` seconds, then starts again, wobbling as it goes.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;

uniform vec4 color : source_color = vec4(0.91, 0.89, 0.8, 1.0);
uniform float opacity = 0.42;
uniform float life = 3.2;
uniform float rise = 3.4;
uniform float size = 0.7;

varying float fade;
varying vec2 local;

void vertex() {
	vec4 c = INSTANCE_CUSTOM;
	float k = fract(TIME / life + c.z);
	vec3 base = vec3(c.x, 0.2, c.y);
	vec2 drift = vec2(cos(c.w), sin(c.w)) * k * 0.9 + vec2(sin(TIME * 2.3 + c.z * 20.0), 0.0) * 0.12 * k;
	vec3 center = base + vec3(drift.x, k * rise, drift.y);
	float s = size * (0.45 + k * 1.3);
	local = VERTEX.xy;
	vec4 view_pos = VIEW_MATRIX * vec4(center, 1.0);
	view_pos.xy += VERTEX.xy * s;
	POSITION = PROJECTION_MATRIX * view_pos;
	fade = smoothstep(0.0, 0.15, k) * (1.0 - smoothstep(0.55, 1.0, k));
}

void fragment() {
	float r = length(local * 2.0);
	float puff = 1.0 - smoothstep(0.35, 1.0, r);
	ALBEDO = color.rgb;
	ALPHA = puff * fade * opacity;
}
