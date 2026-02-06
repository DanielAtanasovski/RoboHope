extends RigidBody2D
class_name Bullet

var _friend:bool = false
var _direction:Vector2 = Vector2.ZERO
export  var _speed:float = 50
export  var _death_time:float = 2
export  var _damage:int = 1

onready var _death_timer:Timer = $Timer


onready var _animated_sprite:AnimatedSprite = $AnimatedSprite

func set_friendly(_friendly:bool):
	if _friendly:
		_friend = true
		set_collision_mask_bit(4, true)
	else :
		_friend = false
		set_collision_mask_bit(0, true)

func set_shoot_direction(direction:Vector2):
	_direction = direction

func set_damage(damage:int):
	_damage = damage

func get_damage()->int:
	return _damage
	
func _ready():
	linear_velocity = _speed * _direction
	rotation_degrees = rad2deg(_direction.angle()) + 90
	_death_timer.start(_death_time)
	
	if _friend:
		_animated_sprite.frame = 0
	else :
		_animated_sprite.frame = 1

func set_death_time(death_time:float):
	_death_time = death_time
	
func set_speed(speed:float):
	_speed = speed

func _on_Timer_timeout():
	queue_free()

func _on_Bullet_body_entered(body):
	if "Nest" in body.name:
		body.get_parent().take_damage(_damage)
		queue_free()
	elif "Enemy" in body.name:
		print(body.name)
