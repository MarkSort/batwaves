extends MarginContainer

var skin = 1

func _ready():

	setSkin()

	var buildType = OS.get_name()

	if buildType == "HTML5":
		$MainMenu/MarginContainer/VBoxContainer/HostGame.visible = false
		$MainMenu/MarginContainer/VBoxContainer/MarginContainer2/Quit.visible = false
		$MainMenu/AnimatedSprite.position.y -= 15

func _on_SinglePlayer_gui_input(event):
	if (!is_clicked(event)): return

	get_tree().get_current_scene().singlePlayerGame(skin)

func _on_HostGame_gui_input(event):
	if (!is_clicked(event)): return

	get_tree().get_current_scene().hostAndJoinGame(skin)

func _on_JoinGame_gui_input(event):
	if (!is_clicked(event)): return

	$JoinGameMenu.visible = true
	$MainMenu.visible = false

func _on_Quit_gui_input(event):
	if (!is_clicked(event)): return

	get_tree().quit()

func _on_ChangePlayer_gui_input(event):
	if (!is_clicked(event)): return

	skin += 1
	if skin > 9:
		skin = 1

	setSkin()

func setSkin():
	var anim = "Player"
	if skin > 1:
		anim = "Player%d" % [skin]
	$MainMenu/AnimatedSprite.play(anim)

func _on_JoinGame2_gui_input(event):
	if (!is_clicked(event)): return

	get_tree().get_current_scene().joinGame(skin, $JoinGameMenu/ServerAddress.text)

func _on_Back_gui_input(event):
	if (!is_clicked(event)): return

	$JoinGameMenu.visible = false
	$MainMenu.visible = true

func is_clicked(event):
	if (!(event is InputEventMouseButton)):
		return false

	if (!event.pressed || event.button_index != 1):
		return false

	# TODO returns true on initial mouse down, but should only return true on
	# mouse up, and only if cursor is still over the button

	get_tree().set_input_as_handled()
	return true
