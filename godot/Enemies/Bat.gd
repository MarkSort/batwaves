extends KinematicBody2D

const EnemyDeathEffect = preload("res://Effects/EnemyDeathEffect.tscn")

export var ACCELERATION = 200
export var MAX_SPEED = 30
export var FRICTION = 150

var velocity = Vector2.ZERO
var knockback = Vector2.ZERO
var startHealth = 2

onready var sprite = $AnimatedSprite
onready var stats = $Stats
onready var hurtbox = $Hurtbox
onready var softCollision = $SoftCollision
onready var animationPlayer = $AnimationPlayer

var player
var id

signal killed

func _ready():
	stats.health = startHealth

func _physics_process(delta):
	knockback = knockback.move_toward(Vector2.ZERO, FRICTION * delta)
	knockback = move_and_slide(knockback)

	if player != null && is_instance_valid(player):
		accelerate_towards_point(player.global_position, delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)

	if softCollision.is_colliding():
		velocity += softCollision.get_push_vector() * delta * 400
	velocity = move_and_slide(velocity)

func accelerate_towards_point(point, delta):
	var direction = global_position.direction_to(point)
	velocity = velocity.move_toward(direction * MAX_SPEED, ACCELERATION * delta)
	sprite.flip_h = velocity.x < 0

func _on_Hurtbox_area_entered(area):
	stats.health -= area.damage
	knockback = area.knockback_vector * 150
	startHurt()

func startHurt():
	hurtbox.create_hit_effect()
	hurtbox.start_invincibility(0.4)

func _on_Stats_no_health():
	queue_free()
	var enemyDeathEffect = EnemyDeathEffect.instance()
	get_parent().get_parent().add_child(enemyDeathEffect)
	enemyDeathEffect.global_position = global_position
	emit_signal("killed")

func _on_Hurtbox_invincibility_started():
	animationPlayer.play("Start")

func _on_Hurtbox_invincibility_ended():
	animationPlayer.play("Stop")
