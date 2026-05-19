class_name FovHandler
extends Node2D

var fov_layer: TileMapLayer
var stone_layer: TileMapLayer

var player: Player
var active_pylons: Array[Vector2i]

var width: int
var height: int

var fog_of_war: bool = true
var do_corners: bool = true
var light_blocking: bool = true
var keep_visited_tiles: bool = false

var visible_tile: Vector2i = Vector2i(0, 0)
var visited_tile: Vector2i = Vector2i(1, 0)
var fov_tile: Vector2i = Vector2i(2, 0)

var dynamic_visible_tiles: Array = []
var static_visible_tiles: Dictionary = {}

var invisible_tiles: Array[Vector2i] = []
var visible_tiles: Array[Vector2i] = []
var seen_tiles: Array[Vector2i] = []
var prev_pos: Vector2i # Previous player position local to map


@warning_ignore("shadowed_variable")
func _init(
		fov_layer: TileMapLayer,
		stone_layer: TileMapLayer,
		player: Player,
		active_pylons: Array[Vector2i],
		width: int,
		height: int,
		fog_of_war: bool = true,
		do_corners: bool = true,
		light_blocking: bool = true,
		keep_visited_tiles: bool = false
   ):
	self.fov_layer = fov_layer
	self.stone_layer = stone_layer
	self.player = player
	self.active_pylons = active_pylons
	self.width = width
	self.height = height
	self.fog_of_war = fog_of_war
	self.do_corners = do_corners
	self.light_blocking = light_blocking
	self.keep_visited_tiles = keep_visited_tiles


func generate_fov() -> void:
	for x in range(width):
		for y in range(height):
			var pos: Vector2i = Vector2i(x, y)

			invisible_tiles.append(pos)
			fov_layer.set_cell(pos, 0, fov_tile)


func handle_player_fov(forced: bool = false) -> void:
	var start_pos: Vector2i = stone_layer.local_to_map(player.position)
	
	if not forced and start_pos == prev_pos:
		return
	
	prev_pos = start_pos
	
	var dist: int = player.max_view_distance
	var ray_dist: int = dist * 2
	var lines: Array = []

	# Top check
	for x in range(-ray_dist, ray_dist + 1):
		var end_pos: Vector2i = start_pos + Vector2i(x, -ray_dist)
		if do_corners: lines.append(line_gen_corners(start_pos, end_pos))
		else:          lines.append(line_gen_no_corners(start_pos, end_pos))

	# Bottom check
	for x in range(-ray_dist, ray_dist + 1):
		var end_pos: Vector2i = start_pos + Vector2i(x, ray_dist)
		if do_corners: lines.append(line_gen_corners(start_pos, end_pos))
		else:          lines.append(line_gen_no_corners(start_pos, end_pos))
	
	# Left side (without corners)
	for y in range(-ray_dist + 1, ray_dist):
		var end_pos: Vector2i = start_pos + Vector2i(-ray_dist, y)
		if do_corners: lines.append(line_gen_corners(start_pos, end_pos))
		else:          lines.append(line_gen_no_corners(start_pos, end_pos))

	# Right side (without corners)
	for y in range(-ray_dist + 1, ray_dist):
		var end_pos: Vector2i = start_pos + Vector2i(ray_dist, y)
		if do_corners: lines.append(line_gen_corners(start_pos, end_pos))
		else:          lines.append(line_gen_no_corners(start_pos, end_pos))
	
	var current_dynamic: Array = []

	for line in lines:
		if light_blocking:
			var light_blocked: bool = false

			for point in line:
				if point.distance_to(start_pos) > dist:
					break

				if not light_blocked: 
					if point not in current_dynamic:
						current_dynamic.append(point)
					
					if point not in seen_tiles:
						seen_tiles.append(point)
					
					if fov_layer.get_cell_atlas_coords(point) != visible_tile:
						fov_layer.set_cell(point, 0, visible_tile)
					
					if stone_layer.get_cell_atlas_coords(point) != Vector2i(-1, -1):
						light_blocked = true
		else:
			for x in range(-dist, dist):
				for y in range(-dist, dist):
					var pos: Vector2i = Vector2i(x, y) + start_pos
					if pos.distance_to(start_pos) > dist:
						break
					
					if pos not in current_dynamic:
						current_dynamic.append(pos)
					
					if pos not in seen_tiles:
						seen_tiles.append(pos)
						
					if fov_layer.get_cell_atlas_coords(pos) != visible_tile:
						fov_layer.set_cell(pos, 0, visible_tile)

	# Clean up tiles the player just walked away from
	for tile in dynamic_visible_tiles:
		if tile not in current_dynamic:
			if not static_visible_tiles.has(tile):
				if light_blocking:
					if tile in seen_tiles and keep_visited_tiles:
						if fov_layer.get_cell_atlas_coords(tile) != visited_tile:
							fov_layer.set_cell(tile, 0, visited_tile)
					else:
						if fov_layer.get_cell_atlas_coords(tile) != fov_tile:
							fov_layer.set_cell(tile, 0, fov_tile)
			else:
				if fov_layer.get_cell_atlas_coords(tile) != fov_tile:
					fov_layer.set_cell(tile, 0, fov_tile)
					
	dynamic_visible_tiles = current_dynamic


