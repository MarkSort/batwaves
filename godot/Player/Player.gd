extends KinematicBody2D

const PlayerHurtSound = preload("res://Player/PlayerHurtSound.tscn")

export var ACCELERATION = 500
export var MAX_SPEED = 80
export var ROLL_SPEED = 120
export var FRICTION = 500

enum {
	MOVE,
	ROLL,
	ATTACK
}

var state = MOVE
var velocity = Vector2.ZERO
var roll_vector = Vector2.DOWN
var health = 4

var clientInputVelocity = Vector2.ZERO
var clientAttack = false
var clientRoll = false
var client = false
var serverPlayer = false

onready var animationPlayer = $AnimationPlayer
onready var animationTree = $AnimationTree
onready var animationState = animationTree.get("parameters/playback")
onready var swordHitbox = $HitboxPivot/SwordHitbox
onready var hurtbox = $Hurtbox
onready var blinkAnimationPlayer = $BlinkAnimationPlayer
onready var sprite = $Sprite

var id

func _ready():
	animationTree.active = true
	swordHitbox.knockback_vector = roll_vector
	sprite.material.set_shader_param("active", false)

	if client:
		swordHitbox.setClientMode()
		hurtbox.setClientMode()

func _physics_process(delta):

	match state:
		MOVE:
			move_state(delta)

		ROLL:
			roll_state()

		ATTACK:
			attack_state()

func move_state(delta):
	var input_vector = Vector2.ZERO
	if client:
		input_vector = velocity
	elif serverPlayer:
		input_vector.x = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
		input_vector.y = Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
	else:
		input_vector = clientInputVelocity
	input_vector = input_vector.normalized()

	if input_vector != Vector2.ZERO:
		roll_vector = input_vector
		swordHitbox.knockback_vector = input_vector
		animationTree.set("parameters/Idle/blend_position", input_vector)
		animationTree.set("parameters/Run/blend_position", input_vector)
		animationTree.set("parameters/Attack/blend_position", input_vector)
		animationTree.set("parameters/Roll/blend_position", input_vector)
		animationState.travel("Run")
		velocity = velocity.move_toward(input_vector * MAX_SPEED, ACCELERATION * delta)
	else:
		animationState.travel("Idle")
		velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)

	move()

	if serverPlayer:
		if Input.is_action_just_pressed("roll"):
			state = ROLL
		if Input.is_action_just_pressed("attack"):
			state = ATTACK
	else:
		if clientAttack:
			state = ATTACK
		if clientRoll:
			state = ROLL

func roll_state():
	velocity = roll_vector * ROLL_SPEED
	animationState.travel("Roll")
	move()

func attack_state():
	velocity = Vector2.ZERO
	animationState.travel("Attack")

func move():
	velocity = move_and_slide(velocity)

func roll_animation_finished():
	velocity = velocity * 0.8
	state = MOVE

func attack_animation_finished():
	state = MOVE

func _on_Hurtbox_area_entered(area):
	if client || state == ROLL:
		return

	hurt()

	health -= area.damage

	if serverPlayer:
		PlayerStats.health = health

	if health <= 0:
		get_parent().get_parent().get_parent().removePlayer(self)
		return queue_free()

	startInvincibility()

func hurt():
	var playerHurtSound = PlayerHurtSound.instance()
	get_tree().current_scene.add_child(playerHurtSound)
	hurtbox.create_hit_effect()

func startInvincibility():
	hurtbox.start_invincibility(0.6)

func _on_Hurtbox_invincibility_started():
	blinkAnimationPlayer.play("Start")

func _on_Hurtbox_invincibility_ended():
	blinkAnimationPlayer.play("Stop")
