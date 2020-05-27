extends Node

var currentNode
var previousNode

const World = preload("World.tscn")
const TitleScreen = preload("UI/TitleScreen.tscn")
const Server = preload("res://Networking/Server.gd")

func _ready():
	var buildType = OS.get_name()

	if (buildType == "Server"):
		hostGame()
	else:
		currentNode = TitleScreen.instance()
		add_child(currentNode)

func hostAndJoinGame():
	addWorldNode()
	currentNode.add_child(Server.new())

func joinGame():
	pass

func hostGame():
	addWorldNode()
	currentNode.add_child(Server.new())

func addWorldNode():
	if currentNode:
		previousNode = currentNode
		remove_child(previousNode)
		call_deferred("freePreviousNode")

	currentNode = World.instance()
	add_child(currentNode)

func freePreviousNode():
	previousNode.free()
