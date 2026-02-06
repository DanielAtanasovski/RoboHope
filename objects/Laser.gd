extends RayCast2D

var is_casting: = false setget set_is_casting



func _ready():
	set_physics_process(false)
	$Line2D.points[1] = Vector2.ZERO

func _physics_process(_delta):
	var cast_point: = cast_to
	force_raycast_update()
	
	if is_colliding():
		cast_point = to_local(get_collision_point())
	
	$Line2D.points[1] = cast_point

func set_is_casting(cast:bool)->void :
	if is_casting == cast:
		return 
	
	is_casting = cast
	
	if is_casting:
		_appear()
	else :
		_disappear()
		$Line2D.points[1] = Vector2.ZERO
		
	set_physics_process(is_casting)

func _appear()->void :
	$Tween.stop_all()
	$Tween.interpolate_property($Line2D, "width", 0, 4.0, 0.2)
	$Tween.start()
	
func _disappear()->void :
	$Tween.stop_all()
	$Tween.interpolate_property($Line2D, "width", 4.0, 0, 0.1)
	$Tween.start()
