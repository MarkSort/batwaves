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

var players: Dictionary = {}
var bats: Dictionary = {}

enum {
	WAITING_FOR_ID,
	WAITING_FOR_OFFER,
	WAITING_FOR_CANDIDATES
}

var state = WAITING_FOR_ID

func _init():
	client.connect("data_received", self, "_data_received")
	client.connect("connection_closed", self, "_connection_closed")
	client.connect("connection_error", self, "_connection_error")

	webRtc.connect("session_description_created", self, "_session_description_created")

func _ready():
	client.connect_to_url("ws://192.168.7.144:1337")

func _process(delta):
	client.poll()
	webRtc.poll()

	if dataChannel && dataChannel.get_available_packet_count():
		var update: PoolByteArray = dataChannel.get_packet()
		var updateBuffer = StreamPeerBuffer.new()
		updateBuffer.set_data_array(update)

		if updateBuffer.get_u8() == 0:
			var playerUpdateId = updateBuffer.get_u32()
			if playerUpdateId < lastPlayerUpdateId:
				return

			lastPlayerUpdateId = playerUpdateId

			var playerCount = (updateBuffer.get_size() - 4 - 1) / 21
			var i = 0
			while i < playerCount:
				i += 1
				var id = updateBuffer.get_u32()

				if !players.has(id):
					players[id] = get_parent().addClientPlayer(id)

				players[id].state = updateBuffer.get_u8()
				players[id].position.x = updateBuffer.get_float()
				players[id].position.y = updateBuffer.get_float()
				players[id].velocity.x = updateBuffer.get_float()
				players[id].velocity.y = updateBuffer.get_float()
		else:
			var batUpdateId = updateBuffer.get_u32()
			if batUpdateId < lastBatUpdateId:
				return

			lastBatUpdateId = batUpdateId

			var batCount = (updateBuffer.get_size() - 4 - 1) / 9
			var i = 0
			var batUpdates = {}
			while i < batCount:
				i += 1
				var id = updateBuffer.get_u8()
				batUpdates[id] = Vector2(
					updateBuffer.get_float(),
					updateBuffer.get_float()
				)

			var newBats = batUpdates.duplicate()
			for bat in get_parent().bats.get_children():
				if batUpdates.has(bat.id):
					newBats.erase(bat.id)
					bat.position.x = batUpdates[bat.id].x
					bat.position.y = batUpdates[bat.id].y
				else:
					get_parent().removeClientBat(bat)

			for id in newBats:
				get_parent().addClientBat(id, newBats[id])

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


#WebSocket
func _data_received():
	match state:
		WAITING_FOR_ID:
			get_parent().playerId = int(client.get_peer(1).get_packet().get_string_from_ascii())
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
	client.get_peer(1).put_packet(sdp.to_utf8())

func _data_channel_received(dataChannel):
	self.dataChannel = dataChannel
	client.disconnect_from_host(1000, "webrtc connected")
