extends Node2D


const TRIGGER_CONDITION: String = "parameters/conditions/on_trigger"


@export var lives: int = 2
@export var points: int = 5


@onready var visual: Node2D = $Visual
@onready var animation_tree: AnimationTree = $AnimationTree
@onready var state_machine: AnimationNodeStateMachinePlayback = $AnimationTree["parameters/playback"]
@onready var hit_box: Area2D = $Visual/HitBox


var _invincible: bool = false
var _tween: Tween

func reduce_lives() -> void:
	lives -= 1
	if lives <= 0:
		SignalManager.on_boss_killed.emit(points)
		_tween.kill()
		queue_free()


func tween_hit() -> void:
	_tween = get_tree().create_tween()
	_tween.tween_property(visual, "position", Vector2.ZERO, 1.6)


func set_invincible(v: bool) -> void:
	_invincible = v
	if v == true:
		state_machine.travel("hit")
		
		
func take_damage() -> void:
	if _invincible == true:
		return
		
	set_invincible(true)
	tween_hit()
	reduce_lives()


func _on_trigger_area_entered(_area: Area2D) -> void:
	animation_tree[TRIGGER_CONDITION] = true
	hit_box.monitoring = true


func _on_hit_box_area_entered(_area: Area2D) -> void:
	take_damage()
