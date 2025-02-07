extends Line2D

const MAX_POINTS = 10

@onready var player: Player = $"../Player"

#@onready var player: CharacterBody2D = $"../Player"

func _physics_process(delta: float) -> void:
	add_point(player.position)
	
	if points.size() > MAX_POINTS:
		remove_point(0)
