extends Node

const WebRTCPeer = preload("WebRTCPeer.gd")

onready var worldPlayers = get_parent().players

var server: WebSocketServer = WebSocketServer.new()
var webRtcPeers: Dictionary = {}
var deltaSinceLastUpdate = 0
var updateCount = 0

func _init():
	server.connect("data_received", self, "_data_received")
	server.connect("client_connected", self, "_client_connected")
	server.connect("client_disconnected", self, "_client_disconnected")

func _ready():
	server.listen(1337)

func _process(delta):
	var disconnectedPeers = []
	var updates = []

	if server.is_listening():
		server.poll()

	deltaSinceLastUpdate += delta
	if deltaSinceLastUpdate >= .05:
		deltaSinceLastUpdate = 0
		updateCount += 1

		var playerCount = worldPlayers.get_child_count()
		var updateBuffer = StreamPeerBuffer.new()
		updateBuffer.resize(playerCount * 13 + 4 + 1)
		updateBuffer.put_u8(0) # update type Player
		updateBuffer.put_u32(updateCount)

		for player in worldPlayers.get_children():
			var facing = 0

			if player.roll_vector.x < 0:
				facing += 1
			elif player.roll_vector.x > 0:
				facing += 2
			if player.roll_vector.y < 0:
				facing += 3
			elif player.roll_vector.y > 0:
				facing += 6

			var x = round((player.position.x + 58) * (65536 / 468))
			var y = round((player.position.y + 60) * (65536 / 280))

			updateBuffer.put_u32(player.id)
			updateBuffer.put_u8(player.state)
			updateBuffer.put_u16(x)
			updateBuffer.put_u16(y)
			updateBuffer.put_8(player.velocity.x)
			updateBuffer.put_8(player.velocity.y)
			updateBuffer.put_u8(player.health)
			updateBuffer.put_u8(facing)
			updateBuffer.put_u8(get_parent().playerSkins[player.id])

		updates.append(updateBuffer.get_data_array())

		var bats = get_parent().bats.get_children()
		updateBuffer = StreamPeerBuffer.new()
		updateBuffer.resize(bats.size() * 8 + 4 + 1 + 1)
		updateBuffer.put_u8(1) # update type Bat
		updateBuffer.put_u32(updateCount)
		updateBuffer.put_u8(get_parent().wave)

		for bat in bats:
			var x = round((bat.position.x + 58) * (65536 / 468))
			var y = round((bat.position.y + 60) * (65536 / 280))

			updateBuffer.put_u8(bat.id)
			updateBuffer.put_u16(x)
			updateBuffer.put_u16(y)
			updateBuffer.put_8(bat.velocity.x)
			updateBuffer.put_8(bat.velocity.y)
			updateBuffer.put_u8(bat.stats.health)

		updates.append(updateBuffer.get_data_array())

	var restartGame = false

	for i in webRtcPeers:
		webRtcPeers[i].poll()
		var dataChannel: WebRTCDataChannel = webRtcPeers[i].dataChannel
		if !dataChannel:
			continue # not connected yet

		if dataChannel.get_ready_state() == WebRTCDataChannel.STATE_CLOSED:
			disconnectedPeers.push_back(i)
			continue

		if !webRtcPeers[i].addedToWorld:
			print("new player %d" % [i])
			get_parent().playersMap[i] = null
			webRtcPeers[i].addedToWorld = true

		for update in updates:
			if dataChannel.get_ready_state() == WebRTCDataChannel.STATE_OPEN:
				dataChannel.put_packet(update)

		if !updates.size() && dataChannel.get_available_packet_count():
			webRtcPeers[i].sinceLastInput = 0
			var inputUpdate: PoolByteArray = dataChannel.get_packet()

			var inputBuffer = StreamPeerBuffer.new()
			inputBuffer.set_data_array(inputUpdate)

			var inputId = inputBuffer.get_u32()
			if inputId < webRtcPeers[i].lastInputId:
				continue
			webRtcPeers[i].lastInputId = inputId

			var direction = inputBuffer.get_u8()
			var clientInputVelocity = Vector2.ZERO

			if direction >= 6:
				direction -= 6
				clientInputVelocity.y = 1
			elif direction >= 3:
				direction -= 3
				clientInputVelocity.y = -1

			if direction == 2:
				clientInputVelocity.x = 1
			elif direction == 1:
				clientInputVelocity.x = -1

			var actions = inputBuffer.get_u8()

			var clientAttack = (actions & 1) > 0
			if clientAttack:
				restartGame = true

			var player = get_parent().playersMap[i]
			if !is_instance_valid(player):
				continue

			player.clientInputVelocity = clientInputVelocity
			player.clientAttack = clientAttack
			player.clientRoll = (actions & 2) > 0
		elif !updates.size():
			webRtcPeers[i].sinceLastInput += delta
			if webRtcPeers[i].sinceLastInput > 2:
				disconnectedPeers.append(i)


	for i in disconnectedPeers:
		get_parent().disconnectPlayer(i)
		webRtcPeers.erase(i)

	if restartGame:
		get_parent().restartGame()

# WebSocket
func _client_connected(id, protocol):
	clientLogInfo(id, "connected with protocol '%s'" % [protocol])

	# TODO make a separate ID for webRtcPeers index + playerId ?
	server.get_peer(id).put_packet(("%d" % [id]).to_ascii())

	webRtcPeers[id] = WebRTCPeer.new(id)
	webRtcPeers[id].connect("offer_created", self, "_offer_created")
	webRtcPeers[id].connect("ice_candidate_created", self, "_ice_candidate_created")
	webRtcPeers[id].createOffer()

func _data_received(id):
	clientLogInfo(id, "server received answer")
	var skinAndAnswer = server.get_peer(id).get_packet().get_string_from_utf8()

	var skin = int(skinAndAnswer[0])
	get_parent().playerSkins[id] = skin

	skinAndAnswer.erase(0, 1)
	webRtcPeers[id].setAnswer(skinAndAnswer)

func _client_disconnected(id, was_clean_close):
	if was_clean_close:
		clientLogInfo(id, "disconnected cleanly")
		server.get_peer(id).close()
	else:
		print("[WebSocketServer] [clientId=%d] %s" % [id, "disconnected unexpectedly"])


#WebRTC
func _offer_created(id, sdp):
	server.get_peer(id).put_packet(sdp.to_utf8())

func _ice_candidate_created(id, media, index, name):
	var candidate = "%s\n%d\n%s" % [media, index, name]
	server.get_peer(id).put_packet(candidate.to_utf8())


#util
func clientLogInfo(id, message):
	print("[WebSocketServer] [clientId=%d] %s" % [id, message])
