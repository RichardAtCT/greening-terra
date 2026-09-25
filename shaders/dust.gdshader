shader_type spatial;
// Drifting dust motes that wrap around the player, moved entirely on the GPU.
// Each instance's base position arrives in INSTANCE_CUSTOM.xyz. `drift` is the wind blown so far,
// summed on the CPU so the wind can change speed (dust storms) without the motes jumping.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;

uniform vec4 color : source_color = vec4(0.88, 0.63, 0.48, 1.0);
uniform float opacity = 0.6;
uniform vec3 center = vec3(0.0);
uniform vec2 drift = vec2(0.0);
// Metres fallen so far (snow), wrapping in a 6 m tall band.
uniform float fall = 0.0;
uniform float extent = 40.0;
uniform float size = 0.09;

void vertex() {
	vec3 base = INSTANCE_CUSTOM.xyz;
	vec2 moved = base.xz + drift - center.xz + extent * 0.5;
	moved = mod(moved, extent) - extent * 0.5 + center.xz;
	float y = mod(base.y - fall, 6.0);
	vec4 view_pos = VIEW_MATRIX * vec4(moved.x, y, moved.y, 1.0);
	view_pos.xy += VERTEX.xy * size;
	POSITION = PROJECTION_MATRIX * view_pos;
}

void fragment() {
	ALBEDO = color.rgb;
	ALPHA = opacity;
}