func handle_pylon_fov() -> void:
	var current_static: Dictionary = {}
	
	for pylon_pos in active_pylons:
		var start_pos: Vector2i = pylon_pos
		var dist: int = Pylon.max_view_distance
		var ray_dist: int = dist * 2
		var lines: Array = []

		# Top check
		for x in range(-ray_dist, ray_dist):
			var end_pos: Vector2i = start_pos + Vector2i(x, -ray_dist)
			if do_corners: lines.append(line_gen_corners(start_pos, end_pos))
			else:          lines.append(line_gen_no_corners(start_pos, end_pos))

		# Bottom check
		for x in range(-ray_dist, ray_dist):
			var end_pos: Vector2i = start_pos + Vector2i(x, ray_dist)
			if do_corners: lines.append(line_gen_corners(start_pos, end_pos))
			else:          lines.append(line_gen_no_corners(start_pos, end_pos))
		
		# Left side
		for y in range(-ray_dist + 1, ray_dist - 1):
			var end_pos: Vector2i = start_pos + Vector2i(-ray_dist, y)
			if do_corners: lines.append(line_gen_corners(start_pos, end_pos))
			else:          lines.append(line_gen_no_corners(start_pos, end_pos))

		# Right side
		for y in range(-ray_dist + 1, ray_dist - 1):
			var end_pos: Vector2i = start_pos + Vector2i(ray_dist, y)
			if do_corners: lines.append(line_gen_corners(start_pos, end_pos))
			else:          lines.append(line_gen_no_corners(start_pos, end_pos))
			
		for line in lines:
			if light_blocking:
				var light_blocked: bool = false
				for point in line:
					if point.distance_to(start_pos) > dist:
						break

					if not light_blocked:
						current_static[point] = true
						
						if point not in seen_tiles:
							seen_tiles.append(point)
						
						if fov_layer.get_cell_atlas_coords(point) != visible_tile:
							fov_layer.set_cell(point, 0, visible_tile)
						
						if stone_layer.get_cell_atlas_coords(point) != Vector2i(-1, -1):
							light_blocked = true
			else:
				for x in range(-dist, dist):
					for y in range(-dist, dist):
						var pos: Vector2i = Vector2i(x, y) + start_pos
						if pos.distance_to(start_pos) > dist:
							break
						
						current_static[pos] = true
						if pos not in seen_tiles:
							seen_tiles.append(pos)
							
						if fov_layer.get_cell_atlas_coords(pos) != visible_tile:
							fov_layer.set_cell(pos, 0, visible_tile)

	# Clean up tiles when a pylon is removed or destroyed
	for tile in static_visible_tiles.keys():
		if not current_static.has(tile):
			# Overwrite Check: Only darken if the player IS NOT standing there lighting it
			if tile not in dynamic_visible_tiles:
				if light_blocking and tile in seen_tiles and keep_visited_tiles:
					if fov_layer.get_cell_atlas_coords(tile) != visited_tile:
						fov_layer.set_cell(tile, 0, visited_tile)
					else:
						if fov_layer.get_cell_atlas_coords(tile) != fov_tile:
							fov_layer.set_cell(tile, 0, fov_tile)
				else:
					if fov_layer.get_cell_atlas_coords(tile) != fov_tile:
						fov_layer.set_cell(tile, 0, fov_tile)
						
	static_visible_tiles = current_static


# Generates a line from point 0 to point 1 that respect visibility.
# Basically, the line doesn't go through blocks.
func line_gen_no_corners(p0: Vector2i, p1: Vector2i):
	var dx = p1[0] - p0[0]
	var dy = p1[1] - p0[1]
	var nx = abs(dx)
	var ny = abs(dy)
	var signX = sign(dx)
	var signY = sign(dy)
	var p: Vector2i = p0
	var points: Array[Vector2i] = [p]

	var ix = 0
	var iy = 0

	while ix < nx || iy < ny:
		if (( 1 + (ix << 1)) * ny < (1 + (iy << 1)) * nx):
			p.x += signX
			ix += 1
		else:
			p.y += signY
			iy += 1
		points.append(p)
	return points


func line_gen_corners(p0: Vector2i, p1: Vector2i) -> Array:
	var points: Array[Vector2i] = []
	var dx =  abs(p1[0] - p0[0])
	var dy = -abs(p1[1] - p0[1])
	var err = dx + dy
	var e2 = 2 * err
	var sx = 1 if p0[0] < p1[0] else -1
	var sy = 1 if p0[1] < p1[1] else -1

	while true:
		points.append(p0)
		if p0.x == p1.x and p0.y == p1.y:
			break
		e2 = 2 * err
		if e2 >= dy:
			err += dy
			p0.x += sx
		if e2 <= dx:
			err += dx
			p0.y += sy
	return points
