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
const STONE_YIELD = 4

const STONE_STRING = "stone"
const COAL_STRING = "coal"
const IRON_STRING = "iron"
const GOLD_STRING = "gold"

const ORES: Dictionary[TileType, Dictionary] = {
	TileType.COAL: {
		"health": 2.0,					  		# How much damage this ore can take before it is destroyed
		"spawn_depth": Vector2i(0, 2048), 		# spawn_depth x-axis is min height, y-axis is max height
		"base_spawn_chance": 0.016, 	  		# Base spawn chance %
		"spawn_chance_increase": 0.20,	  		# How much the spawn chance should be increased in certain scenarios
		"yield": 5,						  		# How much material this ore drops once broken
		"color1": Color(0.2, 0.2, 0.2, 1.0),	# Color on the left-side of the gradient
		"color2": Color(0.35, 0.35, 0.35, 1.0),	# Color on the right-side of the gradient
	},
	TileType.IRON: {
		"health": 6.0,
		"spawn_depth": Vector2i(25, 150),
		"base_spawn_chance": 0.01,
		"spawn_chance_increase": 0.1,
		"yield": 5,
		"color1": Color(0.81, 0.42, 0.0, 1.0),
		"color2": Color(0.45, 0.23, 0.0, 1.0),
	},
	TileType.GOLD: {
		"health": 3.5,
		"spawn_depth": Vector2i(90, 350),
		"base_spawn_chance": 0.02,
		"spawn_chance_increase": 0.05,
		"yield": 3,
		"color1": Color(1.0 , 0.80, 0.0, 1.0),
		"color2": Color(0.55, 0.45, 0.0, 1.0),
	}
}

const PYLON_CONNECTION_DISTANCE = 16 * 6 # Distance in pixels

var debug_mode: bool = false

func set_debug_mode(mode: bool):
	debug_mode = mode
	print("Debug mode toggled: {" + str(debug_mode) + "}")
