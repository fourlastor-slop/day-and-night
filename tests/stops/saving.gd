extends Case
## A stop saved halfway through and loaded back plays on exactly as if it had never stopped, on every
## stop, after going through the same text the save file holds.


func run() -> void:
	for stop: Dictionary in Stops.ROAD:
		a_saved_stop_plays_on_exactly(stop)


func a_saved_stop_plays_on_exactly(stop: Dictionary) -> void:
	fresh(stop)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 2400:
		bot.mash(sim.marta, rng)
		bot.mash(sim.giulio, rng)
		sim.tick()
	var copy := Sim.new(stop)
	copy.restore(str_to_var(var_to_str(sim.to_save())))
	check(var_to_str(copy.to_save()) == var_to_str(sim.to_save()), "%s loads back as it was saved" % stop.name)
	same_pad(sim.marta.pad, copy.marta.pad)
	same_pad(sim.giulio.pad, copy.giulio.pad)
	var other := Bot.new(copy)
	var rng_copy := RandomNumberGenerator.new()
	rng_copy.seed = rng.seed
	rng_copy.state = rng.state
	for i in 1200:
		bot.mash(sim.marta, rng)
		bot.mash(sim.giulio, rng)
		sim.tick()
		other.mash(copy.marta, rng_copy)
		other.mash(copy.giulio, rng_copy)
		copy.tick()
	check(var_to_str(copy.to_save()) == var_to_str(sim.to_save()), "%s plays on exactly the same after loading" % stop.name)


## The buttons a kid is holding aren't saved, so the test hands them over to keep both games in step.
func same_pad(from: Pad, to: Pad) -> void:
	for field in ["x", "y", "jump", "jump_p", "use_p", "alt", "alt_p", "next_p", "interact_p", "dir_p"]:
		to.set(field, from.get(field))
