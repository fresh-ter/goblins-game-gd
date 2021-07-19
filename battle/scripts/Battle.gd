extends Spatial

const RAY_LENGTH = 1000
const MOUSE_HOVER_Y_OFFSET = Vector3(0, 0.05, 0)
const MOVE_AREAS := 3.0

const path_dot_scene = preload("res://battle/terrain/path_dot/PathDot.tscn")

onready var camera := $Camera
onready var terrain := $Terrain
onready var mouse_hover := $MouseHover
onready var trace_path := $TracePath
onready var battleUI: = $BattleUI


var team1_units_meta = {
	1: { "RACE": GlobalConstants.RACE.GOBLIN, "WEAPON": GlobalConstants.WEAPON.AXE },
	2: { "RACE": GlobalConstants.RACE.GOBLIN, "WEAPON": GlobalConstants.WEAPON.MACE },
	3: { "RACE": GlobalConstants.RACE.GOBLIN, "WEAPON": GlobalConstants.WEAPON.AXE },
	4: { "RACE": GlobalConstants.RACE.GOBLIN, "WEAPON": GlobalConstants.WEAPON.MACE },
	5: { "RACE": GlobalConstants.RACE.GOBLIN, "WEAPON": GlobalConstants.WEAPON.AXE },
	6: { "RACE": GlobalConstants.RACE.GOBLIN, "WEAPON": GlobalConstants.WEAPON.MACE },
	7: { "RACE": GlobalConstants.RACE.GOBLIN, "WEAPON": GlobalConstants.WEAPON.AXE },
}
var team1_spawn_point = Vector3(1, 0, 19)

var team2_units_meta = {
	41: { "RACE": GlobalConstants.RACE.GOBLIN, "WEAPON": GlobalConstants.WEAPON.AXE },
	51: { "RACE": GlobalConstants.RACE.GOBLIN, "WEAPON": GlobalConstants.WEAPON.AXE },
	52: { "RACE": GlobalConstants.RACE.GOBLIN, "WEAPON": GlobalConstants.WEAPON.MACE },
}
var team2_spawn_point = Vector3(1, 0, 1)

var team1 := {}
var team2 := {}
var selected_unit = null
var is_action_in_progress := false

var current_hover_cell = Vector3.ZERO
var trace_path_points := []
var hovered_enemy: BattleUnit = null

var turn_number := 1
var is_enemy_turn := false

# Called when the node enters the scene tree for the first time.
func _ready():
	terrain.set_obstacles($Forest)
	if !terrain.is_point_walkable(team1_spawn_point):
		push_error("Team1 spawn point %s is not walkable" % team1_spawn_point)
	if !terrain.is_point_walkable(team2_spawn_point):
		push_error("Team2 spawn point %s is not walkable" % team2_spawn_point)
	team1 = _init_team(team1_units_meta, team1_spawn_point)
	team2 = _init_team(team2_units_meta, team2_spawn_point, true)
#	battle_manager.initialize_battle(team1_units, team2_units, Vector3(1, 0, 9), Vector3(1, 0 ,1))

# Creates and spawns units of the team
func _init_team(units_meta: Dictionary, initial_spawn_point: Vector3, enemy = false) -> Dictionary:
	var team := {}
	var spawn_point = initial_spawn_point
	for unit_id in units_meta.keys():
		if spawn_point == null:
			push_error("Team can't be spawned. Stoped at unit %s" % unit_id)
			break
		var unit_meta = units_meta.get(unit_id)
		var team_unit_meta = unit_meta.duplicate()
		var unit = _produce_unit(team_unit_meta)
		unit.battle_id = unit_id
		_spawn_unit(unit_id, unit, $Units, spawn_point, PI if not enemy else 0)
		team_unit_meta["UNIT"] = unit
		team[unit_id] = team_unit_meta
		spawn_point = terrain.get_neighbor_walkable_point(spawn_point)
	return team

#
# Turn Managment
#

