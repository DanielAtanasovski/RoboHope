extends Node

# RL Mode Flag - Set if started with --rl-mode
var rl_mode: bool = false

# Seed storage (preserved across scene reloads via autoload persistence)
var _pending_seed: int = -1

# Episode state
var _episode_done: bool = false
var _step_count: int = 0

# Step events (agent calculates reward from these)
var _events_this_step: Dictionary = {}

# RL Action Enum
enum RLAction {
	NOOP = 0,
	MOVE_UP = 1,
	MOVE_DOWN = 2,
	MOVE_LEFT = 3,
	MOVE_RIGHT = 4,
	MOVE_UP_LEFT = 5,
	MOVE_UP_RIGHT = 6,
	MOVE_DOWN_LEFT = 7,
	MOVE_DOWN_RIGHT = 8,
	SHOOT_NEAREST = 9,
	MINE_NEAREST = 10,
	INTERACT = 11,
}

# Constants for observation normalization
const MAP_SIZE = 512.0
const MAX_HP = 5
const MAX_RESOURCES = 20
const MAX_CRYSTALS = 5

func _ready():
	# Check if running in RL mode
	rl_mode = "--rl-mode" in OS.get_cmdline_args()

	# Disable audio in RL mode
	if rl_mode:
		AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), true)

	# If there's a pending seed, apply it now
	if _pending_seed >= 0:
		seed(_pending_seed)
		_pending_seed = -1
	else:
		randomize()

# ======= CORE RL API =======

## Reset the world to initial state (without reloading scene to keep servers alive)
func reset_world(rng_seed: int = -1) -> void:
	_episode_done = false
	_step_count = 0
	_reset_events()

	# Set random seed if provided
	if rng_seed >= 0:
		seed(rng_seed)

	# Reset player state
	var player = _get_player()
	if player:
		player.global_position = Vector2(256, 256)  # Center of map
		player._health = 5  # Reset to full health (max HP)
		player._wood = 0
		player._stone = 0
		player._crystal = 0
		player._can_shoot = true
		player._dead = false

	# Clear all enemies
	var ai = _get_ai()
	if ai:
		var enemies = ai.get_enemies()
		for enemy in enemies.get_children():
			enemy.queue_free()

	# Clear all projectiles and effects
	var level = get_tree().current_scene
	if level:
		var children_to_delete = []
		for node in level.get_children():
			# Find and queue projectiles/effects
			if node.name.begins_with("Bullet") or node.name.begins_with("Laser") or node.name.begins_with("Flames"):
				children_to_delete.append(node)
		for node in children_to_delete:
			node.queue_free()

	print("RL World reset (seed=%d)" % rng_seed)

## Get current observation as a flat float array
func get_observation_v0() -> Array:
	var obs = []
	var player = _get_player()

	if not player:
		# Return a zero observation if player doesn't exist
		return _get_zero_observation()

	# Player position (normalized to map)
	obs.append(player.global_position.x / MAP_SIZE)
	obs.append(player.global_position.y / MAP_SIZE)

	# Player health
	obs.append(float(player._health) / float(MAX_HP))

	# Player inventory
	obs.append(float(player._wood) / float(MAX_RESOURCES))
	obs.append(float(player._stone) / float(MAX_RESOURCES))
	obs.append(float(player._crystal) / float(MAX_CRYSTALS))

	# Can shoot (0 or 1 based on cooldown)
	obs.append(1.0 if player._can_shoot else 0.0)

	# Nearest enemy (relative position)
	var enemy_info = _get_nearest_entity(player, "enemies")
	obs.append(enemy_info["rel_x"])
	obs.append(enemy_info["rel_y"])
	obs.append(float(enemy_info["exists"]))

	# Nearest factory (relative position)
	var factory_info = _get_nearest_entity(player, "factories")
	obs.append(factory_info["rel_x"])
	obs.append(factory_info["rel_y"])
	obs.append(float(factory_info["exists"]))

	# Nearest nest (relative position)
	var nest_info = _get_nearest_entity(player, "nests")
	obs.append(nest_info["rel_x"])
	obs.append(nest_info["rel_y"])
	obs.append(float(nest_info["exists"]))

	# Nearest resource (relative position)
	var resource_info = _get_nearest_entity(player, "resources")
	obs.append(resource_info["rel_x"])
	obs.append(resource_info["rel_y"])
	obs.append(float(resource_info["exists"]))

	# Global state
	var ai = _get_ai()
	if ai:
		obs.append(float(ai.get_factories().get_child_count()) / 5.0)
		obs.append(float(ai.get_friendlies().get_child_count()) / 10.0)
		obs.append(float(ai.get_enemy_structures().get_child_count()) / 5.0)
	else:
		obs.append(0.0)
		obs.append(0.0)
		obs.append(0.0)

	# Time elapsed (normalize to 300 seconds = 5 min)
	obs.append(float(_step_count * 4) / 300.0)  # 4 physics ticks per RL step

	return obs

