extends Node2D
class_name Factory

const MAX_BUILD_PROGRESS:int = 5
var _current_build_progress:int = 0
var _build_progress_time:float = 1.0

var _wood:int = 0
var _stone:int = 0
var _health:int = 5

enum BUILD_OPTIONS{
	BUILDBOT,
	AGGRESSOR_BOT,
	ROCKET,
	RANDOM_UPGRADE,
}
enum BUILD_PROPERTIES{
	COST,
	TIME,
	PATH
}

const _build_map:Dictionary = {
	BUILD_OPTIONS.BUILDBOT:{
		BUILD_PROPERTIES.COST:Vector2(4, 4),
		BUILD_PROPERTIES.TIME:5.0,
		BUILD_PROPERTIES.PATH:"res://objects/BuildBot.tscn"
	},
	BUILD_OPTIONS.AGGRESSOR_BOT:{
		BUILD_PROPERTIES.COST:Vector2(6, 4),
		BUILD_PROPERTIES.TIME:6.0,
		BUILD_PROPERTIES.PATH:"res://objects/DefenceBot.tscn"
	},
	BUILD_OPTIONS.ROCKET:{
		BUILD_PROPERTIES.COST:Vector2(20, 20),
		BUILD_PROPERTIES.TIME:10.0
	},
	BUILD_OPTIONS.RANDOM_UPGRADE:{
		BUILD_PROPERTIES.COST:Vector2(10, 10),
		BUILD_PROPERTIES.TIME:10.0
	},

}

var _build_option:int = BUILD_OPTIONS.BUILDBOT
var _can_build:bool = false


func _ready():
	$BuildProgressTimer.start(_build_progress_time)

func _process(delta):
	if _can_build:
		if _can_afford_current_build():
			var _current_cost:Vector2 = _build_map[_build_option][BUILD_PROPERTIES.COST]
			_wood -= _current_cost.x
			_stone -= _current_cost.y
			$BuildTime.start(_build_map[_build_option][BUILD_PROPERTIES.TIME])
			$AnimationPlayer.play("sway")
			_can_build = false

func _can_afford_current_build()->bool:
	var _current_cost:Vector2 = _build_map[_build_option][BUILD_PROPERTIES.COST]
	if _wood >= _current_cost.x and _stone >= _current_cost.y:
		return true
	return false


func _on_BuildProgressTimer_timeout():
	_current_build_progress += 1
	_update_frame_state()
	if _current_build_progress >= MAX_BUILD_PROGRESS:
		_can_build = true
	else :
		$BuildProgressTimer.start(_build_progress_time)

func is_build_done()->bool:
	return _can_build

func _update_frame_state():
	$Structure.frame += 1
	$BuildSprite.frame += 1
	pass


func _on_BuildTime_timeout():
	if _build_option == BUILD_OPTIONS.ROCKET:
		if $"/root/RLInterface".rl_mode:
			$"/root/RLInterface".record_rocket_launched()
		$"/root/Ai".set_end_time()
		get_tree().change_scene("res://levels/FinalScene.tscn")
		return

	var unit:Node2D = load(_build_map[_build_option][BUILD_PROPERTIES.PATH]).instance()
	$"/root/Ai".get_friendlies().add_child(unit)
	unit.global_position = $Spawn.global_position
	_can_build = true
	$AnimationPlayer.stop()

func deposit(wood:int, stone:int)->void :
	_wood += wood
	_stone += stone

func show_interact_panel():
	$InteractPanel.visible = true

func hide_interact_panel():
	$InteractPanel.visible = false

func _on_FactoryArea_body_entered(body):
	if not body.name == "Player":
		return

	show_interact_panel()
	body.entered_factory(self)

func _on_FactoryArea_body_exited(body):
	if not body.name == "Player":
		return
	hide_interact_panel()
	body.left_factory()

func get_wood()->int:
	return _wood

func take_wood(wood:int):
	_wood -= wood

func get_stone()->int:
	return _stone

func take_stone(stone:int):
	_stone -= stone

func get_current_build()->int:
	return _build_option

func set_current_build(choice:int):
	_build_option = choice

func take_damage(damage:int):
	_health -= damage
	if _health <= 0:
		_die()

func _die():
	var flames_instance: = preload("res://objects/Flames.tscn").instance()
	get_parent().get_parent().add_child(flames_instance)
	flames_instance.global_position = global_position
	_drop_resources()
	if $"/root/RLInterface".rl_mode:
		$"/root/RLInterface".record_factory_destroyed()
	$"/root/Ai".factory_died()
	queue_free()

func _get_random_point_range(radius:int)->Vector2:
	return Vector2(rand_range( - radius, radius), rand_range( - radius, radius))

func _drop_resources():
	for _i in range(_wood):
		var resource: = preload("res://objects/Tree_Resource.tscn").instance()
		$"/root/Ai".get_world().call_deferred("add_child", resource)
		resource.global_position = global_position + _get_random_point_range(16)
	for _i in range(_stone):
		var resource: = preload("res://objects/Stone_Resource.tscn").instance()
		$"/root/Ai".get_world().call_deferred("add_child", resource)
		resource.global_position = global_position + _get_random_point_range(16)
