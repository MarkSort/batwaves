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
var waitingForOffer = true
var lastUpdateCount = 0

var players: Dictionary = {}

func _init():
	client.connect("data_received", self, "_data_received")
	client.connect("connection_closed", self, "_connection_closed")
	client.connect("connection_error", self, "_connection_error")

	webRtc.connect("session_description_created", self, "_session_description_created")

func _ready():
	client.connect_to_url("ws://192.168.7.144:1337")

func _process(_delta):
	client.poll()
	webRtc.poll()

	if dataChannel && dataChannel.get_available_packet_count():
		var update: PoolByteArray = dataChannel.get_packet()
		var updateBuffer = StreamPeerBuffer.new()
		updateBuffer.set_data_array(update)

		var updateCount = updateBuffer.get_u32()
		if updateCount < lastUpdateCount:
			return

		lastUpdateCount = updateCount

		var playerCount = (updateBuffer.get_size() - 4) / 21
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


#WebSocket
func _data_received():
	if waitingForOffer:
		waitingForOffer = false
		var offer = client.get_peer(1).get_packet().get_string_from_utf8()
		webRtc.set_remote_description("offer", offer)
	else:
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
