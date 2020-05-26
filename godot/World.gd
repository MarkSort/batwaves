extends Node2D

const bat = preload("res://Enemies/Bat.tscn")
const minSpawnDelay = .1

onready var ysort = $YSort
onready var player = $YSort/Player
onready var spawners = $Spawners.get_children()

onready var waveTimer = $WaveTimer
onready var spawnTimer = $SpawnTimer

var nextSpawner
var wave
var batsSpawned
var batsKilled

func _ready():
	restartGame()

func restartGame():
	wave = 1
	nextSpawner = 0
	waveTimer.start()
	print("Wave 1")

func _on_WaveTimer_timeout():
	batsSpawned = 0
	batsKilled = 0
	spawnBat()

func spawnBat():
	if is_instance_valid(player):
		var newBat = bat.instance()
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