func handle_next_turn():
	# TODO iterate over all unit and call next_turn_update
	pass

func _ai_turn():
	# TODO: make AI turn
	turn_number += 1 # TODO: display turn number
	is_enemy_turn = false
	battleUI.enable_next_turn_button()
#
# MOUSE INPUT
#

func _input(event: InputEvent):
	if is_action_in_progress:
		return true
	_handle_left_mouse_click(event)
	_handle_right_mouse_click(event)
	_handle_mouse_move(event)
	
func _handle_left_mouse_click(event: InputEvent):
	if not event is InputEventMouseButton:
		return
	if event.button_index != BUTTON_LEFT or not event.pressed:
		return
	var m_position = _get_mouse_projected_position(event.position)
	if !m_position:
		return
	var hover_obj = terrain.get_terrain_object(m_position)
	if hover_obj["TYPE"] != BattleConstants.TERRAIN_OBJECTS.UNIT and selected_unit:
		print("DESELECT")
		_deselect_unit(selected_unit)
		return
	if not _is_ally(hover_obj["ID"]):
		return
	if hover_obj["TYPE"] == BattleConstants.TERRAIN_OBJECTS.UNIT:
		var unit_meta = _get_unit_meta_by_id(hover_obj["ID"])
		if !selected_unit:
			_select_unit(unit_meta["UNIT"])
		elif selected_unit != unit_meta["UNIT"]:
			_deselect_unit(selected_unit)
			_select_unit(unit_meta["UNIT"])

func _handle_right_mouse_click(event: InputEvent):
	if not event is InputEventMouseButton:
		return
	if event.button_index != BUTTON_RIGHT or not event.pressed:
		return
	
	var m_position = _get_mouse_projected_position(event.position)
	if m_position and selected_unit:
#		terrain.free_point_from_unit(selected_unit.global_transform.origin)
		_move_unit(selected_unit, m_position)

func _handle_mouse_move(event: InputEvent):
	if not event is InputEventMouseMotion:
		return
	var m_position = _get_mouse_projected_position(event.position)
	if m_position:
		var hover_cell = terrain.get_map_cell_center(m_position)
		if hover_cell == current_hover_cell:
			return
		var hover_obj = terrain.get_terrain_object(m_position)
		if hover_obj["TYPE"] == BattleConstants.TERRAIN_OBJECTS.UNIT and not _is_ally(hover_obj["ID"]):
			var unit_meta = _get_unit_meta_by_id(hover_obj["ID"])
			var unit = unit_meta["UNIT"]
			if unit != hovered_enemy:
				battleUI.display_enemy_info(unit)
				_occupy_enemy_unit_point()
			_free_enemy_unit_point(unit)
		elif hovered_enemy:
			_occupy_enemy_unit_point()
			battleUI.hide_enemy_info()
		current_hover_cell = hover_cell
		_move_mouse_hover(m_position)
		_color_mouse_hover(m_position)
		if selected_unit != null:
			_draw_trace_path(selected_unit, selected_unit.global_transform.origin, m_position)

func _draw_trace_path(unit: BattleUnit, from: Vector3, to: Vector3):
	_clear_trace_path()
	var path_points = terrain.get_map_path(from, to)
	path_points.remove(0)

	var i = 0
	for point in path_points:
		var dot = path_dot_scene.instance()
		dot.set_path_color(_get_current_trace_path_color(unit, unit.max_move_points - unit.move_points + i + 1))
		dot.translation = point
		trace_path.add_child(dot)
		trace_path_points.append(weakref(dot))
		i += 1

func _get_current_trace_path_color(unit: BattleUnit, spend_points):
	var area_points = unit.max_move_points / MOVE_AREAS
	if spend_points >= unit.max_move_points:
		return PathDot.PathDotColor.WHITE
	
	if spend_points <= area_points:
		return PathDot.PathDotColor.GREEN
	elif spend_points <= area_points * 2:
		return PathDot.PathDotColor.YELLOW
	else:
		return PathDot.PathDotColor.RED
		

