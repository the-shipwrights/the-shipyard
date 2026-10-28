@tool
extends Node

var camera_height: float = 5.0
var particle_count: int
var particle_positions: Array[Vector3]
var particle_radiuses: Array[float]
var material: Material

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	particle_positions.resize(3)
	particle_radiuses.resize(3)
	material = load("res://assets/materials/cloud_material.tres")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	camera_height = 4.8
	particle_count = 3
	
	particle_positions[0] = $CloudParticle1.position
	particle_positions[1] = $CloudParticle2.position
	particle_positions[2] = $CloudParticle3.position

	particle_radiuses[0] = $CloudParticle1.scale.x / 2
	particle_radiuses[1] = $CloudParticle2.scale.x / 2
	particle_radiuses[2] = $CloudParticle3.scale.x / 2
	
	material.set_shader_parameter("screen_height", camera_height)
	material.set_shader_parameter("particle_positions", particle_positions)
	material.set_shader_parameter("particle_radiuses", particle_radiuses)
	material.set_shader_parameter("particle_count", particle_count)
