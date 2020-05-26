extends Node2D

const Bat = preload("res://Enemies/Bat.tscn")
const Player = preload("res://Player/Player.tscn")
const minSpawnDelay = .1

onready var ysort = $YSort
onready var spawners = $Spawners.get_children()
onready var camera = $Camera2D

onready var waveTimer = $WaveTimer
onready var spawnTimer = $SpawnTimer

var player
var nextSpawner
var wave
var batsSpawned
var batsKilled

func _process(_delta):
	if Input.is_action_just_pressed("attack"):
		restartGame()

func restartGame():
	if !is_instance_valid(player) && spawnTimer.is_stopped():
		wave = 1
		nextSpawner = 0

		for bat in ysort.get_children():
			ysort.remove_child(bat)
			bat.free()

		var remoteTransform2D = RemoteTransform2D.new()
		remoteTransform2D.remote_path = camera.get_path()

		player = Player.instance()
		player.global_position = Vector2(175, 75)
		player.add_child(remoteTransform2D)
		ysort.add_child(player)

		PlayerStats.set_health(PlayerStats.max_health)

		waveTimer.start()
		print("Wave 1")

func _on_WaveTimer_timeout():
	batsSpawned = 0
	batsKilled = 0
	spawnBat()

func spawnBat():
	if is_instance_valid(player):
		var newBat = Bat.instance()
		newBat.global_position = spawners[nextSpawner].global_position
		newBat.player = player
		newBat.connect("killed", self, "_bat_killed")
		ysort.add_child(newBat)

		nextSpawner += 1
		if nextSpawner >= spawners.size():
			nextSpawner = 0

		batsSpawned += 1
		if batsSpawned < wave * 5:
			spawnTimer.start(1 - (wave - 1) * .1)

func _on_SpawnTimer_timeout():
	spawnBat()

func _bat_killed():
	batsKilled += 1
	if is_instance_valid(player) && batsKilled >= wave * 5:
		wave += 1
		print("Wave %d" % [wave])
		waveTimer.start()

