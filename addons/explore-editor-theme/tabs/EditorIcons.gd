@tool
extends MarginContainer

signal filesystem_changed()

# Private properties
var _icon_map : Dictionary = {}
var _default_type_name : String = "EditorIcons"
var _icon_tags_file := "res://addons/explore-editor-theme/icon_tags.txt"
var _icon_tags := {}

# Utils
const _PluginUtils := preload("res://addons/explore-editor-theme/utils/PluginUtils.gd")
const _IconSaver := preload("res://addons/explore-editor-theme/ui/IconSaver.gd")

# Node references
@onready var layout_root : BoxContainer = $Layout
@onready var filter_tool : Control = $Layout/Toolbar/Filter
@onready var type_tool : Control = $Layout/Toolbar/Type
@onready var icon_list : ItemList = %IconList

@onready var empty_panel : Control = %EmptyPanel
@onready var icon_panel : Control = %IconPanel
@onready var icon_preview : TextureRect = %IconPreview
@onready var icon_preview_info : Label = %IconPreviewInfo
@onready var icon_title : Label = %IconName
@onready var icon_code : Control = %IconCode
@onready var icon_saver : _IconSaver = %IconSaver



func _ready() -> void:
	_load_icon_tags()
	_update_theme()
	%IconPanel.hide()

	_icon_map[_default_type_name] = []
	type_tool.add_text_item(_default_type_name)

	filter_tool.text_changed.connect(self._on_filter_text_changed)
	type_tool.item_selected.connect(self._on_type_item_selected)
	icon_list.multi_selected.connect(self._on_icon_list_multi_selected)
	icon_saver.filesystem_changed.connect(self.emit_signal.bind("filesystem_changed"))

	%ListMode.button_group.pressed.connect(func(x):_refresh_icon_list())



func _update_theme() -> void:
	if (!_PluginUtils.get_plugin_instance(self)):
		return

	layout_root.add_theme_constant_override("separation", 8 * EditorInterface.get_editor_scale())
	icon_preview_info.add_theme_color_override("font_color", get_theme_color("contrast_color_2", "Editor"))
	icon_title.add_theme_font_override("font", get_theme_font("title", "EditorFonts"))

	%ListMode.icon = get_theme_icon("FileList", "EditorIcons")
	%IconsMode.icon = get_theme_icon("FileThumbnail", "EditorIcons")


func _load_icon_tags() -> void:
	if FileAccess.file_exists(_icon_tags_file):
		var file := FileAccess.open(_icon_tags_file, FileAccess.READ)
		_icon_tags = str_to_var(file.get_as_text())


func store_icon_tags() -> void:
	var file := FileAccess.open(_icon_tags_file, FileAccess.WRITE)
	file.store_string(var_to_str(_icon_tags))


func add_icon_set(icon_names : PackedStringArray, type_name : String) -> void:
	if (icon_names.size() == 0 || type_name.is_empty()):
		return

	if (!_icon_map.has(type_name)):
		type_tool.add_text_item(type_name)

	var sorted_icon_names = Array(icon_names)
	sorted_icon_names.sort()
	_icon_map[type_name] = sorted_icon_names

	_refresh_icon_list()


func _refresh_icon_list() -> void:
	var prev_selection: Array = Array(icon_list.get_selected_items()).map(func(index): return icon_list.get_item_tooltip(index))

	icon_list.clear()

	var is_icon_mode: bool = %IconsMode.button_pressed
	if is_icon_mode:
		%IconList.fixed_icon_size = Vector2(32, 32)
		%IconList.fixed_column_width = 40
	else:
		%IconList.fixed_column_width = 200
		%IconList.fixed_icon_size = Vector2(16,16)

	var filter = filter_tool.filter_text.to_lower()
	var type_name = type_tool.get_selected_text()
	var idx := 0

	var new_selection := []

	for icon in _icon_map[type_name]:
		var item_match := true
		for sub_filter in filter.split(" "):
			var inverse: bool = sub_filter.begins_with("-")
			sub_filter = sub_filter.trim_prefix("-")
			var tags_only: bool = sub_filter.begins_with("tag:")
			sub_filter = sub_filter.trim_prefix("tag:")

			var matched := false
			if not tags_only and (sub_filter.is_empty() or sub_filter in icon.to_lower()):
				matched = true

			elif type_name+":"+icon in _icon_tags:
				for tag in _icon_tags[type_name+":"+icon]:
					if sub_filter in tag.to_lower():
						matched = true
			if tags_only and sub_filter == "none":
				if not type_name+":"+icon in _icon_tags or _icon_tags[type_name+":"+icon].is_empty():
					matched = true

			if inverse: matched = not matched

			item_match = item_match and matched

		if not item_match:
			continue

		if is_icon_mode:
			icon_list.add_icon_item(get_theme_icon(icon, type_name))
		else:
			icon_list.add_item(icon, get_theme_icon(icon, type_name))

		icon_list.set_item_tooltip(idx, icon)
		if icon in prev_selection:
			new_selection.append(idx)

		idx += 1

	for i in new_selection:
		icon_list.select(i, false)
	if not new_selection.is_empty():
		_on_icon_list_multi_selected(new_selection[0], true)
	elif not icon_list.item_count == 0:
		icon_list.select(0)
		_on_icon_list_multi_selected(0, true)
	else:
		_on_icon_list_multi_selected(-1, false)
	update_common_tags()
	await get_tree().process_frame
	icon_list.ensure_current_is_visible()


# Events
func _on_filter_text_changed(value : String) -> void:
	_refresh_icon_list()

func _on_type_item_selected(value : int) -> void:
	_refresh_icon_list()

#func _on_icon_item_selected(item_index : int) -> void:


