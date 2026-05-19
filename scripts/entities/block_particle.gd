class_name BlockParticle
extends CharacterBody2D

@onready var particle: ColorRect = %Particle
@onready var collision_shape: CollisionShape2D = %CollisionShape2D
@onready var audio_player: AudioStreamPlayer = %AudioStreamPlayer

var dir: Vector2
var friction: float = 500.0
var drop_type: Global.TileType


func _ready() -> void:
	var rx: float = randf_range(-120, 120)
	var ry: float = randf_range(-180, 0)
	
	velocity = Vector2(rx, ry)

	var random_size = randf_range(2.0, 4.0)

	particle.custom_minimum_size = Vector2(random_size, random_size)
	particle.size = Vector2(random_size, random_size)
	particle.position = -particle.size / 2.0

	var col_shape_node: CollisionShape2D = $CollisionShape2D
	col_shape_node.shape = col_shape_node.shape.duplicate()
	
	if col_shape_node.shape is RectangleShape2D:
		col_shape_node.shape.size = Vector2(random_size, random_size)

	set_physics_process(false)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	
	velocity.x = move_toward(velocity.x, 0.0, friction * delta)
	velocity.y = move_toward(velocity.y, 0.0, friction * delta)

	move_and_slide()


func play() -> void:
	set_physics_process(true)


func stop() -> void:
	set_physics_process(false)


func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		var player: Player = body
		var item = str(Global.TileType.keys()[drop_type]).to_lower()

		player.give_item(item, 1)

		audio_player.pitch_scale = randf_range(0.8, 1.2)
		audio_player.reparent(get_tree().get_first_node_in_group("WorldRoot"))
		audio_player.play()

		queue_free()
