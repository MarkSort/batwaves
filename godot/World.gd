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

func _on_WaveTimer_timeout():
	print("_on_WaveTimer_timeout")
	batsSpawned = 0
	batsKilled = 0
	spawnBat()

func spawnBat():
	if is_instance_valid(player):
		print("spawnBat")
		var newBat = bat.instance()
		ysort.add_child(newBat)
		newBat.global_position = spawners[nextSpawner].global_position
		newBat.player = player

		nextSpawner += 1
		if nextSpawner >= spawners.size():
			nextSpawner = 0

		batsSpawned += 1
		if batsSpawned < wave * 5:
			print("spawnTimer.start()")
			spawnTimer.start(1 - (wave - 1) * .1)


func _on_SpawnTimer_timeout():
	print("_on_SpawnTimer_timeout")
	spawnBat()
