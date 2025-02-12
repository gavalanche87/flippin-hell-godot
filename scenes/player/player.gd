extends CharacterBody2D


class_name Player


enum PlayerState { IDLE, RUN, JUMP, FALL, HURT }


const FALLEN_OFF_GAP: float = 300.0
const GRAVITY: float = 690.0/1.5
const RUN_SPEED: float = 120.0
const MAX_FALL: float = 400.0
const JUMP_VELOCITY: float = -500 #-260.0 * 1.5
const HURT_JUMP_VELOCITY: Vector2 = Vector2(0, -130.0)

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D

@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var debug_label: Label = $DebugLabel

@onready var shooter: Shooter = $Shooter
@onready var invincible_timer: Timer = $InvincibleTimer
@onready var invincible_player: AnimationPlayer = $InvinciblePlayer
@onready var hurt_timer: Timer = $HurtTimer
@onready var sound: AudioStreamPlayer2D = $Sound
@onready var player_cam: Camera2D = $PlayerCam
@onready var jump_charge_timer: Timer = $JumpChargeTimer
@onready var damager_box: Area2D = $AnimatedSprite2D/DamagerBox


var _state: PlayerState = PlayerState.IDLE
var _invincible: bool = false
var _lives: int = 5

var last_wall_normal: Vector2
var _gravity_on: bool = true

# Called when the node enters the scene tree for the first time.
func _ready() -> void:	
	call_deferred("late_setup")


func late_setup() -> void:
	SignalManager.on_level_started.emit(_lives)
	SignalManager.on_heart_hit.connect(increase_lives)


func set_camera_limits(lim_min: Vector2, lim_max: Vector2) -> void:
	player_cam.limit_bottom = lim_min.y
	player_cam.limit_left = lim_min.x
	player_cam.limit_top = lim_max.y
	player_cam.limit_right = lim_max.x


func isInAir() -> bool:
	return !is_on_floor() and !is_on_ceiling() and !is_on_wall()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta: float) -> void:
	
	fallen_off()
	
	if _gravity_on == false:
		animated_sprite_2d.rotation_degrees += 150 * delta
		pass
	
	if _gravity_on:
		if !is_on_floor() and animated_sprite_2d.rotation_degrees != 180:
			velocity.y += GRAVITY * delta
			
		if !is_on_ceiling() and animated_sprite_2d.rotation_degrees == 180:
			velocity.y -= GRAVITY * delta
				
		if !is_on_wall():
			if animated_sprite_2d.rotation_degrees == 90:
				velocity.y = 0
				velocity.x -= GRAVITY * delta
			elif animated_sprite_2d.rotation_degrees == 270:
				velocity.y = 0
				velocity.x += GRAVITY * delta
			
	
	if is_on_floor():
		_gravity_on = true
		last_wall_normal.x = 0
		last_wall_normal.y = 0
		animated_sprite_2d.rotation_degrees = 0
	elif is_on_ceiling():
		_gravity_on = true
		last_wall_normal.x = 0
		last_wall_normal.y = 0
		animated_sprite_2d.rotation_degrees = 180
	if is_on_wall():
		_gravity_on = true
		last_wall_normal = get_wall_normal()
		velocity.y = 0
		
		if last_wall_normal.x > 0:
			animated_sprite_2d.rotation_degrees = 90
		else:
			animated_sprite_2d.rotation_degrees = 270
	
	get_input()
	move_and_slide()
	calculate_states()
	update_debug_label()
		
		
func fallen_off() -> void:
	
	if (global_position.y > player_cam.limit_top - FALLEN_OFF_GAP and
		global_position.y < player_cam.limit_bottom + FALLEN_OFF_GAP and 
		global_position.x < player_cam.limit_right + FALLEN_OFF_GAP and
	 	global_position.x > player_cam.limit_left - FALLEN_OFF_GAP):
		return 
	
	reduce_lives(1)
	GameManager.reload_current_scene()


func update_debug_label() -> void:
	debug_label.text = "floor:%s
						wall: %s
						ceiling: %s
						grav: %s
						inv:%s\n%s\nvel:(%.0f,%.0f)" % [
		is_on_floor(), is_on_wall(), is_on_ceiling(),_gravity_on, _invincible,
		PlayerState.keys()[_state],
		velocity.x, velocity.y
	]