func _clear_trace_path():
	for path_point in trace_path_points:
		var path_point_ref = path_point.get_ref()
		if path_point_ref:
			path_point_ref.queue_free()
	trace_path_points.clear()

func _move_mouse_hover(pos: Vector3):
	mouse_hover.translation = terrain.get_map_cell_center(pos) + MOUSE_HOVER_Y_OFFSET

func _free_enemy_unit_point(unit: BattleUnit):
	hovered_enemy = unit
	terrain.free_point_from_unit(unit.global_transform.origin)

func _occupy_enemy_unit_point():
	if hovered_enemy:
		terrain.occupy_point_with_unit(hovered_enemy.global_transform.origin, hovered_enemy.battle_id)
		hovered_enemy = null

func _color_mouse_hover(pos: Vector3):
	var hover_obj = terrain.get_terrain_object(pos)
	match hover_obj["TYPE"]:
		BattleConstants.TERRAIN_OBJECTS.FREE:
			mouse_hover.hover_neutral()
		BattleConstants.TERRAIN_OBJECTS.OBSTACLE:
			mouse_hover.hover_obstacle()
		BattleConstants.TERRAIN_OBJECTS.UNIT:
			if _is_ally(hover_obj["ID"]):
				mouse_hover.hover_ally()
			else:
				mouse_hover.hover_enemy()

func _get_mouse_projected_position(screen_position: Vector2):
	var from = camera.project_ray_origin(screen_position)
	var to = from + camera.project_ray_normal(screen_position) * RAY_LENGTH
	var space_state = camera.get_world().direct_space_state
	var result = space_state.intersect_ray(from, to, [], 1)
	
	if not result:
		return null
	return result.position

#
# UNIT API
#

func _select_unit(unit: BattleUnit):
	terrain.free_point_from_unit(unit.global_transform.origin)
	selected_unit = unit
	unit.set_selected(true)
	battleUI.display_unit_info(unit)
	
func _deselect_unit(unit: BattleUnit):
	terrain.occupy_point_with_unit(unit.global_transform.origin, unit.battle_id)
	selected_unit = null
	unit.set_selected(false)
	_clear_trace_path()
	battleUI.hide_unit_info()

func _move_unit(unit: BattleUnit, pos: Vector3):
	var path = terrain.get_map_path(unit.global_transform.origin, pos)
	if hovered_enemy:
		path.resize(path.size() - 1)
	if path.size() > 1:
		is_action_in_progress = true
		unit.set_path(path)

func _produce_unit(unit_meta) -> BattleUnit:
	var unit_scene = BattleConstants.RACES_SCENES[unit_meta["RACE"]]
	var unit = unit_scene.instance()
	unit.right_hand = unit_meta["WEAPON"]
	return unit

func _spawn_unit(unit_id: int, unit: BattleUnit, parent_node: Node, pos: Vector3, rot: float):
	unit.translation = pos
	unit.rotate_y(rot)
	parent_node.add_child(unit)
	unit.connect("on_move_end", self, "_handle_unit_move_end", [unit_id])
	unit.connect("on_dead", self, "_handle_unit_death", [unit_id])
	terrain.register_unit(pos, unit_id)
	terrain.occupy_point_with_unit(pos, unit_id)

func _is_ally(id: int):
	return team1.has(id)

func _get_unit_meta_by_id(id: int):
	if _is_ally(id):
		return team1.get(id)
	return team2.get(id, null)
	
func _handle_unit_move_end(unit_id: int):
	var unit_meta = _get_unit_meta_by_id(unit_id)
	if hovered_enemy:
		unit_meta["UNIT"].mele_attack(hovered_enemy)
	is_action_in_progress = false

func _handle_unit_death(unit_id: int):
	var unit_meta = _get_unit_meta_by_id(unit_id)
	var point = unit_meta["UNIT"].global_transform.origin
	terrain.unregister_unit(point)
	terrain.free_point_from_unit(point)
