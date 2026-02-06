extends KinematicBody2D
class_name Player

var _input_vector:Vector2
export  var _speed:float = 60
export  var _attack_speed:float = 1.0

var _can_shoot:bool = true
var _moving:bool = false
var _mining_tool_enable:bool = false
var _is_mining:bool = false
var _resource_mining = null
var _dead: = false

export  var _mining_speed:float = 0.5
export  var _health:int = 5
export  var _wood: = 0
export  var _stone: = 0
export  var _crystal: = 0
export  var _damage: = 1

var _nearby_factory:Factory = null


onready var _animation_player:AnimationPlayer = $AnimationPlayer
onready var _attack_timer:Timer = $AttackTimer
onready var _current_interact_texture:TextureRect = $"%CurrentInteractTexture"
onready var _wood_label:Label = $"%WoodLabel"
onready var _stone_label:Label = $"%StoneLabel"
onready var _health_label:Label = $"%HealthLabel"
onready var _crystal_label:Label = $"%CrystalLabel"

var _mining_texture:Texture = preload("res://sprites/ToggleSprite1.png")
var _attack_texture:Texture = preload("res://sprites/ToggleSprite2.png")

func _ready():
	take_damage(0)
	add_wood(0)
	add_stone(0)

func _process(_delta):
	if _dead:
		return 
	
	_handle_movement_input()
	_handle_interactions()
	
	if _nearby_factory and is_instance_valid(_nearby_factory):
		_update_factory_info()

func _handle_movement_input():
	_input_vector = Vector2.ZERO
	if Input.is_action_pressed("move_up"):
		_input_vector.y -= 1
	if Input.is_action_pressed("move_left"):
		_input_vector.x -= 1
	if Input.is_action_pressed("move_down"):
		_input_vector.y += 1
	if Input.is_action_pressed("move_right"):
		_input_vector.x += 1
	
	if _input_vector != Vector2.ZERO:
		_moving = true
		_animation_player.play("Move")
	else :
		_moving = false
		if _animation_player.current_animation == "Move":
			_animation_player.stop(true)

func _handle_interactions():
	if Input.is_action_just_released("interact"):
		if _nearby_factory:
			$CanvasLayer / FactoryMenu.visible = not $CanvasLayer / FactoryMenu.visible
	
	if Input.is_action_just_released("zoom_in"):
		if $Camera2D.zoom.x > 0.6:
			return 
		$Camera2D.zoom = Vector2($Camera2D.zoom.x + 0.1, $Camera2D.zoom.y + 0.1)
		
	if Input.is_action_just_released("zoom_out"):
		if $Camera2D.zoom.x < 0.3:
			return 
		$Camera2D.zoom = Vector2($Camera2D.zoom.x - 0.1, $Camera2D.zoom.y - 0.1)
	
	if $CanvasLayer / FactoryMenu.visible:
		return 
	
	if Input.is_action_just_released("help_button"):
		$CanvasLayer / HelpMenu.visible = not $CanvasLayer / HelpMenu.visible
	
	if Input.is_action_just_released("toggle_mining"):
		_mining_tool_enable = not _mining_tool_enable
		if _mining_tool_enable:
			_current_interact_texture.texture = _mining_texture
		else :
			_current_interact_texture.texture = _attack_texture
			$Laser.set_is_casting(false)
			_is_mining = false
	
	if Input.is_action_pressed("shoot"):
		if _mining_tool_enable:
			if not _is_mining:
				$MiningAudioPlayer.play()
				_is_mining = true
			$Laser.set_is_casting(true)
			_handle_mining()
		else :
			$Laser.set_is_casting(false)
			_handle_shoot()
	else :
		if _is_mining:
			$MiningAudioPlayer.stop()
			_is_mining = false
		$Laser.set_is_casting(false)
		if _resource_mining and is_instance_valid(_resource_mining):
			_resource_mining.stop_mine()

func _handle_mining():
	$Laser.rotation_degrees = rad2deg((get_global_mouse_position() - global_position).angle())
	if $Laser.is_colliding():
		if not $Laser.get_collider():
			return 

		var resource = $Laser.get_collider().get_parent()
		if resource is Resource_Rock or resource is Resource_Tree:
			if _resource_mining != resource:
				if _resource_mining:
					if is_instance_valid(_resource_mining):
						_resource_mining.stop_mine()
				_resource_mining = resource
				_resource_mining.start_mine(_mining_speed)
		else :
			if _resource_mining:
				if is_instance_valid(_resource_mining):
					_resource_mining.stop_mine()
				_resource_mining = null
	else :
		if _resource_mining:
			if is_instance_valid(_resource_mining):
				_resource_mining.stop_mine()
			_resource_mining = null

