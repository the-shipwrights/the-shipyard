@tool
extends Node

var camera_height: float
var material: Material
var clouds: Array[Cloud]

class Particle:
	var position: Vector3
	var radius: float

class Cloud:
	var node: Node3D
	var particles: Array[Particle]

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	camera_height = 4.8
	material = load("res://assets/materials/cloud_material.tres")
	# create_cloud(Vector3(0.0, 0.0, 0.0), Vector2(16.0, 16.0), 4.0)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	var particle_positions: Array[Vector3]
	var particle_radiuses: Array[float]
	
	for cloud in clouds:
		for particle in cloud.particles:
			particle_positions.append(particle.position + cloud.node.position + self.position)
			particle_radiuses.append(particle.radius)
	
	material.set_shader_parameter("screen_height", camera_height)
	material.set_shader_parameter("particle_positions", particle_positions)
	material.set_shader_parameter("particle_radiuses", particle_radiuses)
	material.set_shader_parameter("particle_count", particle_positions.size())

func move_clouds(transle: Vector3):
	for cloud in clouds:
		cloud.node.transform = cloud.node.transform.translated(transle)

func create_cloud(position: Vector3, size: Vector2, thickness: float):
	var half: Vector2 = size / 2.0
	var cloud: Cloud = Cloud.new()
	var node: Node3D = Node3D.new()
	add_child(node)
	node.owner = self
	node.name = "Cloud1"
	cloud.node = node
	cloud.node.position = position
	
	var particle_count: int = round(size.x * size.y / pow(thickness, 2))
	for i in range(particle_count):
		cloud.particles.append(create_particle(size, thickness, 1.0))
		cloud.particles.append(create_particle(size, thickness, 0.6))
		cloud.particles.append(create_particle(size, thickness, 0.6))
		cloud.particles.append(create_particle(size, thickness, 0.6))
	
	clouds.append(cloud)
	
func create_particle(size: Vector2, thickness: float, threshold: float) -> Particle:
	var half: Vector2 = size / 2.0
	var particle: Particle = Particle.new()
	var position: Vector3 = Vector3(randf() * size.x - half.x, 0.0, randf() * size.y - half.y)
	while pos_to_radius(position, half) > threshold:
		position = Vector3(randf() * size.x - half.x, 0.0, randf() * size.y - half.y)
	var height: float = sqrt(1 - (pow(pos_to_radius(position, half), 2)))
	position.y = height
	
	particle.position = position
	particle.radius = (1.0 + ((randf() - 0.5) / 2.0)) * thickness / 2.0
	return particle

func pos_to_radius(pos: Vector3, size: Vector2) -> float:
	return sqrt(pow(pos.x / size.x, 2) + pow(pos.z / size.y, 2))
