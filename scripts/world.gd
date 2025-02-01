# world.gd
extends Node2D

func _ready():
	# Let GameManager know the world is ready for players
	GameManager._on_world_ready()