## Apply a discrete action
func apply_action_v0(action: int) -> void:
	if action < 0 or action >= RLAction.size():
		return

	var player = _get_player()
	if not player or player._dead:
		return

	# Handle movement actions
	var movement_vector = Vector2.ZERO
	match action:
		RLAction.MOVE_UP:
			movement_vector = Vector2(0, -1)
		RLAction.MOVE_DOWN:
			movement_vector = Vector2(0, 1)
		RLAction.MOVE_LEFT:
			movement_vector = Vector2(-1, 0)
		RLAction.MOVE_RIGHT:
			movement_vector = Vector2(1, 0)
		RLAction.MOVE_UP_LEFT:
			movement_vector = Vector2(-1, -1).normalized()
		RLAction.MOVE_UP_RIGHT:
			movement_vector = Vector2(1, -1).normalized()
		RLAction.MOVE_DOWN_LEFT:
			movement_vector = Vector2(-1, 1).normalized()
		RLAction.MOVE_DOWN_RIGHT:
			movement_vector = Vector2(1, 1).normalized()
		RLAction.SHOOT_NEAREST:
			_shoot_nearest_target(player)
		RLAction.MINE_NEAREST:
			_mine_nearest_resource(player)
		RLAction.INTERACT:
			_interact_factory(player)

	# Apply movement via Input simulation
	_apply_movement(movement_vector)

## Check if episode is done
func is_episode_done() -> bool:
	return _episode_done

## Mark episode as done
func end_episode() -> void:
	_episode_done = true

## Get events that occurred this step (agent uses these for reward)
func get_events_this_step() -> Dictionary:
	return _events_this_step.duplicate()

## Record that a nest was destroyed
func record_nest_destroyed() -> void:
	_events_this_step["nest_destroyed"] = _events_this_step.get("nest_destroyed", 0) + 1

## Record that a crystal was collected
func record_crystal_collected() -> void:
	_events_this_step["crystals_collected"] = _events_this_step.get("crystals_collected", 0) + 1

## Record player damage
func record_player_damage(amount: int) -> void:
	_events_this_step["damage_taken"] = _events_this_step.get("damage_taken", 0) + amount

## Record factory destroyed
func record_factory_destroyed() -> void:
	_events_this_step["factory_destroyed"] = true

## Record player death
func record_player_death() -> void:
	_events_this_step["player_died"] = true

## Record rocket launched (win)
func record_rocket_launched() -> void:
	_events_this_step["rocket_launched"] = true

## Get episode stats
func get_episode_stats() -> Dictionary:
	return {
		"steps": _step_count,
		"done": _episode_done
	}

## Internal: Reset events for the next step
func _reset_events() -> void:
	_events_this_step = {
		"nest_destroyed": 0,
		"crystals_collected": 0,
		"damage_taken": 0,
		"factory_destroyed": false,
		"player_died": false,
		"rocket_launched": false,
	}

# ======= INTERNAL HELPERS =======

