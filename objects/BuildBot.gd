extends RigidBody2D
class_name BuildBot

const _FRIEND_BASE_EYE_COLOR:Color = Color(0.25098, 0.615686, 0.698039)
const _FRIEND_EYE_COLOR:Color = Color(0, 0.3, 1)
const _ENEMY_BASE_EYE_COLOR:Color = Color(0.698039, 0.25098, 0.282414)
const _ENEMY_EYE_COLOR:Color = Color(1, 0, 0.070313)

var _base_eye_color:Color = _FRIEND_BASE_EYE_COLOR
var _eye_color:Color = _FRIEND_EYE_COLOR
var _friend:bool = true


var _speed:float = 100

export  var _stone:int = 0
export  var _wood:int = 0
export  var _mining_speed:float = 0.7
export  var _health:int = 5

var _timeout_time: = 8.0
var _doing_goal:bool = false

enum GOALS{
	BUILD, 
	COLLECT, 
	RETURN, 
	HUNT, 
	UNSTUCK
}
var _current_goal:int = 0

func _ready():
	_set_texture_colors()
	_determine_goal()

func add_wood(amount:int):
	_wood += amount
	_update_resources()

func add_stone(amount:int):
	_stone += amount
	_update_resources()

func _update_resources():
	$ResourceBar / Panel / HBoxContainer / WoodCount / WoodLabel.text = str(_wood)
	$ResourceBar / Panel / HBoxContainer / StoneCount / StoneLabel.text = str(_stone)

func set_friend(friend:bool):
	if friend:
		_base_eye_color = _FRIEND_BASE_EYE_COLOR
		_eye_color = _FRIEND_EYE_COLOR
	else :
		_base_eye_color = _ENEMY_BASE_EYE_COLOR
		_eye_color = _ENEMY_EYE_COLOR
	
	_friend = friend

func _set_texture_colors():
	$Sprites / BaseEye.modulate = _base_eye_color
	$Sprites / Eye.modulate = _eye_color

func _determine_goal():
	var ai = $"/root/Ai"
	var ai_state:int = ai.get_ai_encouragement()
	match ai_state:
		ai.AI_LEVELS.SAFE:
			if ai.get_if_can_build(_wood, _stone):
				_current_goal = GOALS.BUILD
			else :
				_current_goal = GOALS.COLLECT
		ai.AI_LEVELS.COLLECT:
			if _wood > 5 or _stone > 5:
				_current_goal = GOALS.RETURN
			else :
				_current_goal = GOALS.COLLECT

func _process_goals():
	match _current_goal:
		- 1:
			_determine_goal()
		GOALS.BUILD:
			_goal_build()
		GOALS.COLLECT:
			_goal_collect()
		GOALS.RETURN:
			_goal_return_goods()
		GOALS.UNSTUCK:
			_goal_unstuck()

func _process(_delta):
	_process_goals()
	_sprite_direction()
	pass

func _sprite_direction():
	if linear_velocity.x < 0:
		$Sprites / Base.flip_h = true
		$Sprites / Flame.flip_h = true
		$Sprites / BaseEye.flip_h = true
		$Sprites / Eye.flip_h = true
	else :
		$Sprites / Base.flip_h = false
		$Sprites / Flame.flip_h = false
		$Sprites / BaseEye.flip_h = false
		$Sprites / Eye.flip_h = false

func _physics_process(_delta):
	pass

func _find_safe_factory_spot()->Vector2:
	var build_pos:Vector2 = Vector2.ZERO
	var done:bool = false
	var factory_area:Area2D = $Factory_Spawn_Check
	
	while not done:
		var x:float = rand_range(global_position.x - _build_distance, global_position.x + _build_distance)
		var y:float = rand_range(global_position.y - _build_distance, global_position.y + _build_distance)
		factory_area.global_position = Vector2(x, y)
		
		
		var space_state:Physics2DDirectSpaceState = get_world_2d().direct_space_state
		var physics_query:Physics2DShapeQueryParameters = Physics2DShapeQueryParameters.new()
		physics_query.set_shape($Factory_Spawn_Check / CollisionShape2D.shape)
		physics_query.transform = $Factory_Spawn_Check.transform
		physics_query.collision_layer = 4
		var results = space_state.intersect_shape(physics_query)
		
		if len(results) <= 0:
			done = true
			build_pos = factory_area.global_position
			$AudioStreamPlayer2D.play()
	
	
	return build_pos





func _move_to_goal():
	_goal_moving = true
	linear_velocity = (_speed + (_speed * $"/root/Ai".get_modifier($"/root/Ai".Modifiers.BOT_MOVE_SPEED))) * (_goal_target - global_position).normalized()
	$TimeoutTimer.start(_timeout_time)

func _stop_moving_to_goal():
	_goal_moving = false
	linear_velocity = Vector2.ZERO

