extends RigidBody2D

var _target_factory = null
var _target_attack:Node2D = null
var _target_patrol:Vector2 = Vector2.ZERO

var _update_time: = 1.5
var _attacking: = false
var _can_attack: = true
var _moving_to_patrol: = false

export  var _speed: = 120
export  var _health: = 5
export  var _damage: = 2
export  var _attack_speed: = 0.8
export  var _attack_range: = 80

func _ready():
	$UpdateTimer.start(_update_time)

func set_factory(factory):
	_target_factory = factory

func _get_patrol_point()->Vector2:
	if not _target_factory or not is_instance_valid(_target_factory):
		var factories = $"/root/Ai".get_factories()
		if factories.get_child_count() > 0:
			_target_factory = factories.get_child(randi() % factories.get_child_count())
			$AudioStreamPlayer2D.play()
		else :
			return Vector2.ZERO
	
	var rand_vector = Vector2(rand_range( - _attack_range, _attack_range), rand_range( - _attack_range, _attack_range))
	return rand_vector + _target_factory.global_position


func _physics_process(_delta):
	if _attacking:
		_attack_state()
	elif _moving_to_patrol:
		_patrol_state()


func _attack_state():
	if _target_attack and is_instance_valid(_target_attack):
		if global_position.distance_to(_target_attack.global_position) < _attack_range:
			if _can_attack:
				_target_attack.take_damage(_damage)
				_can_attack = false
				$AttackTimer.start(_attack_speed - (_attack_speed * $"/root/Ai".get_modifier($"/root/Ai".Modifiers.BOT_ATTACK_SPEED)))
			$Line2D.points[1] = _target_attack.global_position - global_position
			linear_velocity = Vector2.ZERO
		else :
			$Line2D.points[1] = Vector2.ZERO
			linear_velocity = (_target_attack.global_position - global_position).normalized() * (_speed + (_speed * $"/root/Ai".get_modifier($"/root/Ai".Modifiers.BOT_MOVE_SPEED)))
	else :
		_reset()

func _reset():
	$Line2D.points[1] = Vector2.ZERO
	_attacking = false
	_target_attack = null
	linear_velocity = Vector2.ZERO
	_calculate_move()

func _patrol_state():
	if global_position.distance_to(_target_patrol) <= 16 and _moving_to_patrol:
		_moving_to_patrol = false
		linear_velocity = Vector2.ZERO
		
		$UpdateTimer.start(_update_time)

func _is_nearby_enemies()->bool:
	var nearby_enemies = $Area2D.get_overlapping_bodies()
	if nearby_enemies.size() > 0:
		for enemy in nearby_enemies:
			if is_instance_valid(enemy):
				_target_attack = enemy
				_attacking = true
				return true
		
	return false

func _calculate_move():
	if _attacking:
		return 
	
	if _is_nearby_enemies():
		return 
	
	if _target_factory and is_instance_valid(_target_factory):
		if _moving_to_patrol:
			return 
		else :
			_target_patrol = _get_patrol_point()
			linear_velocity = (_target_patrol - global_position).normalized() * (_speed + (_speed * $"/root/Ai".get_modifier($"/root/Ai".Modifiers.BOT_MOVE_SPEED)))
			_moving_to_patrol = true
	else :
		_target_factory = null
		_target_patrol = _get_patrol_point()
		linear_velocity = (_target_patrol - global_position).normalized() * (_speed + (_speed * $"/root/Ai".get_modifier($"/root/Ai".Modifiers.BOT_MOVE_SPEED)))
		_moving_to_patrol = true
	
func take_damage(damage:int):
	_health -= damage
	if _health <= 0:
		var flames_instance: = preload("res://objects/Flames.tscn").instance()
		get_parent().add_child(flames_instance)
		flames_instance.global_position = global_position
		queue_free()

func _on_UpdateTimer_timeout():
	_calculate_move()

func _on_Area2D_body_entered(body):
	_attacking = true
	_target_attack = body

func _on_AttackTimer_timeout():
	_can_attack = true
