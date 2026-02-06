extends Node2D

var _collector:Node2D = null
var _speed:float = 100.0
var _set_collection:bool = false

export  var _only_player:bool = false

enum RESOURCE{
	WOOD, 
	CRYSTAL, 
	STONE
}
export (RESOURCE) var _resource:int = RESOURCE.WOOD

func _ready():
	$Area2D.connect("area_entered", self, "_on_Area2D_area_entered")

func _process(delta):
	if _collector and is_instance_valid(_collector):
		if global_position.distance_to(_collector.global_position) < 20:
			match _resource:
				RESOURCE.WOOD:
					_collector.add_wood(1)
				RESOURCE.STONE:
					_collector.add_stone(1)
				RESOURCE.CRYSTAL:
					_collector.add_crystal(1)
			_collector = null
			queue_free()
		else :
			global_position += (_collector.global_position - global_position).normalized() * delta * _speed


func _on_Area2D_area_entered(area):
	if _only_player:
		if not "Player" in area.get_parent().name:
			return 
	
	if not _set_collection:
		_collector = area.get_parent()
		_set_collection = true