func _handle_shoot():
	if not _can_shoot:
		return 
	
	
	var bullet:Bullet = preload("res://objects/Bullet.tscn").instance()
	bullet.set_friendly(true)
	bullet.set_shoot_direction(_get_aim_direction().normalized())
	$"/root/Ai".get_world().add_child(bullet)
	bullet.global_position = global_position
	bullet.set_damage(_damage + int($"/root/Ai".get_modifier($"/root/Ai".Modifiers.PLAYER_DAMAGE)))
	_can_shoot = false
	$ShootAudioPlayer.play()
	
	_attack_timer.start(_attack_speed - (_attack_speed * $"/root/Ai".get_modifier($"/root/Ai".Modifiers.PLAYER_ATTACK_SPEED)))

func _get_aim_direction()->Vector2:
	return get_global_mouse_position() - global_position

func _physics_process(_delta):
	move_and_slide(_input_vector.normalized() * (_speed * $"/root/Ai".get_modifier($"/root/Ai".Modifiers.PLAYER_MOVE_SPEED) + _speed))

func _on_AttackTimer_timeout():
	_can_shoot = true

func add_wood(amount:int):
	_wood += amount
	_wood_label.text = str(_wood)

func add_stone(amount:int):
	_stone += amount
	_stone_label.text = str(_stone)
	
func add_crystal(amount:int):
	_crystal += amount
	_crystal_label.text = str(_crystal)

func take_damage(damage:int):
	_health -= damage
	_health_label.text = str(_health)
	
	_animation_player.play("Hit")
	
	if _health <= 0 and not _dead:
		_dead = true
		$"/root/Ai".get_level().show_gameover()

func entered_factory(factory:Factory):
	_nearby_factory = factory
	_update_factory_info()

func _update_factory_info():
	_update_upgrade_info()
	add_stone(0)
	add_wood(0)
	$"%FactoryWood".text = str(_nearby_factory.get_wood())
	$"%FactoryStone".text = str(_nearby_factory.get_stone())
	$"%BuildBotButton".disabled = false
	$"%BuildBotButton".text = "select"
	$"%AggressorBotButton".disabled = false
	$"%AggressorBotButton".text = "select"
	$"%RocketButton".text = "select"
	
	if _crystal >= 5:
		$"%RocketButton".disabled = false
	
	match _nearby_factory.get_current_build():
		0:
			$"%BuildBotButton".disabled = true
			$"%BuildBotButton".text = "selected"
		1:
			$"%AggressorBotButton".disabled = true
			$"%AggressorBotButton".text = "selected"
		2:
			$"%RocketButton".disabled = false
			$"%RocketButton".text = "selected"

func _update_upgrade_info():
	var total_wood = _wood + _nearby_factory.get_wood()
	var total_stone = _stone + _nearby_factory.get_stone()
	
	if total_wood >= 3 and total_stone >= 3:
		$"%PlayerAttackSpeedButton".disabled = false
		$"%PlayerMoveSpeedButton".disabled = false
		$"%PlayerDamageButton".disabled = false
		$"%BotAttackSpeedButton".disabled = false
		$"%BotMoveSpeedButton".disabled = false
	else :
		$"%PlayerAttackSpeedButton".disabled = true
		$"%PlayerMoveSpeedButton".disabled = true
		$"%PlayerDamageButton".disabled = true
		$"%BotAttackSpeedButton".disabled = true
		$"%BotMoveSpeedButton".disabled = true
	
	var prefix: = "Upgrade (+"
	$"%PlayerAttackSpeedButton".text = prefix + str(int($"/root/Ai".get_modifier($"/root/Ai".Modifiers.PLAYER_ATTACK_SPEED) * 100)) + "%)"
	$"%PlayerMoveSpeedButton".text = prefix + str(int($"/root/Ai".get_modifier($"/root/Ai".Modifiers.PLAYER_MOVE_SPEED) * 100)) + "%)"
	$"%PlayerDamageButton".text = prefix + str($"/root/Ai".get_modifier($"/root/Ai".Modifiers.PLAYER_DAMAGE)) + ")"
	$"%BotAttackSpeedButton".text = prefix + str(int($"/root/Ai".get_modifier($"/root/Ai".Modifiers.BOT_ATTACK_SPEED) * 100)) + "%)"
	$"%BotMoveSpeedButton".text = prefix + str(int($"/root/Ai".get_modifier($"/root/Ai".Modifiers.BOT_MOVE_SPEED) * 100)) + "%)"


