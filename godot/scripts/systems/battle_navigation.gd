class_name BattleNavigation
extends NavigationRegion2D

## Procedurally constructs and bakes a NavigationPolygon with river obstacles
## and bridge thoroughfare for NavigationAgent2D pathfinding.

@export var map_bounds: Rect2 = Rect2(-1280, -768, 2560, 1536)

func _ready() -> void:
	_setup_navigation_mesh()

func _setup_navigation_mesh() -> void:
	var nav_poly := NavigationPolygon.new()

	# 1. Main outer walkable bounding polygon
	var outer_outline := PackedVector2Array([
		map_bounds.position,
		Vector2(map_bounds.end.x, map_bounds.position.y),
		map_bounds.end,
		Vector2(map_bounds.position.x, map_bounds.end.y)
	])
	nav_poly.add_outline(outer_outline)

	# 2. Obstacle cutouts for the river (leaving the bridge open at y = -64 to +64)
	var river_half_w := 96.0

	# Upper river segment (above bridge)
	var upper_river := PackedVector2Array([
		Vector2(-river_half_w, map_bounds.position.y),
		Vector2(river_half_w, map_bounds.position.y),
		Vector2(river_half_w, -70.0),
		Vector2(-river_half_w, -70.0)
	])
	nav_poly.add_outline(upper_river)

	# Lower river segment (below bridge)
	var lower_river := PackedVector2Array([
		Vector2(-river_half_w, 70.0),
		Vector2(river_half_w, 70.0),
		Vector2(river_half_w, map_bounds.end.y),
		Vector2(-river_half_w, map_bounds.end.y)
	])
	nav_poly.add_outline(lower_river)

	# Bake the navigation polygons
	nav_poly.make_polygons_from_outlines()
	navigation_polygon = nav_poly
