// The faces the view in a sphere opens (setting «Вид в пещере» → «сфера», CaveSphere):
// drawn on the near side of the sphere, which stands in the world and is sheared like
// all else. The world's own mesh has no faces between two solid cells, so where the
// sphere leaves out solid cells (sphere_hides_cell) the solid cells beyond them would
// show nothing. Each pixel walks its line of sight cell by cell from the sphere's
// surface, away from the camera (solid_map): through the cells left out, to the first
// that is not. That one, if solid and come to from a solid cell left out, has no face
// of the world's there: its face is drawn here, in the colour of stone, at its own
// depth. Any other way the world's own faces show, and this draws nothing.
shader_type spatial;
render_mode world_vertex_coords, unshaded, cull_back, shadows_disabled;

#include "res://shaders/common.gdshaderinc"

// The most cells a line of sight walks.
const int STEPS = 96;

varying vec3 world_pos;

void vertex() {
	world_pos = VERTEX;
	VERTEX = shear(VERTEX);
}

void fragment() {
	vec3 way = -toward_camera();
	vec3 p = world_pos + way * 0.001;
	vec3 c = floor(p / CELL);
	vec3 step_by = sign(way);
	vec3 safe = vec3(abs(way.x) < 1e-5 ? 1e-5 : way.x, abs(way.y) < 1e-5 ? 1e-5 : way.y, abs(way.z) < 1e-5 ? 1e-5 : way.z);
	vec3 delta = abs(CELL / safe);
	vec3 next = ((c + max(step_by, vec3(0.0))) * CELL - p) / safe;
	next = vec3(abs(way.x) < 1e-5 ? 1e9 : next.x, abs(way.y) < 1e-5 ? 1e9 : next.y, abs(way.z) < 1e-5 ? 1e9 : next.z);
	bool seen = false;
	bool last_solid = false;
	vec3 normal = vec3(0.0, 1.0, 0.0);
	float t = 0.0;
	bool hit = false;
	for (int i = 0; i < STEPS; i++) {
		bool solid = solid_cell(c);
		if (sphere_hides_cell(c)) {
			seen = true;
			last_solid = solid;
		} else {
			hit = seen && solid && last_solid;
			if (hit || solid || seen) {
				break;
			}
		}
		if (next.x < next.y && next.x < next.z) {
			t = next.x;
			next.x += delta.x;
			c.x += step_by.x;
			normal = vec3(-step_by.x, 0.0, 0.0);
		} else if (next.y < next.z) {
			t = next.y;
			next.y += delta.y;
			c.y += step_by.y;
			normal = vec3(0.0, -step_by.y, 0.0);
		} else {
			t = next.z;
			next.z += delta.z;
			c.z += step_by.z;
			normal = vec3(0.0, 0.0, -step_by.z);
		}
	}
	if (!hit) {
		discard;
	}
	vec3 at = p + way * t;
	vec4 clip = PROJECTION_MATRIX * VIEW_MATRIX * vec4(shear(at), 1.0);
	DEPTH = clip.z / clip.w * 0.5 + 0.5;
	// Stone, lighter on tops, darker on the sides and under, in dots.
	float lit = normal.y > 0.5 ? 1.0 : (normal.y < -0.5 ? 0.55 : (abs(normal.x) > 0.5 ? 0.8 : 0.7));
	vec2 st = floor(screen_plane(at) * TEXELS);
	float speck = hash13(floor(at * TEXELS));
	vec3 rock = vec3(0.36, 0.34, 0.33) * lit;
	ALBEDO = rock * (bayer4(st) < 0.5 ? 1.0 : 0.85) * (speck > 0.9 ? 0.8 : 1.0);
}