func shoot() -> void:	
	if animated_sprite_2d.flip_h:
		shooter.shoot(Vector2.LEFT)
	else:
		shooter.shoot(Vector2.RIGHT)


func get_input() -> void:
	
	if _state == PlayerState.HURT:
		return
	
	if Input.is_action_just_pressed("slam") == true and isInAir():
		animated_sprite_2d.flip_v = true
		damager_box.position.y = 15
	
	if !isInAir():
		animated_sprite_2d.flip_v = false
		damager_box.position.y = 0
	
	# If on floor or ceiling
	if is_on_floor() or is_on_ceiling():
		velocity.x = 0
	
	if !is_on_wall() and is_player_vertical():
		if Input.is_action_pressed("left") == true:
			velocity.x = -RUN_SPEED
			if animated_sprite_2d.rotation_degrees == 0:
				animated_sprite_2d.flip_h = false
			elif animated_sprite_2d.rotation_degrees == 180:
				animated_sprite_2d.flip_h = true	
		elif Input.is_action_pressed("right") == true:
			velocity.x = RUN_SPEED
			if animated_sprite_2d.rotation_degrees == 0:
				animated_sprite_2d.flip_h = true
			elif animated_sprite_2d.rotation_degrees == 180:
				animated_sprite_2d.flip_h = false
		
	if !is_on_floor() and !is_on_ceiling() and is_player_horizontal():
		if Input.is_action_pressed("up") == true:
			velocity.y = -RUN_SPEED
			if animated_sprite_2d.rotation_degrees == 90:
				animated_sprite_2d.flip_h = false
			elif animated_sprite_2d.rotation_degrees == 270:
				animated_sprite_2d.flip_h = true
		elif Input.is_action_pressed("down") == true:
			velocity.y = RUN_SPEED
			if animated_sprite_2d.rotation_degrees == 90:
				animated_sprite_2d.flip_h = true
			elif animated_sprite_2d.rotation_degrees == 270:
				animated_sprite_2d.flip_h = false
	
	if is_on_floor():
		if Input.is_action_just_pressed("hop") == true:
			jump_charge_timer.start()
		if Input.is_action_just_released("hop") == true:
			var timeElapsed = jump_charge_timer.wait_time - jump_charge_timer.time_left
			
			timeElapsed = clampf(timeElapsed, 0.25, 1.5)	
			
			velocity.y = JUMP_VELOCITY * (timeElapsed * 1.25)
			jump_charge_timer.stop()
			SoundManager.play_clip(sound, SoundManager.SOUND_JUMP)
			
			
		if Input.is_action_just_pressed("jump"):
			velocity.y = JUMP_VELOCITY
			velocity.x = 0
			_gravity_on = false
			SoundManager.play_clip(sound, SoundManager.SOUND_JUMP)
			
	if is_on_ceiling():
			
		if Input.is_action_just_pressed("hop") == true:
			jump_charge_timer.start()
		if Input.is_action_just_released("hop") == true:
			var timeElapsed = jump_charge_timer.wait_time - jump_charge_timer.time_left
			
			timeElapsed = clampf(timeElapsed, 0.25, 1.5)	
			
			velocity.y = -JUMP_VELOCITY * (timeElapsed * 1.25)
			jump_charge_timer.stop()
			SoundManager.play_clip(sound, SoundManager.SOUND_JUMP)
			
		if Input.is_action_just_pressed("jump"):
			velocity.y = -JUMP_VELOCITY
			velocity.x = 0
			_gravity_on = false
			SoundManager.play_clip(sound, SoundManager.SOUND_JUMP)
	
	# If on wall
	if is_on_wall():
		if Input.is_action_just_pressed("hop") == true:
			jump_charge_timer.start()
			
		if Input.is_action_just_released("hop") == true:
			var timeElapsed = jump_charge_timer.wait_time - jump_charge_timer.time_left
			timeElapsed = clampf(timeElapsed, 0.25, 1.5)	
			
			if last_wall_normal.x > 0:
				velocity.x = -JUMP_VELOCITY * (timeElapsed*1.25)
			else:
				velocity.x = JUMP_VELOCITY * (timeElapsed*1.25)
			velocity.y = 0
			
			
			jump_charge_timer.stop()	
			SoundManager.play_clip(sound, SoundManager.SOUND_JUMP)
			

		if Input.is_action_just_pressed("jump"):
			if last_wall_normal.x > 0:
				velocity.x = -JUMP_VELOCITY
			else:
				velocity.x = JUMP_VELOCITY
			velocity.y = 0
			_gravity_on = false
			SoundManager.play_clip(sound, SoundManager.SOUND_JUMP)
		
		
	velocity.x = clampf(velocity.x, -500, 500)	
	velocity.y = clampf(velocity.y, -500, 500)


