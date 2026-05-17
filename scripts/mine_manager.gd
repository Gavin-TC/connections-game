class_name MineManager
extends Node2D

@export var width: int
@export var height: int
@export var fog_of_war: bool = true
@export var do_corners: bool = true
@export var light_blocking: bool = true

@onready var fov_layer: TileMapLayer = %FovLayer
@onready var background_layer: TileMapLayer = %BackgroundLayer
@onready var stone_layer: TileMapLayer = %StoneLayer

@onready var player: Player = get_tree().get_first_node_in_group("Player")

# Noise/generation stuff
var noise: FastNoiseLite
var noise_seed: int = randi_range(0, 214700000)
var rock_threshold: float = 0.18
var noise_freq: float = -0.04

var pylon_scene: PackedScene = preload("res://entities/pylon.tscn")
var active_pylons: Array[Vector2i] = []

# Tile stuff
var tile_type: Dictionary[Vector2i, Global.TileType]
var tile_health: Dictionary[Vector2i, float]
var ore_type: Dictionary[Vector2i, Global.OreType]

# Texture atlas'
var stone_tiles: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0)]
var bedrock_tiles: Array[Vector2i] = [Vector2i(0, 1), Vector2i(1, 1)]
var background_tiles: Array[Vector2i] = [Vector2i(2, 0), Vector2i(3, 0)]
var damage_states: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0), Vector2i(5, 0)]
var darkness_tile: Vector2i = Vector2i(0, 1)

var fov_tile: Vector2i = Vector2i(0, 1)
var visible_tile: Vector2i = Vector2i(2, 1)
var visited_tile: Vector2i = Vector2i(3, 1)

# Replace visible_tiles with these two variables:
var dynamic_visible_tiles: Array = []
var static_visible_tiles: Dictionary = {}

@export var pylon_view_distance: int = 7

var ore_atlas: Dictionary[Global.OreType, Array] = {
	Global.OreType.COAL: [Vector2i(0, 2)],
	Global.OreType.IRON: [Vector2i(1, 2)],
	Global.OreType.GOLD: [Vector2i(2, 2)],
}

var invisible_tiles: Array[Vector2i]
var visible_tiles: Array[Vector2i]
var seen_tiles: Array[Vector2i]
var prev_pos: Vector2i

var d: float = 0.0


func _ready() -> void:
	if width == null && height == null:
		width = DisplayServer.window_get_size().x / 16
		height = DisplayServer.window_get_size().y / 16
	
	for pylon in get_tree().get_nodes_in_group("Pylon"):
		active_pylons.append(pylon.position / stone_layer.tile_set.tile_size)
	
	generate_mine(noise_seed)
	handle_player_fov(true)
	handle_pylon_fov()


func _process(delta: float) -> void:
	d += delta

	if d >= 0.1:
		d = 0
		handle_player_fov()
		handle_pylon_fov()

	queue_redraw()


func _draw() -> void:
	var sorted_pylons: Array[Vector2i] = active_pylons
	sorted_pylons.sort() # This needs to be sorted by distance

	for i in range(sorted_pylons.size()):
		if sorted_pylons.size() > 1 and i != sorted_pylons.size() - 1:
			var top_pylon: Vector2i = sorted_pylons[i] + Vector2i(-1, -7)
			var top_pylon_next: Vector2i = sorted_pylons[i + 1] + Vector2i(-1, -7)

			draw_line(top_pylon, top_pylon_next, Color.SKY_BLUE)


func generate_mine(seed: int) -> void:
	noise = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = noise_freq
	noise.seed = seed

	tile_health.clear()
	tile_type.clear()
	ore_type.clear()

	# Add all the stone
	for x in range(width):
		for y in range(height):
			var pos: Vector2i = Vector2i(x, y)

			stone_layer.erase_cell(pos)
			background_layer.set_cell(pos, 0, background_tiles.pick_random())

			if (x == 0 or x >= width - 1) or y == height - 1:
				stone_layer.set_cell(pos, 0, bedrock_tiles.pick_random())
			
			if y >= 0 and y <= 4 and noise.get_noise_2d(x, y) <= rock_threshold * 2:
				stone_layer.set_cell(pos, 0, stone_tiles.pick_random())
				tile_health[pos] = Global.STONE_HEALTH
				tile_type[pos] = Global.TileType.STONE
			elif noise.get_noise_2d(x, y) <= rock_threshold:
				stone_layer.set_cell(pos, 0, stone_tiles.pick_random())
				tile_health[pos] = Global.STONE_HEALTH
				tile_type[pos] = Global.TileType.STONE

	for k in range(Global.OreType.ORE_TYPE_COUNT):
		for x in range(1, width):
			for y in range(1, height):
				var pos: Vector2i = Vector2i(x, y)
				var depth = pos.y
				var ore_dict: Dictionary = Global.ORES[Global.ORES.keys()[k]]
				var type: Global.OreType = k as Global.OreType
				var rolled_chance: float = randf_range(0.0, 1.0)
				var ore_chance: float = ore_dict["base_spawn_chance"]

				if not tile_type.has(pos) or tile_type[pos] != Global.TileType.STONE:
					continue
				
				for i in range(-1, 2):
					for j in range(-1, 2):
						var offset: Vector2i = pos + Vector2i(i, j)
						if ore_type.has(offset) and ore_type.get(offset) == type:
							ore_chance += ore_dict["spawn_chance_increase"]
				
				if rolled_chance <= ore_chance:
					if depth >= ore_dict["spawn_depth"].x and depth <= ore_dict["spawn_depth"].y:
						stone_layer.set_cell(pos, 0, ore_atlas[type][0])
						ore_type[pos] = type
						tile_health.erase(pos)
						tile_type.erase(pos)
	
	for x in range(width):
		for y in range(height):
			var pos: Vector2i = Vector2i(x, y)
			fov_layer.set_cell(pos, 0, fov_tile)
				

