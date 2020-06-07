extends Node

var currentNode
var previousNode

const World = preload("World.tscn")
const TitleScreen = preload("UI/TitleScreen.tscn")
const Server = preload("res://Networking/Server.gd")
const Client = preload("res://Networking/Client.gd")

func _ready():
	randomize()

	var buildType = OS.get_name()

	if (buildType == "Server"):
		hostGame()
	else:
		currentNode = TitleScreen.instance()
		add_child(currentNode)

func singlePlayerGame(skin):
	addWorldNode()
	# add local player
	currentNode.playersMap[1] = null
	currentNode.playerId = 1
	currentNode.playerSkins[1] = skin

func hostAndJoinGame(skin):
	addWorldNode()
	currentNode.add_child(Server.new())
	# add local player
	currentNode.playersMap[1] = null
	currentNode.playerId = 1
	currentNode.playerSkins[1] = skin

func joinGame(skin):
	addWorldNode()
	currentNode.server = false
	currentNode.add_child(Client.new())

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
