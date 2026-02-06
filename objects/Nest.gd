extends Node2D

export  var _spawn_time:float = 5
export  var _health:int = 5

var _spawn_resources: = [
	preload("res://objects/BabyEnemy.tscn"), 
	preload("res://objects/ChildEnemy.tscn"), 
	preload("res://objects/MotherEnemy.tscn"), 
	preload("res://objects/FatherEnemy.tscn")
]



var _difficulty_map:Dictionary = {
	0:[1, 0, 0, 0], 
	1:[0.6, 0.2, 0.2, 0], 
	2:[0.4, 0.4, 0.2, 0], 
	3:[0.2, 0.5, 0.2, 0.1], 
	4:[0.2, 0.2, 0.3, 0.3]
}
var _current_difficulty:int = 0

func _ready():
	$SpawnTime.start(_spawn_time)



func _on_SpawnTime_timeout():
	var enemy_instance: = _calculate_spawn().instance()
	$"/root/Ai".get_enemies().add_child(enemy_instance)
	enemy_instance.global_position = $SpawnPos.global_position
	$SpawnTime.start(_spawn_time)

func take_damage(damage:int):
	_health -= damage
	$AnimationPlayer.play("hit")
	if _health <= 0:
		var resource: = preload("res://objects/Crystal_Resource.tscn").instance()
		$"/root/Ai".get_world().call_deferred("add_child", resource)
		resource.global_position = global_position
		queue_free()

func _calculate_spawn()->PackedScene:
	var chance:float = rand_range(0, 1.0)
	var difficulty_table:Array = _difficulty_map[_current_difficulty]
	var index: = 0
	
	for _i in range(difficulty_table.size()):
		if chance < difficulty_table[0]:
			return _spawn_resources[index]
		else :
			chance -= difficulty_table[0]
			difficulty_table.pop_front()
			index += 1
	
	return _spawn_resources[0]

func set_difficulty(difficulty:int):
	_current_difficulty = difficulty

func set_spawn_speed(speed:float):
	_spawn_time = speed
