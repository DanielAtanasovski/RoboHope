extends Control



func _ready():
	$"%WinTimeLabel".text = "It took you " + str($"/root/Ai".get_end_time()) + " seconds to escape!"
	$VBoxContainer / Cutscene / Scene1 / AnimationPlayer.play("FinalScene")

func _on_Play_pressed():
	get_tree().change_scene("res://levels/MainMenu.tscn")


func _on_AnimationPlayer_animation_finished(anim_name):
	if anim_name == "FinalScene":
		$VBoxContainer / Cutscene / Scene1 / AnimationPlayer.play("Loop")
