extends Control
## A shade over what is behind (part of the UI kit, kit.gd): it darkens the whole window,
## past the safe rect the interface is laid out in (a phone's camera cutout, a browser's
## toolbars), though it is only as large as its parent. Behind a KitWindow, the pause
## menu, the sleep screen; the map and the death screen draw theirs with window_rect.

## How dark, and in what colour.
var color: Color


func _init(c: Color) -> void:
	color = c
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# Drawn again when the interface moves with the safe rect, not only when it resizes.
	set_notify_transform(true)


## The whole window in the local coordinates of `c`, a pixel past each edge.
static func window_rect(c: CanvasItem) -> Rect2:
	return (c.get_global_transform().affine_inverse() * c.get_viewport_rect()).grow(2)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		queue_redraw()


func _draw() -> void:
	draw_rect(window_rect(self), color)
