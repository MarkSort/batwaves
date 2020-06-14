extends Node

var Player = preload("res://Player/Player.tscn")

var client: WebSocketClient = WebSocketClient.new()
var webRtc: WebRTCPeerConnection = WebRTCPeerConnection.new()
var dataChannel: WebRTCDataChannel = webRtc.create_data_channel("dc", {
	"id": 1,
	"negotiated": true,
	"maxRetransmits": 0,
	"ordered": false
})
var lastPlayerUpdateId = 0
var lastBatUpdateId = 0

var deltaSinceLastInput = 0
var inputCount = 0

var bats: Dictionary = {}

var address: String

enum {
	WAITING_FOR_ID,
	WAITING_FOR_OFFER,
	WAITING_FOR_CANDIDATES
}

var state = WAITING_FOR_ID

onready var world = get_parent()

var skin = 1

func _init():
	client.connect("data_received", self, "_data_received")
	client.connect("connection_closed", self, "_connection_closed")
	client.connect("connection_error", self, "_connection_error")

	webRtc.connect("session_description_created", self, "_session_description_created")

func _ready():
	var fullAddress = "ws://" + address
	if address.find(":") == -1:
		fullAddress += ":1337"
	print("connecting to ", fullAddress)
	client.connect_to_url(fullAddress)

func _process(delta):
	client.poll()
	webRtc.poll()

	if !dataChannel: return

	var newestPlayerUpdate = { "id": 0 }
	var newestBatUpdate = { "id": 0 }

	while dataChannel.get_available_packet_count():
		var update: PoolByteArray = dataChannel.get_packet()
		var updateBuffer = StreamPeerBuffer.new()
		updateBuffer.set_data_array(update)

		if updateBuffer.get_u8() == 0:
			var playerUpdateId = updateBuffer.get_u32()
			if playerUpdateId < lastPlayerUpdateId:
				continue
			if !newestPlayerUpdate.id || playerUpdateId > newestPlayerUpdate.id:
				newestPlayerUpdate.id = playerUpdateId
				newestPlayerUpdate.buffer = updateBuffer

		else:
			var batUpdateId = updateBuffer.get_u32()
			if batUpdateId < lastBatUpdateId:
				continue
			if !newestBatUpdate.id || batUpdateId > newestBatUpdate.id:
				newestBatUpdate.id = batUpdateId
				newestBatUpdate.buffer = updateBuffer

	if newestPlayerUpdate.id:
		doPlayerUpdate(newestPlayerUpdate.id, newestPlayerUpdate.buffer)
	if newestBatUpdate.id:
		doBatUpdate(newestBatUpdate.id, newestBatUpdate.buffer)

	deltaSinceLastInput += delta
	if deltaSinceLastInput > .05:
		deltaSinceLastInput = 0
		inputCount += 1

		var inputDirection = 0
		if Input.is_action_pressed("ui_left") && Input.is_action_pressed("ui_right"):
			pass
		elif Input.is_action_pressed("ui_left"):
			inputDirection += 1
		elif Input.is_action_pressed("ui_right"):
			inputDirection += 2
		if Input.is_action_pressed("ui_up") && Input.is_action_pressed("ui_down"):
			pass
		elif Input.is_action_pressed("ui_up"):
			inputDirection += 3
		elif Input.is_action_pressed("ui_down"):
			inputDirection += 6

		var actions = 0
		if Input.is_action_pressed("attack"):
			actions |= 1
		if Input.is_action_pressed("roll"):
			actions |= 2

		var inputBuffer = StreamPeerBuffer.new()
		inputBuffer.resize(5)
		inputBuffer.put_u32(inputCount)
		inputBuffer.put_u8(inputDirection)
		inputBuffer.put_u8(actions)

		dataChannel.put_packet(inputBuffer.get_data_array())

