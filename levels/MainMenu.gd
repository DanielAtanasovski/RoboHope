extends Control

var playing:int = - 1
onready var animation_player:AnimationPlayer = $VBoxContainer / Cutscene / Scene1 / AnimationPlayer

var state:int = 0


func _ready():
	animation_player.play("BuildBot_Intro")


func _on_Play_pressed():
	if playing != - 1:
		return 
		
	playing = 0
	animation_player.play("Fade_away")

func _on_PlayImpossible_pressed():
	if playing != - 1:
		return 
	
	playing = 1
	animation_player.play("Fade_away")


func _on_AnimationPlayer_animation_finished(anim_name):
	if "Fade_away" in anim_name:
		animation_player.play("RocketCrash")
	elif "RocketCrash" in anim_name:
		
		if playing == 0:
			get_tree().change_scene("res://levels/Level1.tscn")
		else :
			get_tree().change_scene("res://levels/Level2.tscn")