func _on_debug_pressed() -> void:
	#print(_icon_map)
	print(_icon_tags)



func _on_icon_list_multi_selected(item_index: int, selected: bool) -> void:
	if len(icon_list.get_selected_items()) == 0:
		empty_panel.show()
		icon_panel.hide()
	else:
		empty_panel.hide()
		icon_panel.show()

		if len(icon_list.get_selected_items()) == 1:
			var icon_texture = icon_list.get_item_icon(item_index)
			var icon_name = icon_list.get_item_tooltip(item_index)
			var type_name = type_tool.get_selected_text()
			%SingleSelection.show()
			%MultiSelectionLabel.hide()
			icon_preview.texture = icon_texture
			icon_preview_info.text = str(icon_texture.get_width()) + "x" + str(icon_texture.get_height())
			icon_title.text = icon_name
			icon_code.code_text = "get_theme_icon(\"" + icon_name + "\", \"" + type_name + "\")"

			icon_saver.icon_name = icon_name
			icon_saver.type_name = type_name
		else:
			%SingleSelection.hide()
			%MultiSelectionLabel.show()
			%MultiSelectionLabel.custom_minimum_size.y = %SingleSelection.size.y

	update_tags()


func _on_add_tag_edit_text_submitted(new_text: String) -> void:
	for index in icon_list.get_selected_items():
		var icon_name := icon_list.get_item_tooltip(index)
		var type_name: String = type_tool.get_selected_text()

		var id := type_name+":"+icon_name
		if not id in _icon_tags:
			_icon_tags[id] = []

		_icon_tags[id].append(new_text)

	%AddTagEdit.clear()
	update_tags()
	store_icon_tags()
	_refresh_icon_list()


func update_tags() -> void:
	var tags := []
	var first := true
	for index in icon_list.get_selected_items():
		var icon_name := icon_list.get_item_tooltip(index)
		var type_name: String = type_tool.get_selected_text()

		var id := type_name+":"+icon_name
		if id in _icon_tags:
			if first:
				for tag in _icon_tags[id]:
					tags.append(tag)
			else:
				for tag in tags:
					if not tag in _icon_tags[id]:
						tags.erase(tag)

		first = false

	for child in %Tags.get_children():
		child.queue_free()

	for tag in tags:
		var button := Button.new()
		button.text = tag
		button.gui_input.connect(_on_tag_gui_input.bind(button))
		%Tags.add_child(button)


func update_common_tags() -> void:
	var common_tags := {"none":0}
	for icon in _icon_tags:
		for tag in _icon_tags[icon]:
			if not tag in common_tags:
				common_tags[tag] = 0
			else:
				common_tags[tag] += 1

	var tags := common_tags.keys()
	tags.sort_custom(func(x,y): return common_tags[x] > common_tags[y])
	for child in %CommonTags.get_children():
		child.queue_free()

	for tag in tags:
		if common_tags[tag] < 2:
			continue
		var button := Button.new()
		button.text = tag
		button.gui_input.connect(_on_tag_gui_input.bind(button, true))
		%CommonTags.add_child(button)


var right_click_on_button :Button= null
func _on_tag_gui_input(event:InputEvent, tag_button:Button, global_tags := false) -> void:
	if not event is InputEventMouseButton or not event.pressed:
		return

	if event.button_index == MOUSE_BUTTON_LEFT:
		if Input.is_key_pressed(KEY_SHIFT):
			filter_tool.input.text += " tag:"+tag_button.text
		else:
			filter_tool.input.text = "tag:"+tag_button.text
		filter_tool.filter_text = filter_tool.input.text
		_refresh_icon_list()
		return

	if event.button_index == MOUSE_BUTTON_MIDDLE:
		if Input.is_key_pressed(KEY_SHIFT):
			filter_tool.input.text += " -tag:"+tag_button.text
		else:
			filter_tool.input.text = "-tag:"+tag_button.text
		filter_tool.filter_text = filter_tool.input.text
		_refresh_icon_list()
		return

	if global_tags:
		return

	if event.button_index == MOUSE_BUTTON_RIGHT:
		right_click_on_button = tag_button
		%TagPopupMenu.popup_on_parent(Rect2(get_global_mouse_position(), Vector2()))


func _on_tag_popup_menu_id_pressed(id: int) -> void:
	if id == 0:
		%RenameEdit.show()
		%RenameEdit.global_position = right_click_on_button.global_position
		%RenameEdit.text = right_click_on_button.text
		%RenameEdit.grab_focus()
		%RenameEdit.select_all()
		%RenameEdit.custom_minimum_size.x = right_click_on_button.size.x

	if id == 1:
		for index in icon_list.get_selected_items():
			var icon_name := icon_list.get_item_tooltip(index)
			var type_name: String = type_tool.get_selected_text()

			var icon_id := type_name+":"+icon_name
			if icon_id in _icon_tags:
				_icon_tags[icon_id].erase(right_click_on_button.text)
		update_tags()
		_refresh_icon_list()


func rename_tag(from:String, to:String) -> void:
	%RenameEdit.hide()
	if from == to:
		return

	to = to.replace(" ", "")

	for index in icon_list.get_selected_items():
		var icon_name := icon_list.get_item_tooltip(index)
		var type_name: String = type_tool.get_selected_text()

		var icon_id := type_name+":"+icon_name
		if icon_id in _icon_tags:
			if from in _icon_tags[icon_id]:
				_icon_tags[icon_id].erase(from)
				_icon_tags[icon_id].append(to)

	_refresh_icon_list()


func _on_rename_edit_focus_exited() -> void:
	rename_tag(right_click_on_button.text, %RenameEdit.text)


func _on_rename_edit_text_submitted(new_text: String) -> void:
	rename_tag(right_click_on_button.text, new_text)
