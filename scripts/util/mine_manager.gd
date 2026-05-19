class_name MineManager
extends Node2D

@export var width: int
@export var height: int
@export var fog_of_war: bool = true
@export var do_corners: bool = true
@export var light_blocking: bool = true
@export var keep_visited_tiles: bool = false

@onready var fov_layer: TileMapLayer = %FovLayer
@onready var background_layer: TileMapLayer = %BackgroundLayer
@onready var stone_layer: TileMapLayer = %StoneLayer
@onready var damage_layer: TileMapLayer = %DamageLayer
@onready var tile_hit_player: AudioStreamPlayer = %TileHitPlayer

# Preloads
@onready var block_particles2d_scene: PackedScene = preload("res://scenes/block_particles.tscn")

@onready var hit_sound = preload("res://assets/audio/single_stone_hit.wav")
@onready var break_sound = preload("res://assets/audio/block_explosion.wav")

@onready var player: Player

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
var ore_type: Dictionary[Vector2i, Global.TileType]

# Texture atlas'
var stone_tiles: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0)]
var bedrock_tiles: Array[Vector2i] = [Vector2i(0, 1), Vector2i(1, 1)]
var background_tiles: Array[Vector2i] = [Vector2i(2, 0), Vector2i(3, 0)]
var damage_states: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0), Vector2i(5, 0)]
var darkness_tile: Vector2i = Vector2i(0, 1)

var ore_atlas: Dictionary[Global.OreType, Array] = {
	Global.OreType.COAL: [Vector2i(0, 2)],
	Global.OreType.IRON: [Vector2i(1, 2)],
	Global.OreType.GOLD: [Vector2i(2, 2)],
}

var d: float = 0.0
var fov_handler: FovHandler


func _ready() -> void:
	if width == 0 && height == 0:
		width = DisplayServer.window_get_size().x / 16
		height = DisplayServer.window_get_size().y / 16
	
	for pylon in get_tree().get_nodes_in_group("Pylon"):
		active_pylons.append(stone_layer.local_to_map(pylon.position))
	
	player = get_tree().get_first_node_in_group("Player")
	
	fov_handler = FovHandler.new(
		fov_layer,
		stone_layer,
		player,
		active_pylons,
		width,
		height,
		fog_of_war,
		do_corners,
		light_blocking,
		keep_visited_tiles
	)

	generate_mine(noise_seed)

	if fog_of_war:
		fov_handler.generate_fov()
		fov_handler.handle_player_fov(true)
		fov_handler.handle_pylon_fov()


func _process(delta: float) -> void:
	d += delta

	if d >= 0.1:
		d = 0

		if fog_of_war:
			fov_handler.handle_player_fov()
			fov_handler.handle_pylon_fov()

	queue_redraw()


func _draw():
	if active_pylons.is_empty():
			return

	var unconnected: Array[Vector2] = []
	for pylon in active_pylons:
		unconnected.append(stone_layer.map_to_local(pylon))

	var connected: Array[Vector2] = []
	var edges: Array[Array] = []

	connected.append(unconnected.pop_front())

	while unconnected.size() > 0:
		var shortest_dist: float = INF
		var best_connected_index: int = -1
		var best_unconnected_index: int = -1

		for i in range(connected.size()):
			for j in range(unconnected.size()):
				var dist = connected[i].distance_to(unconnected[j])
				if dist < shortest_dist:
					shortest_dist = dist
					best_connected_index = i
					best_unconnected_index = j
		
		if shortest_dist > Global.PYLON_CONNECTION_DISTANCE:
			break

		var new_pylon = unconnected[best_unconnected_index]
		connected.append(new_pylon)
		edges.append([connected[best_connected_index], new_pylon])
		unconnected.remove_at(best_unconnected_index)

	for edge in edges:
		var pylon_a: Vector2 = edge[0] + Vector2(0, -6)
		var pylon_b: Vector2 = edge[1] + Vector2(0, -6)
		draw_line(pylon_a, pylon_b, Color.SKY_BLUE)

	if connected.size() > 0:
		var player_pos: Vector2 = player.position # Ensure this stays Vector2, not Vector2i
		
		var closest_anchor: Vector2 = connected[0] + Vector2(0, -6)
		var min_distance: float = player_pos.distance_to(closest_anchor)

		for pylon in connected:
			var pylon_top = pylon + Vector2(0, -6)
			var current_distance = player_pos.distance_to(pylon_top)
			
			if current_distance < min_distance:
				min_distance = current_distance
				closest_anchor = pylon_top
				
		for edge in edges:
			var pylon_a = edge[0] + Vector2(0, -6)
			var pylon_b = edge[1] + Vector2(0, -6)
			
			var closest_point_on_wire = Geometry2D.get_closest_point_to_segment(player_pos, pylon_a, pylon_b)
			var dist_to_wire = player_pos.distance_to(closest_point_on_wire)
			
			if dist_to_wire < min_distance:
				min_distance = dist_to_wire
				closest_anchor = closest_point_on_wire
		
		if closest_anchor.distance_to(player_pos) <= Global.PYLON_CONNECTION_DISTANCE:
			player.connected_to_pylon = true
			draw_line(closest_anchor, player_pos, Color.LIGHT_BLUE)
		else:
			player.connected_to_pylon = false


