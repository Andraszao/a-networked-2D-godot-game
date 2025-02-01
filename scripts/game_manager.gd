extends Node

# Network settings
const PORT = 9999
var peer = ENetMultiplayerPeer.new()
var players = {}

# Where players spawn in the world
const SPAWN_POINTS = [
	Vector2(0, 0),
	Vector2(100, 0),
	Vector2(-100, 0),
	Vector2(200, 0)
]

# Used to generate fun random player names
const ADJECTIVES = ["Elegant", "Quirky", "Happy", "Bouncy", "Silly", "Clever", "Fluffy", "Sparkly"]
const NOUNS = ["Banana", "Potato", "Penguin", "Unicorn", "Raccoon", "Koala", "Pickle", "Mango"]

# How often we check network status
const PING_INTERVAL = 1.0  # Seconds between pings
const PING_TIMEOUT = 5.0   # When to consider a ping lost
const MAX_PING_HISTORY = 10  # Number of pings to track for cleanup

# Server tick rate (updates per second)
const MIN_TICK_RATE = 10
const MAX_TICK_RATE = 60
const DEFAULT_TICK_RATE = 30

# Signals that other nodes can connect to
signal connection_failed
signal server_disconnected
signal network_stats_updated(latency: float, quality: String)

# References and tracking
var players_node: Node2D
var pending_spawns = []
var _current_tick_rate = DEFAULT_TICK_RATE
var _tick_interval = 1.0 / DEFAULT_TICK_RATE
var _last_tick_time = 0.0

# Network monitoring
var _ping_requests = {}  # Stores timestamps of sent pings
var _current_latency = 0.0
var _ping_timer = 0.0

func _ready():
	# Hook up all our network event handlers
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func host_game() -> Error:
	# Show available IPs for LAN play
	print("\nAvailable IP addresses:")
	for ip in IP.get_local_addresses():
		if ip.begins_with("10."):
			print("Local Network IP: ", ip)
	
	# Start the server
	var err = peer.create_server(PORT)
	if err != OK:
		return err
	
	print("Server started on port: ", PORT)
	multiplayer.multiplayer_peer = peer
	
	# Server host is also a player
	call_deferred("add_player", multiplayer.get_unique_id())
	return OK

func join_game(address: String) -> Error:
	# Try to connect to the server
	var err = peer.create_client(address, PORT)
	if err != OK:
		return err
	
	multiplayer.multiplayer_peer = peer
	return OK

func _on_connected_to_server():
	print("Successfully connected to server!")
	var peer_id = multiplayer.get_unique_id()
	rpc_id(1, "request_spawn", peer_id)

func _on_connection_failed():
	print("Failed to connect to server!")
	multiplayer.multiplayer_peer = null
	connection_failed.emit()

func _on_server_disconnected():
	print("Server disconnected!")
	multiplayer.multiplayer_peer = null
	server_disconnected.emit()

func _on_peer_connected(id: int):
	print("Peer connected: ", id)
	
	# Let the new player know about everyone already here
	if multiplayer.is_server():
		for player_id in players:
			add_player.rpc_id(id, player_id)

@rpc("any_peer", "reliable")
func request_spawn(peer_id: int):
	if !multiplayer.is_server():
		return
	
	add_player.rpc(peer_id)

func _on_peer_disconnected(id: int):
	print("Peer disconnected: ", id)
	remove_player(id)

func _on_world_ready():
	print("World is ready")
	var world = get_tree().current_scene
	players_node = world.get_node_or_null("Players")
	
	if !players_node:
		print("Error: Players node not found!")
		return
	
	# Now that the world is ready, spawn any waiting players
	if multiplayer.is_server():
		for id in pending_spawns:
			add_player(id)
		pending_spawns.clear()

