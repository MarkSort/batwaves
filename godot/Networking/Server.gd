extends Node

const WebRTCPeer = preload("WebRTCPeer.gd")

var world
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

		var playerCount = 1
		var updateBuffer = StreamPeerBuffer.new()
		updateBuffer.resize(playerCount * 21 + 4 + 1)
		updateBuffer.put_u8(0) # update type Player
		updateBuffer.put_u32(updateCount)

		updateBuffer.put_u32(1)

		var player = get_parent().player
		if is_instance_valid(player):
			updateBuffer.put_u8(player.state)
			updateBuffer.put_float(player.position.x)
			updateBuffer.put_float(player.position.y)
			updateBuffer.put_float(player.velocity.x)
			updateBuffer.put_float(player.velocity.y)
		else:
			updateBuffer.put_u8(0)
			updateBuffer.put_float(0)
			updateBuffer.put_float(0)
			updateBuffer.put_float(0)
			updateBuffer.put_float(0)

		updates.append(updateBuffer.get_data_array())

		var bats = get_parent().bats.get_children()
		updateBuffer = StreamPeerBuffer.new()
		updateBuffer.resize(bats.size() * 9 + 4 + 1)
		updateBuffer.put_u8(1) # update type Bat
		updateBuffer.put_u32(updateCount)

		for bat in bats:
			updateBuffer.put_u8(bat.id)
			updateBuffer.put_float(bat.position.x)
			updateBuffer.put_float(bat.position.y)

		updates.append(updateBuffer.get_data_array())

	for i in webRtcPeers:
		webRtcPeers[i].poll()
		var dataChannel: WebRTCDataChannel = webRtcPeers[i].dataChannel
		if !dataChannel:
			continue # not connected yet

		if dataChannel.get_ready_state() == WebRTCDataChannel.STATE_CLOSED:
			disconnectedPeers.push_back(i)
			continue

		for update in updates:
			if dataChannel.get_ready_state() == WebRTCDataChannel.STATE_OPEN:
				dataChannel.put_packet(update)

		if !updates.size() && dataChannel.get_available_packet_count():
			var packet = dataChannel.get_packet().get_string_from_utf8()
			clientLogInfo(i, "got DataChannel packet: '%s'" % [packet])


# WebSocket
func _client_connected(id, protocol):
	clientLogInfo(id, "connected with protocol '%s'" % [protocol])
	webRtcPeers[id] = WebRTCPeer.new(id)
	webRtcPeers[id].connect("offer_created", self, "_offer_created")
	webRtcPeers[id].connect("ice_candidate_created", self, "_ice_candidate_created")
	webRtcPeers[id].createOffer()

func _data_received(id):
	clientLogInfo(id, "server received answer")
	var answer = server.get_peer(id).get_packet().get_string_from_utf8()
	webRtcPeers[id].setAnswer(answer)

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
