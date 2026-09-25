shader_type spatial;
// Rounded dark panel behind floating world labels. Always faces the camera and draws on top.
render_mode unshaded, blend_mix, depth_draw_never, depth_test_disabled, cull_disabled, fog_disabled;

uniform vec4 color : source_color = vec4(0.078, 0.043, 0.063, 0.82);
// Panel size and corner radius, in metres.
uniform vec2 size = vec2(2.0, 0.5);
uniform float radius = 0.14;

varying vec2 local;

void vertex() {
	local = VERTEX.xy * size;
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	VERTEX.xy *= size;
}

void fragment() {
	vec2 q = abs(local) - (size * 0.5 - vec2(radius));
	float dist = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
	ALBEDO = color.rgb;
	ALPHA = color.a * clamp(0.5 - dist / max(fwidth(dist), 0.0001), 0.0, 1.0);
}
