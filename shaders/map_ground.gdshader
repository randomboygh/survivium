shader_type canvas_item;
// The ground of the explored map (Minimap regions, drawn by Minimap.draw_ground): the
// explored land is painted a chunk at a time, so where it meets the unexplored its
// edge would turn in square corners; a corner of a chunk with no land on either side
// of it is rounded off, and a notch between two chunks of land filled round. All of it
// is kept inside `clip` (x, y, w, h in the layer's pixels), its corners rounded by
// `radius`, as the frame round the map.

// Map pixels along a chunk (Minimap.CHUNK_PX) and the radius of a rounded corner.
const float CHUNK = 8.0;
const float ROUND = 5.0;

uniform vec4 clip = vec4(0.0, 0.0, 100000.0, 100000.0);
uniform float radius = 0.0;

varying vec2 local;

void vertex() {
	local = VERTEX;
}

// Outside the circle of radius r touching both edges, `d` pixels from each.
bool outside(vec2 d, float r) {
	vec2 q = r - d - 0.5;
	return d.x < r && d.y < r && dot(q, q) > r * r;
}

void fragment() {
	vec2 at = floor(local) - clip.xy;
	vec2 edge = min(at, clip.zw - 1.0 - at);
	if (at.x < 0.0 || at.y < 0.0 || edge.x < 0.0 || edge.y < 0.0 || outside(edge, radius)) {
		discard;
	}
	vec2 ps = TEXTURE_PIXEL_SIZE;
	vec2 px = floor(UV / ps);
	vec2 in_chunk = mod(px, CHUNK);
	vec4 c = texture(TEXTURE, (px + 0.5) * ps);
	bool land = c.a > 0.5;
	for (int i = 0; i < 4; i++) {
		vec2 s = vec2(i % 2 == 0 ? -1.0 : 1.0, i < 2 ? -1.0 : 1.0);
		vec2 d = vec2(s.x < 0.0 ? in_chunk.x : CHUNK - 1.0 - in_chunk.x,
			s.y < 0.0 ? in_chunk.y : CHUNK - 1.0 - in_chunk.y);
		if (!outside(d, ROUND)) {
			continue;
		}
		vec4 across_x = texture(TEXTURE, (px + vec2(s.x * (d.x + 1.0), 0.0) + 0.5) * ps);
		vec4 across_y = texture(TEXTURE, (px + vec2(0.0, s.y * (d.y + 1.0)) + 0.5) * ps);
		if (land && across_x.a < 0.5 && across_y.a < 0.5) {
			c.a = 0.0;
			break;
		}
		if (!land && across_x.a > 0.5 && across_y.a > 0.5) {
			c = across_x;
			break;
		}
	}
	if (c.a < 0.5) {
		discard;
	}
	COLOR = c;
}
