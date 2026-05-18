class_name Player
extends CharacterBody2D

@export_category("Player paramters")
@export var speed: float = 150.0
@export var jump_force: float = -275.0
@export var friction: float = 1000.0
@export var max_view_distance: int = 5
## Number of blocks away from the player that the player can mine
@export var mining_reach: int = 3

@export_category("Debug")
@export var debug_mode: bool = false


@onready var sprite: Sprite2D = %Sprite2D
@onready var collision_shape: CollisionShape2D = %CollisionShape2D
@onready var pickaxe_origin: Node2D = %PickaxeOrigin
@onready var animation_player: AnimationPlayer = %AnimationPlayer

@onready var mine_manager: MineManager = get_tree().get_first_node_in_group("MineManager")

var oxygen: float = 100.0
var power: float = 100.0

var connected_to_pylon: bool = false


func _ready() -> void:
	if debug_mode:
		Global.set_debug_mode(true)
		collision_shape.disabled = Global.debug_mode
	mining_reach *= 16


func _process(delta):
	var dir = Input.get_axis("left", "right");
	var vert_dir = Input.get_axis("jump", "down")

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

	if dir < 0: scale = Vector2(-1, 1)
	if dir > 0:	scale = Vector2(1, 1)

	move_and_slide()
	

func _input(event):
	if event.is_action_pressed("ui_up"):
		Global.set_debug_mode(not Global.debug_mode)
		collision_shape.disabled = Global.debug_mode
	
	if Global.debug_mode:
		if event.is_action_pressed("ui_accept"):
			position = get_global_mouse_position()

	if event.is_action_pressed("left_click"):
		damage_tile(Vector2i(get_global_mouse_position()))


func damage_tile(pos: Vector2i) -> void:
	var stone_layer: TileMapLayer = mine_manager.stone_layer
	var map_size: Vector2i = stone_layer.get_used_rect().size

	var map_pos = stone_layer.local_to_map(pos)
	var dist = pos.distance_to(position)

	if map_pos.x >= 0 and map_pos.y >= 0 and map_pos.x <= map_size.x and map_pos.y <= map_size.y and dist < mining_reach:
		if mine_manager.damage_tile(map_pos):
			pickaxe_origin.visible = true
			animation_player.play("pickaxe_swing")
			await animation_player.animation_finished
			pickaxe_origin.visible = false
