# main_menu.gd
extends Control

func _ready():
	# Listen for network problems
	GameManager.connection_failed.connect(_on_connection_failed)
	GameManager.server_disconnected.connect(_on_server_disconnected)

func _on_host_button_pressed():
	# Try to start a server
	var err = GameManager.host_game()
	if err != OK:
		_show_error("Failed to host game: " + str(err))
		return
	
	# Server started, load the game world
	get_tree().change_scene_to_file("res://scenes/world.tscn")

func _on_join_button_pressed():
	# Get the server address from the input field
	var address = $VBoxContainer/JoinContainer/AddressInput.text
	if address.is_empty():
		address = "localhost"  # Default to local game
	
	# Try to join the server
	var err = GameManager.join_game(address)
	if err != OK:
		_show_error("Failed to join game: " + str(err))
		return
	
	# Connected successfully, load the game world
	get_tree().change_scene_to_file("res://world.tscn")

func _on_connection_failed():
	_show_error("Failed to connect to server!")
	get_tree().change_scene_to_file("res://main_menu.tscn")

func _on_server_disconnected():
	_show_error("Disconnected from server!")
	get_tree().change_scene_to_file("res://main_menu.tscn")

func _show_error(message: String):
	# Pop up a dialog with the error message
	var dialog = AcceptDialog.new()
	dialog.dialog_text = message
	add_child(dialog)
	dialog.popup_centered()
