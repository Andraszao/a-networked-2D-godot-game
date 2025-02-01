# player.gd
extends CharacterBody2D

# Movement settings
const SPEED = 300.0
const JUMP_VELOCITY = -400.0
const GRAVITY = 980

# Network smoothing
const INTERPOLATION_OFFSET = 0.1  # 100ms buffer for smooth movement

# Player name that shows above their character
@export var nickname: String = "Player":
	set(value):
		nickname = value
		if $Nickname:
			$Nickname.text = value

# Network state tracking
var _target_position: Vector2      # Where we're moving to
var _target_velocity: Vector2      # How fast we're moving there
var _last_update_time: float = 0.0
var _last_state_timestamp: int = 0

@onready var sync = $MultiplayerSynchronizer

func _ready():
	# Set up the player's display name
	$Nickname.text = nickname
	
	# Configure network authority
	var peer_id = str(name).to_int()
	sync.set_multiplayer_authority(peer_id)
	
	# Initialize movement targets
	_target_position = position
	_target_velocity = velocity
	
	# Set up local vs remote player differences
	if sync.is_multiplayer_authority():
		# This is us - make our character green and enable camera
		$Sprite2D.modulate = Color(0.2, 1, 0.2)
		$Camera2D.enabled = true
		$Camera2D.make_current()
	else:
		# This is another player - make them red
		$Sprite2D.modulate = Color(1, 0.2, 0.2)

func _physics_process(delta: float) -> void:
	if sync.is_multiplayer_authority():
		handle_local_movement(delta)
	else:
		interpolate_movement(delta)

func handle_local_movement(delta: float) -> void:
	# Apply gravity when in the air
	if not is_on_floor():
		velocity.y += GRAVITY * delta

	# Handle jumping when on the ground
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Handle left/right movement
	var direction := Input.get_axis("ui_left", "ui_right")
	if direction:
		velocity.x = direction * SPEED
		$Sprite2D.flip_h = direction < 0  # Face the direction we're moving
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)  # Slow down when no input

	move_and_slide()

func interpolate_movement(delta: float) -> void:
	# Smooth out network movement for other players
	var current_time = Time.get_ticks_msec() / 1000.0
	var time_since_update = current_time - _last_update_time
	
	# Wait for first network update
	if _last_state_timestamp == 0:
		return
	
	# Calculate how far along we are between updates
	var interp_factor = clamp(time_since_update / INTERPOLATION_OFFSET, 0.0, 1.0)
	
	# Smoothly move to target position and velocity
	position = position.lerp(_target_position, interp_factor * 0.5)
	velocity = velocity.lerp(_target_velocity, interp_factor * 0.5)
	
	# Update character facing direction
	if abs(velocity.x) > 0.1:
		$Sprite2D.flip_h = velocity.x < 0

# Called by GameManager when new network state arrives
func update_network_state(state: Dictionary) -> void:
	# Only accept newer state updates
	if state.has("timestamp") && state["timestamp"] > _last_state_timestamp:
		_target_position = state["position"]
		_target_velocity = state["velocity"]
		_last_state_timestamp = state["timestamp"]
		_last_update_time = Time.get_ticks_msec() / 1000.0