func doPlayerUpdate(playerUpdateId, updateBuffer):
	lastPlayerUpdateId = playerUpdateId

	var playerUpdates = {}
	var newPlayerIds = []
	var playerCount = (updateBuffer.get_size() - 4 - 1) / 23
	var i = 0
	while i < playerCount:
		i += 1
		var id = updateBuffer.get_u32()
		newPlayerIds.append(id)

		playerUpdates[id] = {
			"state": updateBuffer.get_u8(),
			"position": Vector2(
				updateBuffer.get_float(),
				updateBuffer.get_float()
			),
			"velocity": Vector2(
				updateBuffer.get_float(),
				updateBuffer.get_float()
			),
			"health": updateBuffer.get_u8(),
			"facing": updateBuffer.get_u8(),
			"skin": updateBuffer.get_u8()
		}

	var removePlayers = []
	for player in world.players.get_children():
		if playerUpdates.has(player.id):
			newPlayerIds.erase(player.id)
			player.state = playerUpdates[player.id].state
			player.position = playerUpdates[player.id].position
			player.velocity = playerUpdates[player.id].velocity
			if playerUpdates[player.id].health < player.health:
				player.hurt()
				if playerUpdates[player.id].health > 0:
					player.startInvincibility()
			player.health = playerUpdates[player.id].health
			if world.playerId == player.id:
				PlayerStats.health = player.health

			var facingVector = Vector2.ZERO
			var facing = playerUpdates[player.id].facing
			if facing >= 6:
				facing -= 6
				facingVector.y = 1
			elif facing >= 3:
				facing -= 3
				facingVector.y = -1

			if facing == 2:
				facingVector.x = 1
			elif facing == 1:
				facingVector.x = -1

			player.setBlendPositions(facingVector)
			player.roll_vector = facingVector

		else:
			removePlayers.append(player)

	for player in removePlayers:
		if world.playerId == player.id:
			PlayerStats.health = 0
		world.players.remove_child(player)
		world.playersMap[player.id] = null
		for bat in world.bats.get_children():
			if bat.player == player:
				bat.player = null
		player.free()

	for playerId in newPlayerIds:
		world.playerSkins[playerId] = playerUpdates[playerId].skin
		world.addClientPlayer(playerId)

func doBatUpdate(batUpdateId, updateBuffer):
	lastBatUpdateId = batUpdateId

	var wave = updateBuffer.get_u8()

	var batCount = (updateBuffer.get_size() - 4 - 1 - 1) / 13
	var i = 0
	var batUpdates = {}
	while i < batCount:
		i += 1
		var id = updateBuffer.get_u8()
		batUpdates[id] = {
			"position": Vector2(
				updateBuffer.get_float(),
				updateBuffer.get_float()
			),
			"player": updateBuffer.get_u32()
		}

	var playerCount = world.players.get_child_count()
	if batCount == 0 && playerCount > 0:
		world.status.text = "Wave %d" % [wave]
	elif playerCount == 0:
		world.status.text = "Game Over\non Wave %d" % [wave]
	else:
		world.status.text = ""

	var newBats = batUpdates.duplicate()
	for bat in world.bats.get_children():
		if batUpdates.has(bat.id):
			newBats.erase(bat.id)
			bat.position.x = batUpdates[bat.id].position.x
			bat.position.y = batUpdates[bat.id].position.y
			if world.playersMap.has(batUpdates[bat.id].player):
				bat.player = world.playersMap[batUpdates[bat.id].player]
			else:
				bat.player = null
		else:
			world.removeClientBat(bat)

	for id in newBats:
		world.addClientBat(id, newBats[id])


#WebSocket
func _data_received():
	match state:
		WAITING_FOR_ID:
			world.playerId = int(client.get_peer(1).get_packet().get_string_from_ascii())
			state = WAITING_FOR_OFFER
		WAITING_FOR_OFFER:
			print("client.get_unique_id(): %d" % [client.get_unique_id()])
			state = WAITING_FOR_CANDIDATES
			var offer = client.get_peer(1).get_packet().get_string_from_utf8()
			print("OFFER: ", offer)
			webRtc.set_remote_description("offer", offer)
		WAITING_FOR_CANDIDATES:
			var packet = client.get_peer(1).get_packet().get_string_from_utf8()
			var candidate = packet.split("\n")
			if candidate.size() != 3:
				print("Received bad candidate from server: %s" % [packet])
				return

			webRtc.add_ice_candidate(candidate[0], int(candidate[1]), candidate[2])

func _connection_closed(was_clean_close):
	if was_clean_close || webRtc.get_connection_state() == webRtc.STATE_CONNECTED:
		print("WebSocket disconnected cleanly")
	else:
		print("WebSocket disconnected unexpectedly")

func _connection_error():
	print("WebSocket Connection error")


#WebRTC
func _session_description_created(type, sdp):
	webRtc.set_local_description(type, sdp)
	var skinAndSdp = "%d%s" % [skin, sdp]
	client.get_peer(1).put_packet(skinAndSdp.to_utf8())

func _data_channel_received(dataChannel):
	self.dataChannel = dataChannel
	client.disconnect_from_host(1000, "webrtc connected")
