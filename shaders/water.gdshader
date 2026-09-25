shader_type spatial;
// Stylised lake: faceted, gently heaving surface with drifting light streaks and a foam rim.
// The mesh is a unit disc (MeshUtil.water_disc) scaled to the lake's size.
render_mode diffuse_lambert, specular_disabled;

uniform vec4 deep_color : source_color = vec4(0.18, 0.44, 0.56, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.36, 0.66, 0.72, 1.0);
uniform vec4 foam_color : source_color = vec4(0.86, 0.95, 0.96, 1.0);
uniform float wave_height = 0.06;
uniform float wave_speed = 0.8;
uniform float streak_speed = 0.35;

varying vec2 local;
varying vec3 world_pos;

void vertex() {
	local = VERTEX.xz;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// Waves fade out at the shore so the rim stays on the ground.
	float r = length(VERTEX.xz);
	float w = sin(world_pos.x * 0.9 + TIME * wave_speed) * 0.5 + sin(world_pos.z * 1.3 - TIME * wave_speed * 0.8) * 0.5;
	VERTEX.y += w * wave_height * (1.0 - r) / max(MODEL_MATRIX[1][1], 0.001);
}

void fragment() {
	// Flat facets from screen-space derivatives, for the low-poly look.
	NORMAL = normalize(cross(dFdy(VERTEX), dFdx(VERTEX)));
	float r = length(local);
	vec3 col = mix(deep_color.rgb, shallow_color.rgb, smoothstep(0.45, 0.95, r));
	float s = sin(world_pos.x * 0.7 + world_pos.z * 0.45 + TIME * streak_speed) * sin(world_pos.z * 1.1 - world_pos.x * 0.3 - TIME * streak_speed * 1.3);
	col = mix(col, foam_color.rgb, smoothstep(0.82, 0.95, s) * 0.35);
	float ang = atan(local.y, local.x);
	float rim = smoothstep(0.88, 0.96, r + sin(ang * 9.0 + TIME * 0.9) * 0.015);
	col = mix(col, foam_color.rgb, rim * 0.8);
	ALBEDO = col;
	EMISSION = deep_color.rgb * 0.15;
	ROUGHNESS = 1.0;
}