@rpc("authority", "call_local", "reliable")
func add_player(id: int):
	if not players_node:
		print("World not ready, queuing spawn")
		if not pending_spawns.has(id):
			pending_spawns.append(id)
		return
	
	if players.has(id):
		print("Player ", id, " already exists!")
		return
	
	# Create the player
	var player_scene = preload("res://scenes/player.tscn")
	var player = player_scene.instantiate()
	player.name = str(id)
	
	# Give them a fun random name
	var nickname = "%s%s" % [
		ADJECTIVES[randi() % ADJECTIVES.size()],
		NOUNS[randi() % NOUNS.size()]
	]
	player.nickname = nickname
	
	# Put them at a spawn point
	var spawn_point = SPAWN_POINTS[players.size() % SPAWN_POINTS.size()]
	player.position = spawn_point
	
	# Add them to the game
	players[id] = player
	players_node.add_child(player, true)
	print("Added player: ", id, " with nickname: ", nickname)

func remove_player(id: int):
	if players.has(id):
		players[id].queue_free()
		players.erase(id)
		print("Removed player: ", id)

func _physics_process(delta: float) -> void:
	# Only the server manages game state
	if !multiplayer.is_server():
		return
	
	# Time for the next server tick?
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - _last_tick_time >= _tick_interval:
		_server_tick()
		_last_tick_time = current_time

func _server_tick() -> void:
	var tick_timestamp = Time.get_ticks_msec()
	
	# Update everyone about each player's state
	for player_id in players:
		var player = players[player_id]
		if !is_instance_valid(player):
			continue
		
		var state = {
			"position": player.position,
			"velocity": player.velocity,
			"timestamp": tick_timestamp
		}
		broadcast_state.rpc(player_id, state)

@rpc("authority", "unreliable")
func broadcast_state(player_id: int, state: Dictionary) -> void:
	if !players.has(player_id):
		return
	
	var player = players[player_id]
	if !is_instance_valid(player) || player.sync.is_multiplayer_authority():
		return
	
	state["timestamp"] = Time.get_ticks_msec()
	player.update_network_state(state)

func _process(delta: float) -> void:
	if !multiplayer.multiplayer_peer:
		return
	
	# Clean up old ping requests
	var current_time = Time.get_ticks_msec()
	var to_erase = []
	for ping_id in _ping_requests:
		if current_time - _ping_requests[ping_id] > PING_TIMEOUT * 1000:
			to_erase.append(ping_id)
	for ping_id in to_erase:
		_ping_requests.erase(ping_id)
	
	# Time to check network status?
	_ping_timer += delta
	if _ping_timer >= PING_INTERVAL:
		_ping_timer = 0.0
		
		# Keep ping history manageable
		if _ping_requests.size() > MAX_PING_HISTORY:
			var oldest = _ping_requests.keys()[0]
			_ping_requests.erase(oldest)
		
		# Send new ping
		var ping_id = randi()
		_ping_requests[ping_id] = current_time
		if multiplayer.is_server():
			request_ping.rpc(ping_id)  # Server pings everyone
		else:
			request_ping.rpc_id(1, ping_id)  # Clients ping only server

@rpc("any_peer", "unreliable")
func request_ping(ping_id: int) -> void:
	# Echo the ping back to sender
	var sender = multiplayer.get_remote_sender_id()
	respond_ping.rpc_id(sender, ping_id)

@rpc("any_peer", "unreliable")
func respond_ping(ping_id: int) -> void:
	# Calculate the actual round-trip time
	if !_ping_requests.has(ping_id):
		return
	
	var round_trip_time = Time.get_ticks_msec() - _ping_requests[ping_id]
	_ping_requests.erase(ping_id)
	_current_latency = max(0.0, round_trip_time / 1000.0)
	
	# Update the connection quality
	var quality = "Good"
	if _current_latency > 0.2:
		quality = "Poor"
	elif _current_latency > 0.1:
		quality = "Fair"
	
	network_stats_updated.emit(_current_latency, quality)

func set_tick_rate(new_rate: int) -> void:
	_current_tick_rate = clamp(new_rate, MIN_TICK_RATE, MAX_TICK_RATE)
	_tick_interval = 1.0 / _current_tick_rate
	print("Server tick rate set to: ", _current_tick_rate)
