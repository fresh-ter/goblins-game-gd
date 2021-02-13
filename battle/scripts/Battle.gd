extends Spatial

const RAY_LENGTH = 1000
const MOUSE_HOVER_Y_OFFSET = Vector3(0, 0.05, 0)

onready var camera := $Camera
onready var goblin := $BattleGoblin
onready var terrain := $Terrain
onready var mouse_hover := $MouseHover

var team1_units_meta = {
	1: { "RACE": GlobalConstants.RACE.GOBLIN, "WEAPON": GlobalConstants.WEAPON.AXE },
	2: { "RACE": GlobalConstants.RACE.GOBLIN, "WEAPON": GlobalConstants.WEAPON.AXE },
	3: { "RACE": GlobalConstants.RACE.GOBLIN, "WEAPON": GlobalConstants.WEAPON.AXE },
}
var team1_spawn_point = Vector3(1, 0, 9)

var team2_units_meta = {
	4: { "RACE": GlobalConstants.RACE.GOBLIN, "WEAPON": GlobalConstants.WEAPON.AXE },
	5: { "RACE": GlobalConstants.RACE.GOBLIN, "WEAPON": GlobalConstants.WEAPON.AXE },
}
var team2_spawn_point = Vector3(1, 0, 1)

var team1 := {}
var team2 := {}

# Called when the node enters the scene tree for the first time.
func _ready():
	terrain.set_obstacles($Forest)
	if !terrain.is_point_walkable(team1_spawn_point):
		push_error("Team1 spawn point %s is not walkable" % team1_spawn_point)
	if !terrain.is_point_walkable(team2_spawn_point):
		push_error("Team2 spawn point %s is not walkable" % team2_spawn_point)
	team1 = _init_team(team1_units_meta, team1_spawn_point, true)
	team2 = _init_team(team2_units_meta, team2_spawn_point)
#	battle_manager.initialize_battle(team1_units, team2_units, Vector3(1, 0, 9), Vector3(1, 0 ,1))

# Creates and spawns units of the team
func _init_team(units_meta: Dictionary, initial_spawn_point: Vector3, rotate = false) -> Dictionary:
	var team := {}
	var spawn_point = initial_spawn_point
	for unit_id in units_meta.keys():
		if spawn_point == null:
			push_error("Team can't be spawned. Stoped at unit %s" % unit_id)
			break
		var unit_meta = units_meta.get(unit_id)
		var team_unit_meta = unit_meta.duplicate()
		var unit = _produce_unit(team_unit_meta)
		_spawn_unit(unit, $Units, spawn_point, PI if rotate else 0)
		terrain.occupy_point_with_unit(spawn_point, unit_id)
		team_unit_meta["UNIT"] = unit
		team[unit_id] = team_unit_meta
		spawn_point = terrain.get_neighbor_walkable_point(spawn_point)
	return team

func _input(event: InputEvent):
	_handle_mouse_click(event)
	_handle_mouse_move(event)

func _handle_mouse_click(event: InputEvent):
	if not event is InputEventMouseButton:
		return
	if event.button_index != BUTTON_LEFT or not event.pressed:
		return
	
	var m_position = _get_mouse_projected_position(event.position)
	if m_position:
		_move_unit(goblin, m_position)

func _handle_mouse_move(event: InputEvent):
	if not event is InputEventMouseMotion:
		return
	var m_position = _get_mouse_projected_position(event.position)
	if m_position:
		_move_mouse_hover(m_position)
		_color_mouse_hover(m_position)

func _move_unit(unit: BattleUnit, pos: Vector3):
	var path = terrain.get_map_path(unit.global_transform.origin, pos)
	unit.set_path(path)

func _move_mouse_hover(pos: Vector3):
	mouse_hover.translation = terrain.get_map_cell_center(pos) + MOUSE_HOVER_Y_OFFSET

func _color_mouse_hover(pos: Vector3):
	var hover_obj = terrain.get_terrain_object(pos)
	match hover_obj["TYPE"]:
		BattleConstants.TERRAIN_OBJECTS.FREE:
			mouse_hover.hover_neutral()
		BattleConstants.TERRAIN_OBJECTS.OBSTACLE:
			mouse_hover.hover_obstacle()
		BattleConstants.TERRAIN_OBJECTS.UNIT:
			if team1.has(hover_obj["ID"]):
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

func _produce_unit(unit_meta) -> BattleUnit:
	var unit_scene = BattleConstants.RACES_SCENES[unit_meta["RACE"]]
	var unit = unit_scene.instance()
	unit.right_hand = unit_meta["WEAPON"]
	return unit
	
func _spawn_unit(unit: BattleUnit, parent_node: Node, pos: Vector3, rot: float):
	unit.translation = pos
	unit.rotate_y(rot)
	parent_node.add_child(unit)
