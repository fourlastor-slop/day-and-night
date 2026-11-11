extends Node
## Renders the boot splash from the game itself: the Brook at the start of the road, Marta's day over
## Giulio's night, with the title card over the join. Run it with tools/gen_splash.sh.

const OUT := "res://assets/gfx/splash.png"
const SAVE := "user://splash_progress.cfg"


func _ready() -> void:
	TranslationServer.set_locale("en")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	var game: Main = load("res://scenes/main.tscn").instantiate()
	game.manual = true
	game.save_path = SAVE
	add_child(game)
	TranslationServer.set_locale("en")
	game.go_to(0)
	game.sim.marta.facing = 1
	game.sim.giulio.facing = -1
	game.show_hud(false)
	game.refresh()
	# Nothing to act on yet, so no target and no keys.
	game.stage.target.visible = false
	for cues: Stage.Cues in [game.stage.marta_cues, game.stage.giulio_cues]:
		for cue: Sprite2D in [cues.drive, cues.bell, cues.interact, cues.use, cues.alt]:
			cue.visible = false
	game.menu.open("splash")
	for i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.resize(1280, 720, Image.INTERPOLATE_LANCZOS)
	img.save_png(OUT)
	print("wrote ", OUT)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	get_tree().quit()
