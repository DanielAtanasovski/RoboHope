extends Node

# TCP Server for RL communication
var _server: TCP_Server = null
var _client: StreamPeerTCP = null
var _port: int = 9999

# Step control
var _ticks_per_step: int = 4
var _pending_ticks: int = 0
var _step_in_progress: bool = false
var _last_action: int = 0

# Reset response handling
# (removed - no longer needed since reset is synchronous)

func _ready():
    if not $"/root/RLInterface".rl_mode:
        set_process(false)
        call_deferred("queue_free")
        return

    _parse_args()
    _start_server()

func _parse_args():
    var args = OS.get_cmdline_args()
    for arg in args:
        if arg.begins_with("--port="):
            _port = int(arg.split("=")[1])

func _start_server():
    _server = TCP_Server.new()
    var err = _server.listen(_port)
    if err != OK:
        push_error("Failed to start RL server on port %d" % _port)
        return
    print("RL Server listening on port %d" % _port)

func _process(_delta):
	# Check for new connections
	if _server and _server.is_connection_available():
		_client = _server.take_connection()
		if _client:
			print("RL Client connected")

	# Handle client messages
	if _client and _client.is_connected_to_host():
		if _client.get_available_bytes() > 0:
			_handle_client_messages()

	# Handle pending step ticks
	if _pending_ticks > 0:
		_pending_ticks -= 1
		if _pending_ticks == 0:
			_send_step_response()

func _handle_client_messages():
	# Try to read available data from the client
	var available = _client.get_available_bytes()
	if available <= 0:
		return

	# Read data in smaller chunks
	var result = _client.get_data(min(available, 512))

	if result.size() >= 2 and result[0] == OK:
		var raw_bytes = result[1]
		var raw_string = raw_bytes.get_string_from_utf8()

		# Process all complete lines in the buffer
		for line in raw_string.split("\n"):
			var stripped = line.strip_edges()
			if stripped.length() > 0:
				_process_command(stripped)

func _process_command(json_string: String):
	# Parse JSON command
	var json = JSON.parse(json_string)
	if json.error:
		_send_error("JSON parse error")
		return

	var cmd_dict = json.result
	if not cmd_dict or not cmd_dict.has("cmd"):
		_send_error("Missing 'cmd' field")
		return

	var cmd = cmd_dict["cmd"]
	match cmd:
		"reset":
			var rng_seed = cmd_dict.get("seed", -1)
			_handle_reset(rng_seed)
		"step":
			var action = cmd_dict.get("action", 0)
			_handle_step(action)
		"close":
			_handle_close()
		_:
			_send_error("Unknown command: %s" % cmd)

func _handle_reset(rng_seed: int):
	$"/root/RLInterface".reset_world(rng_seed)
	# Reset is synchronous now, send response immediately
	var response = _build_step_response()
	_send_json(response)

func _handle_step(action: int):
	if _step_in_progress:
		_send_error("Step already in progress")
		return

	_step_in_progress = true
	_last_action = action

	# Reset events for this step
	$"/root/RLInterface"._reset_events()

	# Apply the action
	$"/root/RLInterface".apply_action_v0(action)

	# Schedule the step completion after N physics frames
	_pending_ticks = _ticks_per_step

func _send_step_response():
	_step_in_progress = false
	var response = _build_step_response()
	_send_json(response)

func _build_step_response() -> Dictionary:
	var rl = $"/root/RLInterface"

	# Increment step counter in RLInterface
	rl._step_count += 1

	var obs = rl.get_observation_v0()
	var done = rl.is_episode_done()
	var events = rl.get_events_this_step()

	return {
		"obs": obs,
		"done": done,
		"info": {
			"step": rl._step_count,
			"action": _last_action,
			"events": events
		}
	}

func _handle_close():
	print("RL Server: Client requesting close")
	if _client:
		_client.disconnect_from_host()
		_client = null

func _send_json(data: Dictionary):
	if not _client or not _client.is_connected_to_host():
		return

	var json_string = JSON.print(data) + "\n"
	_client.put_data(json_string.to_utf8())

func _send_error(msg: String):
	if not _client or not _client.is_connected_to_host():
		return

	var error_dict = {
		"error": msg
	}
	_send_json(error_dict)