func _input(event) -> void:
	if event.is_action_pressed("ui_down"):
		noise_seed = randi_range(0, 214700000)
		generate_mine(noise_seed)

	if event.is_action_pressed("right_click"):
		var pos = Vector2i(get_global_mouse_position())
		var data = stone_layer.get_cell_tile_data(stone_layer.local_to_map(pos))

		print("pos: ", pos)

		# If the block that is clicked is air and the block beneath it is not
		if data == null and\
		   stone_layer.get_cell_tile_data(stone_layer.local_to_map(pos + Vector2i(0, stone_layer.tile_set.tile_size.y))) and\
		   not active_pylons.has(stone_layer.local_to_map(pos)):
			var pylon: Pylon = pylon_scene.instantiate()
			var grid_pos = stone_layer.local_to_map(pos)
			var pixel_pos = grid_pos * 16 + Vector2i(8, 8)
			
			pylon.position = pixel_pos
			active_pylons.append(grid_pos) # Append the raw grid coordinate for the FOV math
			
			get_tree().get_first_node_in_group("WorldRoot").add_child(pylon)
	
	if Global.debug_mode:
		if event.is_action_pressed("ui_page_up"):
			rock_threshold += 0.02
			print("rock threshold: ", rock_threshold)
		elif event.is_action_pressed("ui_page_down"):
			rock_threshold -= 0.02
			print("rock threshold: ", rock_threshold)


func generate_mine(seed: int) -> void:
	noise = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = noise_freq
	noise.seed = seed

	tile_health.clear()
	tile_type.clear()
	ore_type.clear()

	background_layer.clear()
	fov_layer.clear()
	stone_layer.clear()
	damage_layer.clear()

	# Add all the stone
	for x in range(width):
		for y in range(height):
			var pos: Vector2i = Vector2i(x, y)

			stone_layer.erase_cell(pos)
			background_layer.set_cell(pos, 0, background_tiles.pick_random())

			if (x == 0 or x >= width - 1) or y == height - 1 or y == 0:
				stone_layer.set_cell(pos, 0, bedrock_tiles.pick_random())
			elif noise.get_noise_2d(x, y) <= rock_threshold:
				stone_layer.set_cell(pos, 0, stone_tiles.pick_random())
				damage_layer.set_cell(pos, 0, damage_states[0])
				tile_health[pos] = Global.STONE_HEALTH
				tile_type[pos] = Global.TileType.STONE

	for k in range(Global.OreType.ORE_TYPE_COUNT):
		for x in range(1, width):
			for y in range(1, height):
				var pos: Vector2i = Vector2i(x, y)
				var depth = pos.y
				var ore_dict: Dictionary = Global.ORES[Global.ORES.keys()[k]]
				var type: Global.TileType = k as Global.TileType
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
						damage_layer.set_cell(pos, 0, damage_states[0])
						ore_type[pos] = type
						tile_health[pos] = Global.ORES[ore_type[pos] + 1]["health"]
						tile_type.erase(pos)


