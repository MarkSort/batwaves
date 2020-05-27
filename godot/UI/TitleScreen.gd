extends MarginContainer

func _ready():

	var buildType = OS.get_name()

	if buildType == "HTML5":
		$VBoxContainer/MarginContainer/VBoxContainer/HostGame.visible = false
		$VBoxContainer/MarginContainer/VBoxContainer/Quit.visible = false

func _on_HostGame_gui_input(event):
	if (!is_clicked(event)): return

	get_tree().get_current_scene().hostAndJoinGame()

func _on_JoinGame_gui_input(event):
	if (!is_clicked(event)): return

	get_tree().get_current_scene().joinGame()

func _on_Quit_gui_input(event):
	if (!is_clicked(event)): return

	get_tree().quit()


func is_clicked(event):
	if (!(event is InputEventMouseButton)):
		return false

	if (!event.pressed || event.button_index != 1):
		return false

	# TODO returns true on initial mouse down, but should only return true on
	# mouse up, and only if cursor is still over the button

	get_tree().set_input_as_handled()
	return true
