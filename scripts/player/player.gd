class_name Player
extends CharacterBody2D

@export_category("Player paramters")
@export var speed: float = 150.0
@export var jump_force: float = -275.0
@export var friction: float = 1000.0
@export var max_view_distance: int = 10

@export_category("Debug")
@export var debug_mode: bool = false


@onready var sprite: Sprite2D = %Sprite2D
@onready var collision_shape: CollisionShape2D = %CollisionShape2D

@onready var mine_manager: MineManager = get_tree().get_first_node_in_group("MineManager")


func _ready() -> void:
	if debug_mode:
		Global.set_debug_mode(true)
		collision_shape.disabled = Global.debug_mode


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

	if dir < 0: sprite.scale = Vector2(-1, 1)
	if dir > 0: sprite.scale = Vector2( 1, 1)

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

	pos = pos / stone_layer.tile_set.tile_size

	if pos.x >= 0 and pos.y >= 0 and pos.x <= map_size.x and pos.y <= map_size.y:
		mine_manager.damage_tile(pos)
