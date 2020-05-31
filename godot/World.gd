extends Node2D

const Bat = preload("res://Enemies/Bat.tscn")
const Player = preload("res://Player/Player.tscn")
const minSpawnDelay = .2

onready var ysort = $YSort
onready var bats = $YSort/Bats
onready var players = $YSort/Players
onready var spawners = $Spawners.get_children()
onready var camera = $Camera2D

onready var waveTimer = $WaveTimer
onready var spawnTimer = $SpawnTimer

var server = true
var firstTick = true
var playersMap = {}

var nextSpawner
var wave
var batsSpawned
var batsKilled
var playerId

func _process(_delta):
	if Input.is_action_just_pressed("attack"):
		restartGame()
	if firstTick:
		firstTick = false

func restartGame():
	if server && players.get_child_count() == 0 && spawnTimer.is_stopped() && !firstTick:
		wave = 1
		nextSpawner = 0

		for bat in bats.get_children():
			bats.remove_child(bat)
			bat.free()

		for id in playersMap:
			var player = Player.instance()
			playersMap[id] = player
			player.id = id
			player.global_position = Vector2(175, 75)

			if id == playerId:
				var remoteTransform2D = RemoteTransform2D.new()
				remoteTransform2D.remote_path = camera.get_path()
				player.add_child(remoteTransform2D)

				if server:
					player.serverPlayer = true

			players.add_child(player)

		PlayerStats.set_health(PlayerStats.max_health)

		waveTimer.start()
		print("Wave 1")

func _on_WaveTimer_timeout():
	batsSpawned = 0
	batsKilled = 0
	spawnBat()

func spawnBat():
	if players.get_child_count():
		var newBat = Bat.instance()
		newBat.global_position = spawners[nextSpawner].global_position
		newBat.player = players.get_child(randi() % players.get_child_count())
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
	if players.get_child_count() && batsKilled >= wave * 5:
		for id in playersMap:
			if !playersMap[id] || !is_instance_valid(playersMap[id]):
				var player = Player.instance()
				playersMap[id] = player
				player.id = id
				player.global_position = Vector2(175, 75)

				if id == playerId:
					var remoteTransform2D = RemoteTransform2D.new()
					remoteTransform2D.remote_path = camera.get_path()
					player.add_child(remoteTransform2D)

					if server:
						player.serverPlayer = true

				players.add_child(player)
			else:
				playersMap[id].health = 4


		wave += 1
		print("Wave %d" % [wave])
		waveTimer.start()

func _playerKilled(player):
	players.remove_child(player)
	playersMap[player.id] = null

	if players.get_child_count() == 0:
		print("Game Over")
		for bat in bats.get_children():
			bat.player = null
		return

	for bat in bats.get_children():
		if bat.player == player:
			bat.player = players.get_child(randi() % players.get_child_count())


func addPlayer(id):
	playersMap[id] = null

func addClientPlayer(id):
	if server:
		return

	var player = Player.instance()
	player.client = true
	player.id = true

	if id == playerId:
		var remoteTransform2D = RemoteTransform2D.new()
		remoteTransform2D.remote_path = camera.get_path()
		player.add_child(remoteTransform2D)

	players.add_child(player)

	#for bat in bats.get_children():
	#	bat.player = player

	return player

func addClientBat(id, newBat):
	if server:
		return

	var bat = Bat.instance()
	bat.id = id
	#bat.player = player
	bat.position = newBat
	bats.add_child(bat)

func removeClientBat(bat):
	bats.remove_child(bat)
	bat.free()
