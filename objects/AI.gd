extends Node
class_name AI

var _friend_bases:int = 0
var _friend_bots:int = 1

onready var _factories:Node2D = $"/root/Level/Structures"
onready var _friendlies:Node2D = $"/root/Level/Friendly"
onready var _enemies:Node2D = $"/root/Level/Enemies"
onready var _enemy_structures:Node2D = $"/root/Level/EnemyStructures"
onready var _world:Node2D = $"/root/Level/World"
onready var _level:Node2D = $"/root/Level"


const FACTORY_STONE_COST = 5
const FACTORY_WOOD_COST = 5

enum AI_LEVELS{
	SAFE, 
	COLLECT, 
	AGGRESSIVE
}

var _ai_encouragement:int = 0
var _starting_enemy_structures = 0
var _win_time:int = 0

var _player_move_speed_modifier: = 0.0
var _player_attack_speed_modifier: = 0.0
var _player_damage_modifier: = 0.0
var _bot_attack_speed_modifier: = 0.0
var _bot_move_speed_modifier: = 0.0

enum Modifiers{
	PLAYER_MOVE_SPEED, 
	PLAYER_ATTACK_SPEED, 
	PLAYER_DAMAGE, 
	BOT_ATTACK_SPEED, 
	BOT_MOVE_SPEED
}
var _modifiers_map:Dictionary

func setup():
	_factories = $"/root/Level/Structures"
	_friendlies = $"/root/Level/Friendly"
	_enemies = $"/root/Level/Enemies"
	_enemy_structures = $"/root/Level/EnemyStructures"
	_world = $"/root/Level/World"
	_level = $"/root/Level"
	_starting_enemy_structures = _enemy_structures.get_child_count()
	
	for mod in Modifiers:
		_modifiers_map[mod] = 0.0
	

func _update_stats()->void :
	if not _factories or not is_instance_valid(_factories):
		return 
	
	_friend_bases = _factories.get_child_count()
	_friend_bots = _friendlies.get_child_count()
	
	set_nest_difficulty()
	
	if _friend_bases >= 3:
		_ai_encouragement = AI_LEVELS.COLLECT
	else :
		_ai_encouragement = AI_LEVELS.SAFE


func set_nest_difficulty():
	var difficulty: = 0
	if _friend_bases > 1:
		if _friend_bases > 2:
			difficulty += 2
		else :
			difficulty += 1

	if _friend_bots > 2:
		if _friend_bots > 3:
			difficulty += 2
		else :
			difficulty += 1
	
	if difficulty > 4:
		difficulty = 4
	
	for nest in _enemy_structures.get_children():
		nest.set_difficulty(difficulty)
	

func _ready():
	randomize()

func factory_died():
	if _factories.get_child_count() - 1 <= 0:
		_level.show_gameover()

func set_end_time():
	_win_time = OS.get_unix_time() - _level.get_time_start()

func get_end_time():
	return _win_time

func get_factories()->Node2D:
	return _factories

func get_friendlies()->Node2D:
	return _friendlies

func get_enemies()->Node2D:
	return _enemies

func get_world()->Node2D:
	return _world

func get_level()->Node2D:
	return _level

func get_enemy_structures()->Node2D:
	return _enemy_structures

func get_ai_encouragement()->int:
	_update_stats()
	return _ai_encouragement

func get_friend_bases()->int:
	return _friend_bases

func get_friend_bots()->int:
	return _friend_bots

func get_modifier(modifier:int)->float:
	if not _modifiers_map.has(modifier):
		return 0.0
	
	return _modifiers_map[modifier]

func set_modifier(modifier:int, value:float):
	_modifiers_map[modifier] = value

func get_if_can_build(wood:int, stone:int)->bool:
	if wood >= FACTORY_WOOD_COST and stone >= FACTORY_STONE_COST:
		return true
	return false
