extends SceneTree
## Run at different --fixed-fps values to exercise multiple/no physics ticks per frame.

class ClockProbe extends Node:
	var clock: FocusController
	var real_seconds: float = 0.0
	var ticks: int = 0
	var max_tick_error: float = 0.0
	func _physics_process(delta: float) -> void:
		var real_delta := clock.real_delta(delta)
		max_tick_error = maxf(max_tick_error, absf(real_delta - 1.0 / Engine.physics_ticks_per_second))
		real_seconds += real_delta
		ticks += 1

var failures: int = 0
var checks: int = 0

func _initialize() -> void:
	create_timer(20.0, true, false, true).timeout.connect(func(): quit(1))
	run.call_deferred()

func check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(description)
	else:
		print("PASS: ", description)

func run() -> void:
	var arena: Node3D = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	var player: RainPlayer = arena.get_node("Player")
	var probe := ClockProbe.new()
	probe.clock = player.focus
	probe.process_physics_priority = 1000
	arena.add_child(probe)
	for i in 6:
		player.focus.toggle()
		var start := probe.real_seconds
		while probe.real_seconds - start < 0.27:
			await process_frame
	check(probe.max_tick_error < 0.00001, "real-time physics delta remains correct across render/physics frame boundaries")
	check(absf(probe.real_seconds - float(probe.ticks) / Engine.physics_ticks_per_second) < 0.0001, "rapid transitions never double-scale the clock")
	player.focus.set_active(true)
	var start := probe.real_seconds
	while probe.real_seconds - start < 0.3:
		await process_frame
	player.inventory.add_item(ItemInstance.new(load("res://resources/weapons/pistol.tres")))
	start = probe.real_seconds
	while probe.real_seconds - start < 0.2:
		await process_frame
	player.equipped.animate_action(&"reload", 0.5)
	start = probe.real_seconds
	while player.equipped.remaining > 0.0:
		await process_frame
	check(absf(probe.real_seconds - start - 0.625) < 0.06, "Focus animation lasts approximately 0.625 real seconds at this render rate")
	arena.queue_free()
	await process_frame
	print("FRAME CLOCK RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
