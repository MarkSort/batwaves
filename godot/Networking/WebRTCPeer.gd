var id
var connection: WebRTCPeerConnection
var dataChannel: WebRTCDataChannel

var addedToWorld = false
var lastInputId = 0

var sinceLastInput = 0

signal offer_created
signal ice_candidate_created

func _init(newId):
	id = newId
	connection = WebRTCPeerConnection.new()
	connection.connect("session_description_created", self, "_session_description_created")
	connection.connect("ice_candidate_created", self, "_ice_candidate_created")
	dataChannel = connection.create_data_channel("dc", {
		"id": 1,
		"negotiated": true,
		"maxRetransmits": 0,
		"ordered": false
	})


func poll():
	connection.poll()

func createOffer():
	var err = connection.create_offer()
	if err != OK:
		print("create_offer error: %s" % [err])

func _session_description_created(type, sdp):
	connection.set_local_description(type, sdp)
	emit_signal("offer_created", id, sdp)

func setAnswer(answer):
	connection.set_remote_description("answer", answer)

func _ice_candidate_created(media, index, name):
	if name.split(" ")[2] != "udp":
		return

	emit_signal("ice_candidate_created", id, media, index, name)