func set_state(new_state: PlayerState) -> void:
	
	if new_state == _state:
		return	
		
	if _state == PlayerState.FALL:
		if new_state == PlayerState.IDLE or new_state == PlayerState.RUN:
			SoundManager.play_clip(sound, SoundManager.SOUND_LAND)
	
	_state = new_state
	
	match _state:
		PlayerState.IDLE:
			animated_sprite_2d.play("idle")
		PlayerState.RUN:
			animated_sprite_2d.play("run")
		PlayerState.JUMP:
			animated_sprite_2d.play("jump")
		PlayerState.FALL:
			animated_sprite_2d.play("fall")
		PlayerState.HURT:
			apply_hurt_jump()

func is_player_vertical() -> bool:
	return animated_sprite_2d.rotation_degrees == 0 or animated_sprite_2d.rotation_degrees == 180

func is_player_horizontal() -> bool:
	return animated_sprite_2d.rotation_degrees == 90 or animated_sprite_2d.rotation_degrees == 270

func calculate_states() -> void:
	
	if _state == PlayerState.HURT:
		return
	
	if is_player_vertical():
		if is_on_floor() or is_on_ceiling():
			if velocity.x == 0:
				set_state(PlayerState.IDLE)
			else:
				set_state(PlayerState.RUN)
		else:
			if velocity.y > 0:
				set_state(PlayerState.FALL)
			else:
				set_state(PlayerState.JUMP)
	else:
		if is_on_wall() == true:
			if velocity.y == 0:
				set_state(PlayerState.IDLE)
			else:
				set_state(PlayerState.RUN)
		else:
			if velocity.x > 0:
				set_state(PlayerState.JUMP)
			else:
				set_state(PlayerState.FALL)


func reduce_lives(reduction: int) -> bool:
	_lives -= reduction
	SignalManager.on_player_hit.emit(_lives)
	SignalManager.on_player_lives_changed.emit(_lives)
	if _lives <= 0:
		SignalManager.on_game_over.emit()
		set_physics_process(false)
		animated_sprite_2d.stop()
		invincible_player.stop()
		print("PLAYER DIES")
		return false
	return true

func increase_lives(numLivesToAdd: int) -> void:
	_lives += numLivesToAdd
	SignalManager.on_player_lives_changed.emit(_lives)
	if (_lives >= 5):
		_lives = 5

func go_invincible() -> void:
	_invincible = true
	invincible_player.play("invincible")
	call_deferred("set_damager_box_enabled", false)
	invincible_timer.start()

func set_damager_box_enabled(enabled: bool) -> void:
	damager_box.monitoring = enabled
	damager_box.monitorable = enabled

func apply_hurt_jump() -> void:
	animated_sprite_2d.play("hurt")
	velocity = HURT_JUMP_VELOCITY
	hurt_timer.start()


func apply_hit() -> void:
	if _invincible == true:
		return
		
	if reduce_lives(1) == false:
		return
		
	SoundManager.play_clip(sound, SoundManager.SOUND_DAMAGE)
	go_invincible()
	set_state(PlayerState.HURT)


func _on_invincible_timer_timeout() -> void:
	_invincible = false
	call_deferred("set_damager_box_enabled", true)
	invincible_player.stop()


func _on_hit_box_area_entered(_area: Area2D) -> void:
	apply_hit()


func _on_hurt_timer_timeout() -> void:
	set_state(PlayerState.IDLE)
