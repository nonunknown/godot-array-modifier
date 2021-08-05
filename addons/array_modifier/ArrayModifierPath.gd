extends Spatial
tool

export (NodePath) var path setget set_path
export (float, 0, 1, 0.001) var path_offset_start setget set_path_offset_start
export (float) var repeat_offset setget set_repeat_offset
export (Vector3) var instance_offset = Vector3.ZERO

export (int) var repeat_count = 1 setget set_repeat_count
export (bool) var force_refresh = false setget set_force_refresh

var _hooks = Dictionary()
# Path node
var _path_node = null
var _path_length = 0


func _ready():
	if _path_node != null:
		_adjust_copies()


func _get_copy_position_rotation(instance_number):
	var position = path_offset_start + instance_number * repeat_offset 
	var absolute_offset = fmod(_path_length * position, _path_length)
	var offset_1 = max(absolute_offset - 0.01, 0)
	var offset_2 = min(absolute_offset + 0.01, _path_length)
	var p1 = _path_node.curve.interpolate_baked(offset_1, true)
	var p2 = _path_node.curve.interpolate_baked(offset_2, true)
	var newpos = p1 + ((p2 - p1) / 2.0)

	return [
		Vector3(newpos.x, newpos.y, newpos.z),
		Vector3(p2.x, p2.y, p2.z)
	]


func set_path(value):
	if get_node(value) is Path:
		_path_node = get_node(value)
		_path_length = _path_node.curve.get_baked_length()
		path = value
		_adjust_copies()
	else:
		printerr("Selected node is not a Path instance")
		_path_node = null
		path = null


func set_path_offset_start(value):
	path_offset_start = value
	if _path_node != null:
		_adjust_position_of_copies()


func set_repeat_count(value):
	# Make sure the value will be at least 1
	repeat_count = max(value, 1)
	if _path_node != null:
		_adjust_copies()


func set_repeat_offset(value):
	# Make sure there is always the same number of offsets and levels
	if value == repeat_offset:
		return
	
	repeat_offset = value
	
	if _path_node != null:
		_adjust_position_of_copies()


func set_force_refresh(value):
	if _path_node != null:
		_adjust_copies()


func _adjust_copies():
	# Clean up existing hooks
	for child in get_children():
		if child.name.begins_with(_get_hook_name_prefix()):
			remove_child(child)
			child.queue_free()
	
	for orig_child in get_children():
		# Ignore hooks
		if orig_child.name.begins_with(_get_hook_name_prefix()):
			continue
		
		# Create a "hook" for each actual child, to hold the copies in
		var hook = Spatial.new()
		hook.name = _get_hook_name(orig_child)
		add_child(hook)
		_hooks[hook.name] = hook
		
		# Original instance has to be moved as well, so start with 0
		for index in range(0, repeat_count):
			var position_rotation = _get_copy_position_rotation(index)
			if index == 0:
				orig_child.transform.origin = position_rotation[0]
				orig_child.transform = orig_child.transform.looking_at(
					position_rotation[1], Vector3.UP
				)
				if instance_offset != Vector3.ZERO:
					orig_child.translate(
						get_transform().basis.xform(instance_offset)
					)
			else:
				var temp_index = index
				var copy = orig_child.duplicate()
				copy.transform.origin = position_rotation[0] + instance_offset
				copy.transform = copy.transform.looking_at(
					position_rotation[1], Vector3.UP
				)
				if instance_offset != Vector3.ZERO:
					copy.translate(get_transform().basis.xform(instance_offset))
				hook.add_child(copy)


func _adjust_position_of_copies():	
	for orig_child in get_children():
		# Ignore hooks
		if orig_child.name.begins_with(_get_hook_name_prefix()):
			continue
		
		# Find the corresponding hook
		var hook = _hooks.get(_get_hook_name(orig_child))
		if hook == null:
			printerr("Corresponding hook not found: ", orig_child.name)
			return
		
		# Original instance has to be moved as well, so start with 0
		for index in range(0, repeat_count):
			var position_rotation = _get_copy_position_rotation(index)
			if index == 0:
				orig_child.transform.origin = position_rotation[0]
				orig_child.transform = orig_child.transform.looking_at(
					position_rotation[1], Vector3.UP
				)
				if instance_offset != Vector3.ZERO:
					orig_child.translate(
						get_transform().basis.xform(instance_offset)
					)
			else:
				# Find the copy that should be moved
				var copy = hook.get_children()[index - 1]
				copy.transform.origin = position_rotation[0]
				copy.transform = copy.transform.looking_at(
					position_rotation[1], Vector3.UP
				)
				if instance_offset != Vector3.ZERO:
					copy.translate(get_transform().basis.xform(instance_offset))


func _get_hook_name_prefix():
	return "_array_modifier_hook_" + str(get_instance_id())


func _get_hook_name(child):
	return _get_hook_name_prefix() + "_" + str(child.get_instance_id())