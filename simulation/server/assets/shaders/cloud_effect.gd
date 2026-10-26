@tool
extends CompositorEffect
class_name CloudEffect

var rd = RenderingServer.get_rendering_device()
var shader: RID
var pipeline: RID

var shader_file: RDShaderFile

func _ready() -> void:
	shader_file = preload("res://assets/shaders/cloud.glsl")
	var shader_spirv := shader_file.get_spirv()
	shader = rd.shader_create_from_spirv(shader_spirv)
	pipeline = rd.compute_pipeline_create(shader)

func _render_callback(effect_callback_type: int, render_data: RenderData) -> void:
	
	print(shader_file.get_rid())
	'''
	var render_scene_buffers: RenderSceneBuffersRD = render_data.get_render_scene_buffers()
	var size := render_scene_buffers.get_internal_size()
	
	var color_layer_uniform := RDUniform.new()
	color_layer_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	color_layer_uniform.binding = 0
	color_layer_uniform.add_id(render_scene_buffers.get_color_layer(0))
	
	var bindings: Array[RDUniform] = [
		color_layer_uniform
	]
	
	var groups := Vector3i(size.x, size.y, 1)
	var uniform_set := rd.uniform_set_create(bindings, shader, 0)
	var compute_list := rd.compute_list_begin()
	
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	rd.compute_list_dispatch(compute_list, groups.x, groups.y, groups.z)
	rd.compute_list_end()
	
	rd.free_rid(uniform_set)
'''
