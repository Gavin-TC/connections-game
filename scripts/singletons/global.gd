extends Node

enum TileType {
	STONE,
	COAL,
	IRON,
	GOLD,
	EMERALD,
	TILE_TYPE_COUNT
}

enum OreType {
	COAL,
	IRON,
	GOLD,
	ORE_TYPE_COUNT
}

const STONE_HEALTH = 3.5

const ORES: Dictionary[TileType, Dictionary] = {
	TileType.COAL: {
		"health": 2.0,					  # How much damage this ore can take before it is destroyed
		"spawn_depth": Vector2i(0, 2048), # spawn_depth x-axis is min height, y-axis is max height
		"base_spawn_chance": 0.008, 	  # Base spawn chance %
		"spawn_chance_increase": 0.20,	  # How much the spawn chance should be increased in certain scenarios
		"yield": 5,						  # How much material this ore drops once broken
	},
	TileType.IRON: {
		"health": 6.0,
		"spawn_depth": Vector2i(25, 150),
		"base_spawn_chance": 0.005,
		"spawn_chance_increase": 0.20,
		"yield": 5,
	},
	TileType.GOLD: {
		"health": 3.5,
		"spawn_depth": Vector2i(90, 350),
		"base_spawn_chance": 0.002,
		"spawn_chance_increase": 0.12,
		"yield": 3,
	}
}

const PYLON_CONNECTION_DISTANCE = 16 * 6 # Distance in pixels

var debug_mode: bool = false

func set_debug_mode(mode: bool):
	debug_mode = mode
	print("Debug mode toggled: {" + str(debug_mode) + "}")
