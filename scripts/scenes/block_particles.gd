class_name BlockParticles2D
extends Node2D

## Color gradient for each particle
@export var color_gradient: Gradient
@export var num_particles: int = 16
## Lifetime in seconds
@export var lifetime: float = 1.0
@export var drop_type: Global.TileType

var particles: Array[BlockParticle] = []
@onready var particle_scene: PackedScene = preload("res://entities/block_particle.tscn")



func _init(drop_type: Global.TileType, color_gradient: Gradient, num_particles: int, lifetime: float = 5.0) -> void:
	self.drop_type = drop_type
	self.color_gradient = color_gradient
	self.num_particles = num_particles
	self.lifetime = lifetime


func _ready() -> void:
	for i in range(num_particles):
		var particle: BlockParticle = particle_scene.instantiate()
		var color_pos = float(i) / float(num_particles)
		var particle_color: Color = color_gradient.sample(color_pos)

		particle.drop_type = drop_type
		particle.get_node("%Particle").color = particle_color
		
		particles.append(particle)
		add_child(particle)

	get_tree().create_timer(lifetime).timeout.connect(queue_free)


func play() -> void:
	for particle in particles:
		particle.play()


func stop() -> void:
	for particle in particles:
		particle.stop()
