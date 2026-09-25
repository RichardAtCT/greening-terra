shader_type spatial;
// Pad tops, all pads in one MultiMesh: dark translucent fill with a coloured square border, like
// the prototype's canvas pads, and the pad's title and subtitle read from a text atlas (PadBatch).
// Per instance: COLOR is the pad's colour; INSTANCE_CUSTOM.x its atlas cell, .y its opacity.
render_mode unshaded, blend_mix, depth_draw_never, cull_back;

uniform vec4 fill_color : source_color = vec4(0.063, 0.035, 0.047, 0.5);
// Border band, as a fraction of the pad size from the edge.
uniform float border_outer = 0.053;
uniform float border_inner = 0.088;
uniform float fill_edge = 0.04;
// White text on black (red = coverage), one cell per pad; a cell covers text_rows of the pad.
uniform sampler2D atlas : filter_linear_mipmap_anisotropic;
uniform vec2 atlas_cells = vec2(4.0, 6.0);
uniform vec2 text_rows = vec2(0.2734, 0.7734);
// The top sits just above its slab. Pulling it this share of the way towards the camera along the
// view ray (same pixel, nearer depth) stops it z-fighting the slab where depth precision is low.
uniform float depth_pull = 0.004;

varying vec4 pad_color;
varying flat float cell;
varying flat float opacity;

void vertex() {
	vec4 view = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	view.xyz *= 1.0 - depth_pull;
	POSITION = PROJECTION_MATRIX * view;
	pad_color = COLOR;
	// Rounded: instance data can arrive as 11.999 on some GPUs, and floor() would pick the wrong row.
	cell = floor(INSTANCE_CUSTOM.x + 0.5);
	opacity = INSTANCE_CUSTOM.y;
}

void fragment() {
	vec2 d = min(UV, 1.0 - UV);
	float edge = min(d.x, d.y);
	vec4 c = vec4(0.0);
	if (edge > fill_edge) {
		c = fill_color;
	}
	if (edge > border_outer && edge < border_inner) {
		c = vec4(pad_color.rgb, 1.0);
	}
	float a = c.a * opacity;
	vec3 col = c.rgb;
	float v = (UV.y - text_rows.x) / (text_rows.y - text_rows.x);
	// Sampled outside any branch: mipmap selection needs derivatives from every pixel of a quad.
	vec2 at = vec2(mod(cell, atlas_cells.x), floor(cell / atlas_cells.x));
	float text = texture(atlas, (at + vec2(UV.x, clamp(v, 0.0, 1.0))) / atlas_cells).r;
	// Firmed up a little, as mipmapped text at a glancing angle goes soft.
	text = smoothstep(0.08, 0.6, text) * step(0.0, v) * step(v, 1.0) * step(0.0, cell);
	col = mix(col, pad_color.rgb, text);
	a = max(a, text);
	ALBEDO = col;
	ALPHA = a;
}