func left_factory():
	_nearby_factory = null
	$CanvasLayer / FactoryMenu.visible = false

func _on_DepositButton_pressed():
	_nearby_factory.deposit(_wood, _stone)
	_wood = 0
	_stone = 0
	add_wood(0)
	add_stone(0)
	_update_factory_info()

func _on_BuildBotButton_pressed():
	_nearby_factory.set_current_build(0)
	_update_factory_info()

func _on_AggressorBotButton_pressed():
	_nearby_factory.set_current_build(1)
	_update_factory_info()

func _on_RocketButton_pressed():
	if _crystal >= 5:
		_nearby_factory.set_current_build(2)
		_update_factory_info()


func _on_BotMoveSpeedButton_pressed():
	if _wood < 3:
		var diff = 3 - _wood
		_wood = 0
		_nearby_factory.take_wood(diff)
	else :
		_wood -= 3
	
	if _stone < 3:
		var diff = 3 - _stone
		_stone = 0
		_nearby_factory.take_stone(diff)
	else :
		_stone -= 3
	
	$"/root/Ai".set_modifier($"/root/Ai".Modifiers.BOT_MOVE_SPEED, $"/root/Ai".get_modifier($"/root/Ai".Modifiers.BOT_MOVE_SPEED) + 0.1)
	_update_factory_info()

func _on_BotAttackSpeedButton_pressed():
	if _wood < 3:
		var diff = 3 - _wood
		_wood = 0
		_nearby_factory.take_wood(diff)
	else :
		_wood -= 3
	
	if _stone < 3:
		var diff = 3 - _stone
		_stone = 0
		_nearby_factory.take_stone(diff)
	else :
		_stone -= 3
		
	$"/root/Ai".set_modifier($"/root/Ai".Modifiers.BOT_ATTACK_SPEED, $"/root/Ai".get_modifier($"/root/Ai".Modifiers.BOT_ATTACK_SPEED) + 0.1)
	_update_factory_info()

func _on_PlayerDamageButton_pressed():
	if _wood < 3:
		var diff = 3 - _wood
		_wood = 0
		_nearby_factory.take_wood(diff)
	else :
		_wood -= 3
	
	if _stone < 3:
		var diff = 3 - _stone
		_stone = 0
		_nearby_factory.take_stone(diff)
	else :
		_stone -= 3
		
	$"/root/Ai".set_modifier($"/root/Ai".Modifiers.PLAYER_DAMAGE, $"/root/Ai".get_modifier($"/root/Ai".Modifiers.PLAYER_DAMAGE) + 1.0)
	_update_factory_info()

func _on_PlayerMoveSpeedButton_pressed():
	if _wood < 3:
		var diff = 3 - _wood
		_wood = 0
		_nearby_factory.take_wood(diff)
	else :
		_wood -= 3
	
	if _stone < 3:
		var diff = 3 - _stone
		_stone = 0
		_nearby_factory.take_stone(diff)
	else :
		_stone -= 3
		
	$"/root/Ai".set_modifier($"/root/Ai".Modifiers.PLAYER_MOVE_SPEED, $"/root/Ai".get_modifier($"/root/Ai".Modifiers.PLAYER_MOVE_SPEED) + 0.1)
	_update_factory_info()

func _on_PlayerAttackSpeedButton_pressed():
	if _wood < 3:
		var diff = 3 - _wood
		_wood = 0
		_nearby_factory.take_wood(diff)
	else :
		_wood -= 3
	
	if _stone < 3:
		var diff = 3 - _stone
		_stone = 0
		_nearby_factory.take_stone(diff)
	else :
		_stone -= 3
		
	$"/root/Ai".set_modifier($"/root/Ai".Modifiers.PLAYER_ATTACK_SPEED, $"/root/Ai".get_modifier($"/root/Ai".Modifiers.PLAYER_ATTACK_SPEED) + 0.1)
	_update_factory_info()
