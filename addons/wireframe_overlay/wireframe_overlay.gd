@tool
extends EditorPlugin

var _button: Button
var _panel: PanelContainer
var _opacity_slider: HSlider
var _enabled: bool = false
var _overlay_material: ShaderMaterial
var _wire_meshes: Array[MeshInstance3D] = []


func _enter_tree():
	var shader = load("res://addons/wireframe_overlay/wireframe.gdshader")
	_overlay_material = ShaderMaterial.new()
	_overlay_material.shader = shader
	_overlay_material.set_shader_parameter("wire_color", Color(0.0, 0.0, 0.0, 0.3))
	_overlay_material.set_shader_parameter("wire_width", 0.5)

	# Wire toggle button
	_button = Button.new()
	_button.text = "Wire"
	_button.toggle_mode = true
	_button.tooltip_text = "Toggle shaded wireframe overlay"
	_button.pressed.connect(_on_toggle)
	add_control_to_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, _button)

	# Settings panel (hidden by default)
	_panel = PanelContainer.new()
	_panel.visible = false

	_opacity_slider = HSlider.new()
	_opacity_slider.min_value = 0.05
	_opacity_slider.max_value = 1.0
	_opacity_slider.step = 0.05
	_opacity_slider.value = 0.3
	_opacity_slider.custom_minimum_size = Vector2(100, 0)
	_opacity_slider.value_changed.connect(_on_opacity_changed)
	_panel.add_child(_opacity_slider)

	add_control_to_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, _panel)


func _exit_tree():
	_clear_overlays()
	if _button:
		remove_control_from_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, _button)
		_button.queue_free()
		_button = null
	if _panel:
		remove_control_from_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, _panel)
		_panel.queue_free()
		_panel = null


func _on_toggle():
	_enabled = _button.button_pressed
	_panel.visible = _enabled
	if _enabled:
		_apply_overlays()
	else:
		_clear_overlays()


func _on_opacity_changed(value: float):
	_overlay_material.set_shader_parameter("wire_color", Color(0.0, 0.0, 0.0, value))


func _apply_overlays():
	_clear_overlays()
	var scene_root = get_tree().edited_scene_root
	if not scene_root:
		return
	_find_and_apply(scene_root)


func _find_and_apply(node: Node):
	if node is MeshInstance3D and node.mesh and node.visible:
		var wire_mesh = _create_wireframe_mesh(node)
		if wire_mesh:
			_wire_meshes.append(wire_mesh)
	for child in node.get_children():
		if child.has_meta("_wireframe_overlay"):
			continue
		_find_and_apply(child)


func _clear_overlays():
	for mesh in _wire_meshes:
		if is_instance_valid(mesh):
			mesh.queue_free()
	_wire_meshes.clear()


func _create_wireframe_mesh(source: MeshInstance3D) -> MeshInstance3D:
	var src_mesh = source.mesh
	if not src_mesh or src_mesh.get_surface_count() == 0:
		return null

	var arr_mesh = ArrayMesh.new()

	for surf_idx in range(src_mesh.get_surface_count()):
		var arrays = src_mesh.surface_get_arrays(surf_idx)
		if arrays.size() == 0:
			continue

		var src_verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var src_indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]

		if src_verts.size() == 0:
			continue

		var new_verts = PackedVector3Array()
		var new_colors = PackedColorArray()
		var bary_coords = [
			Color(1.0, 0.0, 0.0),
			Color(0.0, 1.0, 0.0),
			Color(0.0, 0.0, 1.0),
		]

		if src_indices.size() > 0:
			var tri_count = src_indices.size() / 3
			new_verts.resize(tri_count * 3)
			new_colors.resize(tri_count * 3)
			for i in range(tri_count):
				var base = i * 3
				new_verts[base + 0] = src_verts[src_indices[base + 0]]
				new_verts[base + 1] = src_verts[src_indices[base + 1]]
				new_verts[base + 2] = src_verts[src_indices[base + 2]]
				new_colors[base + 0] = bary_coords[0]
				new_colors[base + 1] = bary_coords[1]
				new_colors[base + 2] = bary_coords[2]
		else:
			var tri_count = src_verts.size() / 3
			new_verts = src_verts
			new_colors.resize(src_verts.size())
			for i in range(tri_count):
				var base = i * 3
				new_colors[base + 0] = bary_coords[0]
				new_colors[base + 1] = bary_coords[1]
				new_colors[base + 2] = bary_coords[2]

		var new_arrays = []
		new_arrays.resize(Mesh.ARRAY_MAX)
		new_arrays[Mesh.ARRAY_VERTEX] = new_verts
		new_arrays[Mesh.ARRAY_COLOR] = new_colors

		arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, new_arrays)
		arr_mesh.surface_set_material(surf_idx, _overlay_material)

	var wire_inst = MeshInstance3D.new()
	wire_inst.mesh = arr_mesh
	wire_inst.set_meta("_wireframe_overlay", true)
	wire_inst.name = "_wire_" + source.name
	wire_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	source.add_child(wire_inst)
	wire_inst.position = Vector3.ZERO
	wire_inst.rotation = Vector3.ZERO
	wire_inst.scale = Vector3.ONE

	return wire_inst


func _process(_delta):
	if not _enabled:
		return
	if Engine.get_process_frames() % 120 == 0:
		_apply_overlays()