func generate_fov() -> void:
	for x in range(width):
		for y in range(height):
			var pos: Vector2i = Vector2i(x, y)

			invisible_tiles.append(pos)
			fov_layer.set_cell(pos, 0, fov_tile)


func handle_player_fov(forced: bool = false) -> void:
	if player == null:
		player = await Global.get_item("player")
	
	var start_pos: Vector2i = stone_layer.local_to_map(player.position)
	
	if not forced and start_pos == prev_pos:
		return
	
	prev_pos = start_pos
	
	var dist: int = player.max_view_distance
	var lines: Array = []

	# Top check
	for x in range(-dist, dist):
		var end_pos: Vector2i = start_pos + Vector2i(x, -dist)
		if do_corners: lines.append(line_gen_corners(start_pos, end_pos))
		else:          lines.append(line_gen_no_corners(start_pos, end_pos))

	# Bottom check
	for x in range(-dist, dist):
		var end_pos: Vector2i = start_pos + Vector2i(x, dist)
		if do_corners: lines.append(line_gen_corners(start_pos, end_pos))
		else:          lines.append(line_gen_no_corners(start_pos, end_pos))
	
	# Left side (without corners)
	for y in range(-dist + 1, dist - 1):
		var end_pos: Vector2i = start_pos + Vector2i(-dist, y)
		if do_corners: lines.append(line_gen_corners(start_pos, end_pos))
		else:          lines.append(line_gen_no_corners(start_pos, end_pos))

	# Right side (without corners)
	for y in range(-dist + 1, dist - 1):
		var end_pos: Vector2i = start_pos + Vector2i(dist, y)
		if do_corners: lines.append(line_gen_corners(start_pos, end_pos))
		else:          lines.append(line_gen_no_corners(start_pos, end_pos))
	
	var current_dynamic: Array = []

	for line in lines:
		if light_blocking:
			var light_blocked: bool = false

			for point in line:
				if point.distance_to(start_pos) > dist:
					continue

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
						continue
					
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
					if tile in seen_tiles:
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
		var dist: int = pylon_view_distance
		var lines: Array = []

		# Top check
		for x in range(-dist, dist):
			var end_pos: Vector2i = start_pos + Vector2i(x, -dist)
			if do_corners: lines.append(line_gen_corners(start_pos, end_pos))
			else:          lines.append(line_gen_no_corners(start_pos, end_pos))

		# Bottom check
		for x in range(-dist, dist):
			var end_pos: Vector2i = start_pos + Vector2i(x, dist)
			if do_corners: lines.append(line_gen_corners(start_pos, end_pos))
			else:          lines.append(line_gen_no_corners(start_pos, end_pos))
		
		# Left side
		for y in range(-dist + 1, dist - 1):
			var end_pos: Vector2i = start_pos + Vector2i(-dist, y)
			if do_corners: lines.append(line_gen_corners(start_pos, end_pos))
			else:          lines.append(line_gen_no_corners(start_pos, end_pos))

		# Right side
		for y in range(-dist + 1, dist - 1):
			var end_pos: Vector2i = start_pos + Vector2i(dist, y)
			if do_corners: lines.append(line_gen_corners(start_pos, end_pos))
			else:          lines.append(line_gen_no_corners(start_pos, end_pos))
			
		for line in lines:
			if light_blocking:
				var light_blocked: bool = false
				for point in line:
					if point.distance_to(start_pos) > dist:
						continue

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
							continue
						
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
				if light_blocking:
					if tile in seen_tiles:
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


func _input(event) -> void:
	if event.is_action_pressed("ui_down"):
		noise_seed = randi_range(0, 214700000)
		generate_mine(noise_seed)

	if event.is_action_pressed("right_click"):
		var pos = Vector2i(get_global_mouse_position())
		var data = stone_layer.get_cell_tile_data(stone_layer.local_to_map(pos))

		print("pos: ", pos)

		# If the block that is clicked is air and the block beneath it is not
		if data == null and stone_layer.get_cell_tile_data(stone_layer.local_to_map(pos + Vector2i(0, stone_layer.tile_set.tile_size.y))):
			var pylon: Pylon = pylon_scene.instantiate()
			var map_pos = stone_layer.local_to_map(pos) * 16 + Vector2i(8, 8)
			pylon.position = map_pos
			active_pylons.append(map_pos)
			get_tree().get_first_node_in_group("WorldRoot").add_child(pylon)


func damage_tile(pos: Vector2i) -> void:
	if tile_type.has(pos):
		tile_type.erase(pos)
		tile_health.erase(pos)
		stone_layer.erase_cell(pos)
		handle_player_fov(true)
		handle_pylon_fov()
	else:
		ore_type.erase(pos)
		stone_layer.erase_cell(pos)
		handle_player_fov(true)
		handle_pylon_fov()


func get_nearest_ore(pos: Vector2i, type: Global.OreType) -> Vector2i:
	return Vector2i.ZERO
