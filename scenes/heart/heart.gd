extends Area2D


@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var sound: AudioStreamPlayer2D = $Sound
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var collision_shape_2d: CollisionShape2D = $CollisionShape2D


const GRAVITY: float = 160.0
const JUMP: float = -120.0
const LIVES: int = 1


var _start_y: float
var _speed_y: float = JUMP


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	
	_start_y = position.y
	
	var ln: Array[String] = []
	for an in anim.sprite_frames.get_animation_names():
		ln.push_back(an)
	anim.animation = ln.pick_random()
	
	#animation_player.play("collected")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	#position.y += _speed_y * delta
	#_speed_y += GRAVITY * delta
	pass
	#if position.y > _start_y:
	#	set_process(false)


func kill_me() -> void:
	hide()
	queue_free()


func _on_area_entered(_area: Area2D) -> void:
	SignalManager.on_heart_hit.emit(LIVES)
	SoundManager.play_clip(sound, SoundManager.SOUND_PICKUP)
	animation_player.play("collected")
	set_deferred("monitoring", false)
	


func _on_sound_finished() -> void:
	pass


func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	kill_me()
