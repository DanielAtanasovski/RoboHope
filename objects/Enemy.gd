extends RigidBody2D

export  var _speed:float = 40
export  var _knock_back_multiplier:float = 2.0
export  var _health:float = 2
export  var _damage:int = 1
export  var _movement_update_speed:float = 0.5

var _factory_target = null
var _nearest_target:Node2D = null

func _ready():
	connect("body_entered", self, "_on_body_entered")
	$Area2D.connect("body_entered", self, "_on_Area2D_body_entered")
	$MoveTimer.connect("timeout", self, "_on_MoveTimer_timeout")
	$MoveTimer.start(_movement_update_speed)

func _get_factory_target():
	var factories = $"/root/Ai".get_factories()
	if factories.get_child_count() > 0:
		return factories.get_child(randi() % factories.get_child_count())
	return null

func _on_body_entered(body:Node):
	if "Enemy" in body.name or "Nest" in body.name or "Border" in body.name:
		return 
	
	print(body.name)
	if body is Bullet:
		var bullet:Bullet = body
		_health -= bullet.get_damage()
		_check_dead()
		bullet.queue_free()
	else :
		
		if "Player" in body.name or "Bot" in body.name:
			body.take_damage(_damage)
		else :
#			var name = body.get_parent().name
			body.get_parent().take_damage(_damage)
	var direction:Vector2 = - (body.global_position - global_position).normalized()
	linear_velocity = direction * _speed * _knock_back_multiplier
	$AnimationPlayer.play("Hit")
	$AudioStreamPlayer2D.play()

func take_damage(damage:int):
	_health -= damage
	_check_dead()

func _check_dead():
	if _health <= 0:
		queue_free()

func _on_MoveTimer_timeout():
	if _nearest_target and is_instance_valid(_nearest_target):
		linear_velocity = (_nearest_target.global_position - global_position).normalized() * _speed
	elif _factory_target and is_instance_valid(_factory_target):
		linear_velocity = (_factory_target.global_position - global_position).normalized() * _speed
	else :
		_nearest_target = null
		_factory_target = _get_factory_target()

func _on_Area2D_body_entered(body):
	_nearest_target = body
