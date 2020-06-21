extends Node2D

const Bat = preload("res://Enemies/Bat.tscn")
const Player = preload("res://Player/Player.tscn")
const minSpawnDelay = .2

onready var ysort = $YSort
onready var bats = $YSort/Bats
onready var players = $YSort/Players
onready var spawners = $Spawners.get_children()
onready var camera = $Camera2D
onready var status = $CanvasLayer/Status

onready var waveTimer = $WaveTimer
onready var spawnTimer = $SpawnTimer
onready var gameOverTimer = $GameOverTimer

var server = true
var firstTick = true
var playersMap = {}
var playerSkins = {}
var skin = 0
var gameOver = true

var nextSpawner
var wave = 1
var batsSpawned
var batsKilled
var playerId

func _process(_delta):
	if Input.is_action_just_pressed("attack"):
		restartGame()
	if firstTick:
		firstTick = false

func restartGame():
	if server && gameOver && !firstTick:
		gameOver = false
		wave = 1
		nextSpawner = 0

		for bat in bats.get_children():
			bats.remove_child(bat)
			bat.free()

		for id in playersMap:
			var player = Player.instance()
			playersMap[id] = player
			player.id = id
			player.skin = getSkin(id)
			player.global_position = Vector2(175, 75)

			if id == playerId:
				var remoteTransform2D = RemoteTransform2D.new()
				remoteTransform2D.remote_path = camera.get_path()
				player.add_child(remoteTransform2D)

				if server:
					player.serverPlayer = true

			players.add_child(player)

		PlayerStats.set_health(PlayerStats.max_health)

		status.text = "Wave 1"
		waveTimer.start()

func _on_WaveTimer_timeout():
	status.text = ""
	batsSpawned = 0
	batsKilled = 0
	spawnBat()

func spawnBat():
	if players.get_child_count():
		var newBat = Bat.instance()
		newBat.global_position = spawners[nextSpawner].global_position
		newBat.player = players.get_child(randi() % players.get_child_count())
		newBat.id = batsSpawned
		if server:
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
				player.skin = getSkin(id)
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
		status.text = "Wave %d" % [wave]
		waveTimer.start()

		PlayerStats.set_health(PlayerStats.max_health)

func getSkin(id):
	if skin && id == playerId:
		return skin
	if playerSkins.has(id):
		return playerSkins[id]
	return 1

func removePlayer(player):
	players.remove_child(player)
	playersMap[player.id] = null

	if players.get_child_count() == 0:
		gameOverTimer.start()
		status.text = "Game Over\non Wave %d" % [wave]
		for bat in bats.get_children():
			bat.player = null
		return

	for bat in bats.get_children():
		if bat.player == player:
			bat.player = players.get_child(randi() % players.get_child_count())

func disconnectPlayer(playerId):
	var player = playersMap[playerId]

	if player:
		removePlayer(player)

	playersMap.erase(playerId)

func addPlayer(id):
	playersMap[id] = null

func addClientPlayer(id):
	if server:
		return

	var player = Player.instance()
	player.client = true
	player.id = id
	player.skin = getSkin(id)

	if id == playerId:
		var remoteTransform2D = RemoteTransform2D.new()
		remoteTransform2D.remote_path = camera.get_path()
		player.add_child(remoteTransform2D)

	players.add_child(player)
	playersMap[id] = player

	return player

func addClientBat(id, newBat):
	if server:
		return

	var bat = Bat.instance()
	bat.id = id
	bat.position = newBat.position
	bat.velocity = newBat.velocity
	bat.startHealth = newBat.health

	bats.add_child(bat)

func removeClientBat(bat):
	bats.remove_child(bat)
	bat.free()


func _on_GameOverTimer_timeout():
	gameOver = true
	status.text += "\n\nAttack to Restart"