func _get_player() -> Node:
	var level = get_tree().current_scene
	if level and level.has_node("Player"):
		return level.get_node("Player")
	return null

func _get_ai() -> Node:
	if get_tree().root.has_node("Ai"):
		return get_tree().root.get_node("Ai")
	return null

func _get_nearest_entity(from_node: Node, entity_type: String) -> Dictionary:
	var result = {
		"rel_x": 0.0,
		"rel_y": 0.0,
		"exists": false
	}

	var ai = _get_ai()
	if not ai:
		return result

	var _candidates = []
	var node_list = null

	match entity_type:
		"enemies":
			node_list = ai.get_enemies()
		"factories":
			node_list = ai.get_factories()
		"nests":
			node_list = ai.get_enemy_structures()
		"resources":
			# Resources are in the World node
			var level = get_tree().current_scene
			if level and level.has_node("World"):
				node_list = level.get_node("World")

	if not node_list or node_list.get_child_count() == 0:
		return result

	# Find nearest
	var nearest = null
	var min_distance = INF

	for child in node_list.get_children():
		if not is_instance_valid(child):
			continue

		var dist = from_node.global_position.distance_to(child.global_position)
		if dist < min_distance:
			min_distance = dist
			nearest = child

	if nearest:
		var rel_pos = nearest.global_position - from_node.global_position
		result["rel_x"] = rel_pos.x / MAP_SIZE
		result["rel_y"] = rel_pos.y / MAP_SIZE
		result["exists"] = true

	return result

func _shoot_nearest_target(player: Node) -> void:
	var ai = _get_ai()
	if not ai:
		return

	var enemies = ai.get_enemies()
	var nests = ai.get_enemy_structures()

	# Find nearest threat (enemy or nest)
	var nearest = null
	var min_dist = INF

	for enemy in enemies.get_children():
		if is_instance_valid(enemy):
			var dist = player.global_position.distance_to(enemy.global_position)
			if dist < min_dist:
				min_dist = dist
				nearest = enemy

	for nest in nests.get_children():
		if is_instance_valid(nest):
			var dist = player.global_position.distance_to(nest.global_position)
			if dist < min_dist:
				min_dist = dist
				nearest = nest

	if nearest:
		# Calculate aim direction and set up shot
		var aim_dir = (nearest.global_position - player.global_position).normalized()
		# Store this for the player to use
		player._rl_aim_direction = aim_dir
		# Trigger shoot
		Input.action_press("shoot")

func _mine_nearest_resource(player: Node) -> void:
	var level = get_tree().current_scene
	if not level or not level.has_node("World"):
		return

	var world = level.get_node("World")
	var nearest = null
	var min_dist = INF

	for resource in world.get_children():
		if is_instance_valid(resource) and resource.name.find("Resource") >= 0:
			var dist = player.global_position.distance_to(resource.global_position)
			if dist < min_dist:
				min_dist = dist
				nearest = resource

	if nearest:
		# Switch to mining mode if not already
		if not player._mining_tool_enable:
			Input.action_press("toggle_mining")

		# Aim at resource
		var aim_dir = (nearest.global_position - player.global_position).normalized()
		player._rl_aim_direction = aim_dir
		Input.action_press("shoot")

func _interact_factory(_player: Node) -> void:
	# Toggle factory menu interaction
	Input.action_press("interact")

func _apply_movement(direction: Vector2) -> void:
	# Clear previous movement inputs
	Input.action_release("move_up")
	Input.action_release("move_down")
	Input.action_release("move_left")
	Input.action_release("move_right")

	# Apply new movement
	if direction.y < 0:
		Input.action_press("move_up")
	elif direction.y > 0:
		Input.action_press("move_down")

	if direction.x < 0:
		Input.action_press("move_left")
	elif direction.x > 0:
		Input.action_press("move_right")

func _get_zero_observation() -> Array:
	var obs = []
	for _i in range(25):  # Match the size of a normal observation
		obs.append(0.0)
	return obs
