extends Node2D

export  var _min_world:Vector2 = Vector2( - 16, - 16)
export  var _max_world:Vector2 = Vector2(16, 16)

var _safe_zone:Rect2 = Rect2(Vector2( - 16 * 2, - 16 * 2), Vector2(16 * 4, 16 * 4))

export  var _min_trees:int = 50
export  var _min_rocks:int = 50


onready var _resources_node:Node2D = $Resources

var _time_start = 0
var _music_index = - 1
var _music:Array = [preload("res://music/Rolemusic - pl4y1ng.mp3"), preload("res://music/Rolemusic - Shipwreck In The Pacific Ocean.mp3"), preload("res://music/Rolemusic - She Is My Best Treasure.mp3")]


func _ready():
	$"/root/Ai".setup()
	_generate_trees()
	_generate_rocks()
	_time_start = OS.get_unix_time()
	

func _play_music():
	if $AudioStreamPlayer.playing:
		return 
	
	var old_music = _music_index
	_music_index = randi() % _music.size()
	
	while _music_index == old_music:
		_music_index = randi() % _music.size()
	
	$AudioStreamPlayer.stream = _music[_music_index]
	$AudioStreamPlayer.play()

func _process(_delta):
	_play_music()

func _get_safe_coord():
	var safe:bool = false
	var coord:Vector2 = Vector2.ZERO
	while not safe:
		coord.x = rand_range(_min_world.x, _max_world.x)
		coord.y = rand_range(_min_world.y, _max_world.y)
		
		if not _safe_zone.has_point(coord):
			safe = true
	return coord

func _generate_trees():
	for _i in range(_min_trees):
		var tree = preload("res://objects/Tree.tscn").instance()
		tree.global_position = _get_safe_coord()
		_resources_node.add_child(tree)

func _generate_rocks():
	for _i in range(_min_rocks):
		var tree = preload("res://objects/Rock.tscn").instance()
		tree.global_position = _get_safe_coord()
		_resources_node.add_child(tree)
	
func show_gameover():
	$CanvasLayer / GameOverMenu.visible = true
	var time_end = OS.get_unix_time() - _time_start
	$"%TimeLabel".text = "You lasted: " + str(time_end) + " seconds."

func _on_TryAgainButton_pressed():
	get_tree().change_scene(get_tree().current_scene.filename)

func get_time_start():
	return _time_start
