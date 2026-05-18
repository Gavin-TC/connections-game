extends Node2D

@onready var audio_player: AudioStreamPlayer2D = %AudioStreamPlayer2D


func _ready() -> void:
	audio_player.play()
