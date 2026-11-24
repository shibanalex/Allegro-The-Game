@tool
extends SceneTree

func _init() -> void:
	var root := Control.new()
	root.name = "IntroCutscene"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	root.set_script(load("res://scripts/intro_cutscene.gd"))

	var packed := PackedScene.new()
	var perr := packed.pack(root)
	var serr := ResourceSaver.save(packed, "res://intro_cutscene.tscn")
	print("Packed intro_cutscene.tscn pack_err=", perr, " save_err=", serr)
	root.free()
	quit()
