# Create a new script: network_status.gd
extends Control

@onready var status_label = $Label

func _ready() -> void:
	GameManager.network_stats_updated.connect(_on_network_stats_updated)
	
func _on_network_stats_updated(latency: float, quality: String) -> void:
	var latency_ms = latency * 1000
	status_label.text = "Ping: %3.0fms (%s)" % [latency_ms, quality]
	
	# Color code based on quality
	match quality:
		"Good":
			status_label.modulate = Color.GREEN
		"Fair":
			status_label.modulate = Color.YELLOW
		"Poor":
			status_label.modulate = Color.RED
