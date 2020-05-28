extends Node2D

const Bat = preload("res://Enemies/Bat.tscn")
const Player = preload("res://Player/Player.tscn")
const minSpawnDelay = .2

onready var ysort = $YSort
onready var bats = $YSort/Bats
onready var spawners = $Spawners.get_children()
onready var camera = $Camera2D

onready var waveTimer = $WaveTimer
onready var spawnTimer = $SpawnTimer

var server = true
var firstTick = true

var player
var nextSpawner
var wave
var batsSpawned
var batsKilled

func _process(_delta):
	if Input.is_action_just_pressed("attack"):
		restartGame()
	if firstTick:
		firstTick = false

func restartGame():
	if server && !is_instance_valid(player) && spawnTimer.is_stopped() && !firstTick:
		wave = 1
		nextSpawner = 0

		for bat in bats.get_children():
			bats.remove_child(bat)
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
		newBat.id = batsSpawned
		newBat.connect("killed", self, "_bat_killed")
		bats.add_child(newBat)

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

func addClientPlayer(_id):
	if server:
		return

	player = Player.instance()
	player.client = true
	ysort.add_child(player)

	for bat in bats.get_children():
		bat.player = player

	return player

func addClientBat(id, newBat):
	if server:
		return

	var bat = Bat.instance()
	bat.id = id
	bat.player = player
	bat.position = newBat
	bats.add_child(bat)

func removeClientBat(bat):
	bats.remove_child(bat)
	bat.free()