func damage_tile(player_pos: Vector2i, pos: Vector2i, damage: float) -> bool:
	if tile_type.has(pos):
		tile_health[pos] -= damage

		if tile_health[pos] <= 0:
			var gradient: Gradient = Gradient.new()
			gradient.set_color(0, Color(0.2, 0.2, 0.2, 1.0)) # Dark gray to 
			gradient.set_color(1, Color(0.7, 0.7, 0.7, 1.0)) # Light gray
			var block_particles: BlockParticles2D = BlockParticles2D.new(
				Global.TileType.STONE,
				gradient,
				Global.STONE_YIELD,
			)
			block_particles.position = stone_layer.map_to_local(pos)
			get_tree().get_first_node_in_group("WorldRoot").add_child(block_particles)
			block_particles.play()
			tile_type.erase(pos)
			tile_health.erase(pos)

			stone_layer.erase_cell(pos)
			damage_layer.erase_cell(pos)

			tile_hit_player.pitch_scale = randf_range(0.8, 1.2)
			tile_hit_player.stream = break_sound
			tile_hit_player.play()
		else:
			var current_health: float = tile_health[pos]
			var max_health: float = Global.STONE_HEALTH
			var idx: int = (1 - (current_health / max_health)) * (damage_states.size() - 1)

			damage_layer.set_cell(pos, 0, damage_states[idx])

			tile_hit_player.pitch_scale = randf_range(0.8, 1.2)
			tile_hit_player.stream = hit_sound
			tile_hit_player.play()

		fov_handler.handle_player_fov(true)
		fov_handler.handle_pylon_fov()

		return true
	elif ore_type.has(pos):
		tile_health[pos] -= damage

		if tile_health[pos] <= 0:
			var gradient: Gradient = Gradient.new()
			gradient.set_color(0, Global.ORES[ore_type[pos] + 1]["color1"])
			gradient.set_color(1, Global.ORES[ore_type[pos] + 1]["color2"]) # Light gray
			var block_particles: BlockParticles2D = BlockParticles2D.new(
				ore_type[pos] + 1,
				gradient,
				Global.ORES[ore_type[pos] + 1]["yield"],
			)
			block_particles.position = stone_layer.map_to_local(pos)
			get_tree().get_first_node_in_group("WorldRoot").add_child(block_particles)
			block_particles.play()
			ore_type.erase(pos)
			tile_health.erase(pos)

			stone_layer.erase_cell(pos)
			damage_layer.erase_cell(pos)

			tile_hit_player.pitch_scale = randf_range(0.8, 1.2)
			tile_hit_player.stream = break_sound
			tile_hit_player.play()
		else:
			var current_health: float = tile_health[pos]
			var max_health: float = Global.ORES[ore_type[pos] + 1]["health"]
			var idx: int = (1 - (current_health / max_health)) * (damage_states.size() - 1)

			print("current health: ", current_health)
			print("max health: ", max_health)
			print("idx: ", idx)

			damage_layer.set_cell(pos, 0, damage_states[idx])

			tile_hit_player.pitch_scale = randf_range(0.8, 1.2)
			tile_hit_player.stream = hit_sound
			tile_hit_player.play()

		fov_handler.handle_player_fov(true)
		fov_handler.handle_pylon_fov()

		return true
	elif active_pylons.has(pos):
		for pylon in get_tree().get_nodes_in_group("Pylon"):
			if stone_layer.local_to_map(pylon.position) == pos:
				active_pylons.erase(pos)
				fov_handler.handle_pylon_fov()
				pylon.queue_free()

				tile_hit_player.pitch_scale = randf_range(0.8, 1.2)
				tile_hit_player.stream = break_sound
				tile_hit_player.play()
				return true
	
	return false


func get_nearest_ore(pos: Vector2i, type: Global.OreType) -> Vector2i:
	return Vector2i.ZERO