func take_damage(damage:int):
	_health -= damage
	if _health <= 0:
		var flames_instance: = preload("res://objects/Flames.tscn").instance()
		get_parent().add_child(flames_instance)
		flames_instance.global_position = global_position
		_drop_resources()
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


var _goal_target:Vector2 = Vector2.ZERO
var _goal_moving:bool = false



var _goal_resource:Node2D = null
var _goal_mining:bool
var _gather_range:float = 100

func _goal_collect():
	if _goal_resource:
		if is_instance_valid(_goal_resource):
			
			if global_position.distance_to(_goal_resource.global_position) < _build_range:
				if not _goal_mining:
					$TimeoutTimer.stop()
					
					_goal_mining = true
					_goal_moving = false
					_goal_resource.start_mine(_mining_speed)
					linear_velocity = Vector2.ZERO
					$Line2D.points[1] = _goal_resource.global_position - global_position
			else :
				_goal_mining = false
				
				if _goal_moving:
					return 
				
				linear_velocity = (_goal_resource.global_position - global_position).normalized() * (_speed + (_speed * $"/root/Ai".get_modifier($"/root/Ai".Modifiers.BOT_MOVE_SPEED)))
				_goal_moving = true
		else :
			
			$Line2D.points[1] = Vector2.ZERO
			_goal_resource = null
			_current_goal = - 1
			_goal_mining = false
	else :
		$Line2D.points[1] = Vector2.ZERO
		
		var space_state:Physics2DDirectSpaceState = get_world_2d().direct_space_state
		var physics_query:Physics2DShapeQueryParameters = Physics2DShapeQueryParameters.new()
		physics_query.set_shape($ResourceFinder / CollisionShape2D.shape)
		physics_query.transform = self.transform
		physics_query.collision_layer = 4
		physics_query.collide_with_areas = false
		physics_query.collide_with_bodies = true
		var results: = space_state.intersect_shape(physics_query)
		
		if len(results) > 0:
			_goal_resource = results[0]["collider"].get_parent()
			$TimeoutTimer.start(_timeout_time)
			$AudioStreamPlayer2D.play()
		else :
			_current_goal = GOALS.UNSTUCK
	pass


var _unstuck_goal: = Vector2.ZERO
var _unstuck_moving:bool = false

func _goal_unstuck():
	if _unstuck_moving:
		if global_position.distance_to(_unstuck_goal) < 32:
			linear_velocity = Vector2.ZERO
			_unstuck_goal = Vector2.ZERO
			_unstuck_moving = false
			_current_goal = - 1
	else :
		_unstuck_goal = _get_random_map_point()
		linear_velocity = (_unstuck_goal - global_position).normalized() * (_speed + (_speed * $"/root/Ai".get_modifier($"/root/Ai".Modifiers.BOT_MOVE_SPEED)))
		_unstuck_moving = true

func _get_random_map_point():
	return Vector2(rand_range( - 250, 250), rand_range( - 250, 250))

var _factory_target = null
var _factory_distance:float = 32

func _goal_return_goods():
	if _factory_target:
		
		if global_position.distance_to(_factory_target.global_position) <= _factory_distance:
			_factory_target.deposit(_wood, _stone)
			_wood = 0
			_stone = 0
			_update_resources()
			_factory_target = null
			_current_goal = - 1
			linear_velocity = Vector2.ZERO
	else :
		var factories:Node2D = $"/root/Ai".get_factories()
		var random_factory_index:int = randi() % factories.get_child_count()
		_factory_target = factories.get_child(random_factory_index)
		linear_velocity = (_factory_target.global_position - global_position).normalized() * (_speed + (_speed * $"/root/Ai".get_modifier($"/root/Ai".Modifiers.BOT_MOVE_SPEED)))



var _is_building:bool = false
var _build_distance:int = 100
var _build_range:float = 50
var _building = null

func _goal_build():
	if not _is_building:
		if not _goal_moving:
			
			_goal_target = _find_safe_factory_spot()
			_move_to_goal()
		else :
			
			if global_position.distance_to(_goal_target) <= _build_range:
				$TimeoutTimer.stop()
				_is_building = true
				_stop_moving_to_goal()
				var factory:Factory = preload("res://objects/Factory.tscn").instance()
				_building = factory
				$"/root/Ai".get_factories().add_child(factory)
				factory.global_position = _goal_target
				
				_wood -= $"/root/Ai".FACTORY_WOOD_COST
				_stone -= $"/root/Ai".FACTORY_STONE_COST
				_update_resources()
	else :
		if _building.is_build_done():
			_goal_target = Vector2.ZERO
			$Line2D.points[1] = Vector2.ZERO
			_is_building = false
			_current_goal = - 1
		else :
			$Line2D.points[1] = _building.global_position - global_position


func _on_TimeoutTimer_timeout():
	_current_goal = GOALS.UNSTUCK
	_goal_resource = null
	_goal_moving = false
