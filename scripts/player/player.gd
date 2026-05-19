class_name Player
extends CharacterBody2D

@export_category("Player parameters")
var speed: float
## Default speed value
@export var def_speed: float = 150.0
@export var sprint_mult: float = 1.5
@export var walk_mult: float = 0.5
@export var jump_force: float = -275.0
@export var friction: float = 1000.0
@export var max_view_distance: int = 5

@export_category("Mining parameters")
## Number of blocks away from the player that the player can mine
@export var mining_reach: int = 3
## How much damage the pickaxe can do to a tile
@export var pickaxe_damage: float = 1.5
## How many seconds between swings
@export var swing_speed: float = 0.2

@export_category("Debug")
@export var debug_mode: bool = false

@onready var sprite: Sprite2D = %Sprite2D
@onready var collision_shape: CollisionShape2D = %CollisionShape2D
@onready var pickaxe_scale_origin: Node2D = %PickaxeScaleOrigin
@onready var pickaxe_origin: Node2D = %PickaxeOrigin
@onready var animation_player: AnimationPlayer = %AnimationPlayer
@onready var swing_timer: Timer = %SwingTimer

@onready var mine_manager: MineManager

var oxygen: float = 100.0
var power: float = 100.0
## Number of pylons player has in their 'inventory'
var pylons: int = 5

var inventory: Dictionary[String, int] = {}

## The position of the valid tile the player just clicked
var targeted_tile: Vector2i
var can_swing: bool = true

var connected_to_pylon: bool = false


func _ready() -> void:
	if debug_mode:
		Global.set_debug_mode(true)
		collision_shape.disabled = Global.debug_mode

	mine_manager = get_tree().get_first_node_in_group("MineManager")
	speed = def_speed
	swing_timer.wait_time = swing_speed


func _process(delta):
	var dir = Input.get_axis("left", "right");
	var vert_dir = Input.get_axis("up", "down")

	if Input.is_action_pressed("left_click") and can_swing:
		var stone_layer: TileMapLayer = mine_manager.stone_layer
		var mouse_pos: Vector2i = stone_layer.local_to_map(get_global_mouse_position())
		var player_pos: Vector2i = stone_layer.local_to_map(position)
		var fov_layer: TileMapLayer = mine_manager.fov_layer
		var cell_coords: Vector2i = fov_layer.get_cell_atlas_coords(mouse_pos)
		var dist: float = player_pos.distance_to(mouse_pos)

		if not cell_coords == mine_manager.fov_handler.fov_tile and dist <= mining_reach:
			can_swing = false

			if stone_layer.get_cell_tile_data(mouse_pos) or\
			mine_manager.active_pylons.has(mouse_pos):
				targeted_tile = mouse_pos
				animation_player.play("pickaxe_swing")
				await animation_player.animation_finished

			swing_timer.start()
	
	if Input.is_action_pressed("slow_walk"): speed = def_speed * walk_mult
	elif Input.is_action_pressed("sprint"):  speed = def_speed * sprint_mult
	else: 									 speed = def_speed

	if Global.debug_mode:
		if vert_dir: velocity.y = vert_dir * speed;
		else:		 velocity.y = move_toward(velocity.x, 0.0, friction)
	else:
		if not is_on_floor():
			velocity += get_gravity() * delta

		if Input.is_action_just_pressed("jump") and is_on_floor():
			velocity.y = jump_force * (get_gravity().y / 1000)
	
	if dir: velocity.x = dir * speed;
	else:	velocity.x = move_toward(velocity.x, 0.0, friction)

	# Flip the player horizontally depending on their direction and where there mouse was clicked
	if dir < 0 ||\
	  (position.direction_to(get_global_mouse_position()).x < 0 and Input.is_action_pressed("left_click")):
		sprite.scale = Vector2(-1, 1)
		pickaxe_scale_origin.set_scale(Vector2(-1, 1))
	if dir > 0 ||\
	  (position.direction_to(get_global_mouse_position()).x > 0 and Input.is_action_pressed("left_click")):
		sprite.scale = Vector2(1, 1)
		pickaxe_scale_origin.set_scale(Vector2(1, 1))

	move_and_slide()
	

func _input(event):
	if event.is_action_pressed("ui_up"):
		Global.set_debug_mode(not Global.debug_mode)
		collision_shape.disabled = Global.debug_mode
	
	if Global.debug_mode:
		if event.is_action_pressed("ui_accept"):
			position = get_global_mouse_position()


func damage_tile() -> void:
	var stone_layer: TileMapLayer = mine_manager.stone_layer
	var player_pos: Vector2i = stone_layer.local_to_map(position)

	mine_manager.damage_tile(player_pos, targeted_tile, pickaxe_damage)


func give_item(name: String, amount: int) -> void:
	if inventory.has(name): inventory[name] += amount
	else: 					inventory[name] = amount

	print(inventory)


func set_swing_speed(value: float) -> void:
	swing_speed = value


func _on_swing_timer_timeout() -> void:
	can_swing = true
	
