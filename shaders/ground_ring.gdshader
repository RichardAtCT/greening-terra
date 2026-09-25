shader_type spatial;
// Soft glowing rings on the ground, all in one MultiMesh: a burning Heat Tower's warm radius, and
// a coming meteor's impact marker. Per instance: COLOR (alpha = strength); INSTANCE_CUSTOM.x how
// much the inside glows, .y 1 for a target (inner ring and cross).
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;

varying vec4 tint;
varying vec2 style;

void vertex() {
	tint = COLOR;
	style = INSTANCE_CUSTOM.xy;
}

void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float r = length(q);
	float w = fwidth(r) * 1.5;
	float ring = smoothstep(0.93 - w, 0.955, r) * (1.0 - smoothstep(0.975, 1.0, r));
	float fill = (1.0 - smoothstep(0.2, 1.0, r)) * style.x;
	float target = 0.0;
	if (style.y > 0.5) {
		target = smoothstep(0.30 - w, 0.33, r) * (1.0 - smoothstep(0.37, 0.40 + w, r));
		float cross = (1.0 - smoothstep(0.03, 0.05 + w, min(abs(q.x), abs(q.y)))) * step(r, 0.62) * step(0.12, r);
		target = max(target, cross);
	}
	ALBEDO = tint.rgb;
	ALPHA = clamp((ring + fill + target) * tint.a, 0.0, 1.0);
}
