extends Node2D

const bat = preload("res://Enemies/Bat.tscn")
const spawnDelay = 1

onready var ysort = $YSort
onready var player = $YSort/Player
onready var spawners = $Spawners.get_children()

var timeSinceLastBatSpawn = 0
var nextSpawner = 0

func _process(delta):
	timeSinceLastBatSpawn += delta

	if is_instance_valid(player) && timeSinceLastBatSpawn > spawnDelay:
		timeSinceLastBatSpawn -= spawnDelay

		var newBat = bat.instance()
		ysort.add_child(newBat)
		newBat.global_position = spawners[nextSpawner].global_position
		newBat.player = player

		nextSpawner += 1
		if nextSpawner >= spawners.size():
			nextSpawner = 0
