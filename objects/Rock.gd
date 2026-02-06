extends Node2D
class_name Resource_Rock

onready var _animation_player:AnimationPlayer = $AnimationPlayer

var _health:int = 5
var _mined:int = 0


func _ready():
	_animation_player.play("Objectssway_standard")
	_animation_player.advance(rand_range(0, _animation_player.get_current_animation_length()))


func start_mine(mining_speed:float):
	_mined += 1
	if _mined > 1:
		return 
	_mined = true
	$MiningTimer.start(mining_speed)
	_animation_player.play("mining")

func stop_mine():
	_mined -= 1
	if _mined > 0:
		return 
	$MiningTimer.stop()
	_animation_player.play("RESET")
	_animation_player.play("Objectssway_standard")

func _on_MiningTimer_timeout():
	_health -= 1
	if _health <= 0:
		_die()

func _random_spawn()->Vector2:
	var coord:Vector2 = Vector2(
		rand_range( - 16, 16), 
		rand_range( - 16, 16)
	)
	coord += global_position
	return coord

func _die():
	var random_amount:int = (randi() % 4) + 1
	for _i in range(random_amount):
		var resource: = preload("res://objects/Stone_Resource.tscn").instance()
		resource.global_position = _random_spawn()
		get_parent().add_child(resource)
	$MiningTimer.stop()
	queue_free()
