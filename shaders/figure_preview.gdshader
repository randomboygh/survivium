// The character drawn big on the «Персонаж» tab (figure_preview.gd): its sheet with the
// colours of the looks picked swapped in, as the world's figure has them (sprite.gdshader).
shader_type canvas_item;

#include "res://shaders/looks.gdshaderinc"

void fragment() {
	COLOR.rgb = looks_swap(COLOR.rgb);
}
