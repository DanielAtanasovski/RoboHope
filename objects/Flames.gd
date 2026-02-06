extends Node2D

func _on_DeathTimer_timeout():
	queue_free()
