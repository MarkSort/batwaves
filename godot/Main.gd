extends Node

var currentNode
var previousNode

const World = preload("World.tscn")
const TitleScreen = preload("UI/TitleScreen.tscn")

func _ready():
	var buildType = OS.get_name()

	if (buildType == "Server"):
		hostGame()
	else:
		currentNode = TitleScreen.instance()
		add_child(currentNode)

func hostAndJoinGame():
	addWorldNode()

#	currentNode.startServer()
#	currentNode.startClient()

func joinGame():
	addWorldNode()

#	currentNode.startClient()

func hostGame():
	addWorldNode()

#	currentNode.startServer()

func addWorldNode():
	if currentNode:
		previousNode = currentNode
		remove_child(previousNode)
		call_deferred("freePreviousNode")

	currentNode = World.instance()
	add_child(currentNode)

func freePreviousNode():
	previousNode.free()
