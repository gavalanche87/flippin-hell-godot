extends Area2D


const TRIGGER_CONDITION: String = "parameters/conditions/on_trigger"


@onready var animation_tree: AnimationTree = $AnimationTree
@onready var sound: AudioStreamPlayer2D = $Sound
@onready var sprite_2d: Sprite2D = $Sprite2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	SignalManager.on_boss_killed.connect(on_boss_killed)
	on_boss_killed(1)

func on_boss_killed(_p: int) -> void:
	sprite_2d.show()
	animation_tree[TRIGGER_CONDITION] = true
	monitoring = true
	SoundManager.play_clip(sound, SoundManager.SOUND_CHECKPOINT)


func _on_area_entered(_area: Area2D) -> void:
	SoundManager.play_clip(sound, SoundManager.SOUND_WIN)
	SignalManager.on_level_complete.emit()
