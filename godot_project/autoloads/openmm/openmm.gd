class_name OpenMMClass extends Node

const _PRINT_REQUEST_AND_RESPONSE: bool = false
const _CONNECT_TO_DEBUG_SOCKET: bool = false # Change this to lanch and debug server manually
const _DEBUG_SOCKET_NAME: String = "msep-one-socket"
const OPENMM_CRASH_MESSAGE: String = "OpenMM server crashed with unexpected result"

const ImportFilePayload = preload("res://autoloads/openmm/import_file_payload.gd")

const ServerCommands: Dictionary = {
	RELAX    = "Relax",
	SIMULATE = "Simulate",
	ABORT_SIMULATION = "AbortSimulation",
	EXPORT   = "Export File",
	GET_PID  = "GetProcessID",
	QUIT     = "Quit",
}

class RelaxResult:
	var original_payload: OpenMMPayload
	var positions: PackedVector3Array
	func _init(out_payload: OpenMMPayload, out_positions: PackedVector3Array) -> void:
		original_payload = out_payload
		positions = out_positions


class ImportFileResult:
	var original_payload: ImportFilePayload
	var atoms_count: int
	var bonds_count: int
	var atomic_numbers: PackedByteArray = []
	var positions: PackedVector3Array = []
	var bonds: PackedVector3Array = [] # (x: atom1, y: atom2, z: order)
	var aabb := AABB()
	func _init(out_payload: ImportFilePayload, in_atomic_numbers: PackedByteArray,
				in_positions: PackedVector3Array, in_bonds: PackedVector3Array) -> void:
		
		assert(in_atomic_numbers.size() == in_positions.size())
		original_payload = out_payload
		atoms_count = in_atomic_numbers.size()
		bonds_count = in_bonds.size()
		atomic_numbers = in_atomic_numbers.duplicate()
		positions = in_positions.duplicate()
		bonds = in_bonds.duplicate()
		if !positions.is_empty():
			aabb.position = positions[0]
			for pos in positions:
				aabb = aabb.expand(pos)
			aabb = aabb.abs()


@export var shortcut_kill_server: Shortcut = null


@onready var utils: OpenMMUtils = $Utils as OpenMMUtils


var _ctx := ZMQContext.new()
var _bus: ZMQSocket = null
var _bus_thread: Thread = null
var _bus_lock := TrackableMutex.new("Zmq-Main-Bus", false)
var _subscription_bus: ZMQSocket = null
var _subscription_thread: Thread = null
var _subscription_thread_running: bool = false
var _subscription_thread_lock := TrackableMutex.new("Simulation-Subscription-Bus", false)
var _threads: Array[Thread] = []
var _running_simulations: Dictionary = {
	# subscription_id:int = data:SimulationData
}
var _tmp_dir: String = _find_tmp_dir()
var extract_thread: Thread = null
var _is_windows: bool = OS.get_name().to_lower() == "windows"
var _server_pid_mutex := Mutex.new() # TrackableMutex.new("OpenMM-Server-PID", false)
var _server_pid: int = -1:
	set(v):
		_server_pid_mutex.lock()#("setter")
		_server_pid = v
		_server_pid_mutex.unlock()#("setter")
	get:
		_server_pid_mutex.lock()#("getter")
		var pid: int = _server_pid
		_server_pid_mutex.unlock()#("getter")
		return pid


func _ready() -> void:
	# Perform integrity check
	var missing_required_files: Array[String] = utils.find_missing_files()
	var custom_server_script_in_use: bool = utils.is_custom_server_script_in_use()
	var display_backed_up_files: Dictionary = { value = false }
	if !missing_required_files.is_empty() or custom_server_script_in_use:
		# wait until user presses OK in the About dialog
		await InitialInfoScreen.confirmed
	
	if !missing_required_files.is_empty():
		var dlg := NanoAcceptDialog.new()
		dlg.exclusive = true
		dlg.dialog_text = \
				"\nThe following mandatory files was not found in the applicaiton pack:\n" + \
				">>  %s\n\n" % "\n>>  ".join(missing_required_files) + \
				"Are those files missing in the project export whitelist for this platform?"
		dlg.add_button("Copy list to clipboard", false, "copy")
		dlg.add_button("Quit now", true, "quit")
		var custom_action_callback: Callable = func(action: String) -> void:
			match action:
				"ok":
					dlg.queue_free()
				"copy":
					DisplayServer.clipboard_set(", ".join(missing_required_files))
					dlg.queue_free()
				"quit":
					get_tree().auto_accept_quit = true
					get_tree().quit()
				_:
					push_error("Unexpected action: " + action)
					dlg.queue_free()
		dlg.confirmed.connect(custom_action_callback.bind("ok"))
		dlg.custom_action.connect(custom_action_callback)
		get_tree().root.add_child.call_deferred(dlg)
		dlg.popup_centered.call_deferred()
		await dlg.tree_exited
	if custom_server_script_in_use:
		var dlg := NanoAcceptDialog.new()
		dlg.exclusive = true
		dlg.dialog_text = \
				"\nCurrently, this version MSEP.one is using a custom OpenMM script." + \
				"\nPress ‘OK’ to continue, or ‘Revert’ to use an unedited version of the file."
		dlg.add_button(tr("Revert"), true, "revert")
		dlg.add_button("Quit now", true, "quit")
		var custom_action_callback: Callable = func(action: String) -> void:
			match action:
				"ok":
					# dont do nothing
					dlg.queue_free()
				"revert":
					# disable custom script, overwrite modified files and display the list of
					# backed up files in a new dialog
					display_backed_up_files.value = true
					MolecularEditorContext.msep_editor_settings.openmm_server_allow_modified_script = false
					dlg.queue_free()
				"quit":
					get_tree().auto_accept_quit = true
					get_tree().quit()
				_:
					push_error("Unexpected action: " + action)
					dlg.queue_free()
		dlg.confirmed.connect(custom_action_callback.bind("ok"))
		dlg.custom_action.connect(custom_action_callback)
		get_tree().root.add_child.call_deferred(dlg)
		dlg.popup_centered.call_deferred()
		await dlg.tree_exited
	if utils.needs_install_or_update():
		extract_thread = Thread.new()
		extract_thread.start(utils.install_environment)
		InitialInfoScreen.confirmed.connect(BusyIndicator.activate.bind(tr("Running First Time Setup")))
		await utils.environment_installed
		MolecularEditorContext.show_first_run_message()
		InitialInfoScreen.confirmed.disconnect(BusyIndicator.activate)
		BusyIndicator.deactivate()
	if utils.needs_install_scripts():
		var backed_up_files: PackedStringArray = []
		utils.install_additional_scripts(backed_up_files)
		if display_backed_up_files.value and not backed_up_files.is_empty():
			var dlg := NanoAcceptDialog.new()
			dlg.exclusive = true
			dlg.dialog_text = \
					"\nThe custom OpenMM script has been backed up to:\n >> " + \
					("\n >> ".join(backed_up_files))
			dlg.confirmed.connect(dlg.queue_free)
			get_tree().root.add_child.call_deferred(dlg)
			dlg.popup_centered.call_deferred()
	_bus = ZMQSocket.create(_ctx, ZMQSocket.TYPE_REQUEST)
	_subscription_bus = ZMQSocket.create(_ctx, ZMQSocket.TYPE_SUB)
	_start_zmq_sockets()


func _start_zmq_sockets() -> void:
	const mutex_context: String = "OpenMM::_restart_zmq_sockets"
	_bus_lock.lock(mutex_context)
	if _CONNECT_TO_DEBUG_SOCKET:
		var tmp_path: String = _tmp_dir.path_join(_DEBUG_SOCKET_NAME)
		_bus.connect_to_server("ipc://" + tmp_path)
		print_rich("[color=magenta]Connected to IPC socket " + tmp_path + "[/color]")
		tmp_path += "-subscription"
		_subscription_bus.connect_to_server("ipc://" + tmp_path)
		print_rich("[color=magenta]Connected to IPC socket " + tmp_path + "[/color]")
		_capture_openmm_server_pid.call_deferred()
	else:
		# Conda takes time to initialize, so let's start as soon as possible
		_bus_thread = Thread.new()
		_bus_thread.start(_launch_openmm_server_in_thread.bind(utils.globalize_path("user://python")))
		var socket: String = _tmp_dir.path_join("msep-%d" % OS.get_process_id())
		_bus.connect_to_server("ipc://"+socket)
		print_rich("[color=magenta]Connected to IPC socket " + socket + "[/color]")
		socket += "-subscription"
		_subscription_bus.connect_to_server("ipc://" + socket)
		print_rich("[color=magenta]Connected to IPC socket " + socket + "[/color]")
	_bus_lock.unlock(mutex_context)

func _shortcut_input(event: InputEvent) -> void:
	if shortcut_kill_server == null or !OS.has_feature("editor"):
		return
	if shortcut_kill_server.matches_event(event):
		request_quit_server()


func _find_tmp_dir() -> String:
	var tmp_path: String = ""
	for env_variable in PackedStringArray(["TMPDIR", "TEMP", "TMP"]):
		tmp_path = OS.get_environment("TEMP")
		if !tmp_path.is_empty():
			break
	if tmp_path.is_empty():
		for candidate_path in PackedStringArray(["/tmp", "/var/tmp", "/usr/tmp"]):
			if DirAccess.dir_exists_absolute(candidate_path):
				tmp_path = candidate_path
				break
	assert(!tmp_path.is_empty())
	return tmp_path


func relaunch_openmm_server() -> void:
	print_rich("[color=1040FF]Relaunch OpenMM Server[/color]")
	request_quit_server()
	var context: WorkspaceContext = MolecularEditorContext.get_current_workspace_context()
	if is_instance_valid(context):
		context.start_async_work(tr("Restarting OpenMM Server"))
	while is_instance_valid(_bus_thread) and _bus_thread.is_alive():
		await get_tree().create_timer(0.50).timeout
	if _CONNECT_TO_DEBUG_SOCKET:
		var tmp_path: String = _tmp_dir.path_join(_DEBUG_SOCKET_NAME)
		_bus.connect_to_server("ipc://" + tmp_path)
		print_rich("[color=magenta]Connected to IPC socket " + tmp_path + "[/color]")
		tmp_path += "-subscription"
		_subscription_bus.connect_to_server("ipc://" + tmp_path)
		print_rich("[color=magenta]Connected to IPC socket " + tmp_path + "[/color]")
	else:
		# Conda takes time to initialize, so let's start as soon as possible
		_bus_thread = Thread.new()
		_bus_thread.start(_launch_openmm_server_in_thread.bind(utils.globalize_path("user://python")))
		var socket: String = _tmp_dir.path_join("msep-%d" % OS.get_process_id())
		_bus.connect_to_server("ipc://"+socket)
		print_rich("[color=magenta]Connected to IPC socket " + socket + "[/color]")
		socket += "-subscription"
		_subscription_bus.connect_to_server("ipc://" + socket)
		print_rich("[color=magenta]Connected to IPC socket " + socket + "[/color]")
	if is_instance_valid(context):
		context.end_async_work()


func request_relax(
		in_workspace_context: WorkspaceContext,
		in_temperature_in_kelvins: float,
		in_selection_only: bool,
		in_include_springs: bool,
		in_lock_atoms: bool,
		in_passivate_molecules: bool) -> RelaxRequest:
	return _request_relax(in_workspace_context, in_temperature_in_kelvins, in_selection_only,
		in_include_springs, in_lock_atoms, in_passivate_molecules)


func request_start_simulation(
		in_workspace_context: WorkspaceContext,
		in_parameters: SimulationParameters
		) -> SimulationData:
	var data := SimulationData.new(in_parameters)
	_request_start_simulation(in_workspace_context, data)
	return data


func request_abort_simulation(in_simulation: SimulationData) -> void:
	_request_abort_simulation(in_simulation)


func request_import(file_path: String, in_generate_bonds: bool, in_add_hydrogens: bool, in_remove_waters: bool) -> Promise:
	var promise := Promise.new()
	_request_import(file_path, in_generate_bonds, in_add_hydrogens, in_remove_waters, promise)
	return promise


func request_export(file_path: String, in_workspace_context: WorkspaceContext) -> Promise:
	var promise := Promise.new()
	_request_export(file_path, in_workspace_context, promise)
	return promise


func request_quit_server() -> void:
	const mutex_context: String = "OpenMM::request_quit_server"
	if _bus != null and _bus.is_connected_to_server():
		_bus_lock.lock(mutex_context)
		_bus.send_string(ServerCommands.QUIT)
		var _acknowledge_quit: PackedStringArray = _bus.receive_multipart_string()
		_bus_lock.unlock(mutex_context)
		if _CONNECT_TO_DEBUG_SOCKET:
			var tmp_path: String = _tmp_dir.path_join(_DEBUG_SOCKET_NAME)
			_bus.disconnect_from_server("ipc://" + tmp_path)
		else:
			var socket: String = _tmp_dir.path_join("msep-%d" % OS.get_process_id())
			_bus.disconnect_from_server("ipc://"+socket)


func _request_relax(
		in_workspace_context: WorkspaceContext,
		in_temperature_in_kelvins: float,
		in_selection_only: bool,
		in_include_springs: bool,
		in_lock_atoms: bool,
		in_passivate_molecules: bool) -> RelaxRequest:
	
	if !_CONNECT_TO_DEBUG_SOCKET and _bus_thread == null:
		_bus_thread = Thread.new()
		_bus_thread.start(_launch_openmm_server_in_thread.bind(utils.globalize_path("user://python")))
		
	const DONT_INCLUDE_VIRTUAL_OBJECTS: bool = false
	const NUDGE_ATOMS_FIX: bool = true
	var payload: OpenMMPayload = _create_payload(in_workspace_context , in_selection_only,
			DONT_INCLUDE_VIRTUAL_OBJECTS, in_include_springs, in_lock_atoms, in_passivate_molecules, NUDGE_ATOMS_FIX)
	if _PRINT_REQUEST_AND_RESPONSE:
		print_rich("[color=orange] Header: %s[/color]" % str(payload.header))
		print_rich("[color=orange] Topology: %s[/color]" % str(payload.topology))
		print_rich("[color=orange] Shapes: %s[/color]" % str(payload.shapes_data))
		print_rich("[color=orange] Motors: %s[/color]" % str(payload.motors_data))
		print_rich("[color=orange] State: %s[/color]" % str(payload.state))
	var relax_request := RelaxRequest.new(in_temperature_in_kelvins, in_selection_only, in_include_springs, in_lock_atoms, in_passivate_molecules)
	relax_request.original_payload = payload
	if _subscription_thread == null:
		_subscription_thread = Thread.new()
		_subscription_thread.start(_listen_simulation_subscriptions_in_thread)
	var thread := Thread.new()
	_threads.push_back(thread)
	thread.start(_process_relax_request_on_thread.bind(relax_request, in_workspace_context))
	_dispose_thread_when_done.call_deferred(relax_request.promise, thread)
	return relax_request

func _request_start_simulation(
		in_workspace_context: WorkspaceContext,
		out_simulation_data: SimulationData
		) -> void:
	
	if !_CONNECT_TO_DEBUG_SOCKET and _bus_thread == null:
		_bus_thread = Thread.new()
		_bus_thread.start(_launch_openmm_server_in_thread.bind(utils.globalize_path("user://python")))
	
	const INCLUDE_VIRTUAL_OBJECTS = true
	const LOCK_ATOMS = true
	const INCLUDE_SPRINGS = true
	const PASSIVATE_MOLECULES = false
	const NUDGE_ATOMS_FIX = false
	out_simulation_data.original_payload = _create_payload(in_workspace_context, false,
			INCLUDE_VIRTUAL_OBJECTS, INCLUDE_SPRINGS, LOCK_ATOMS, PASSIVATE_MOLECULES, NUDGE_ATOMS_FIX)
	out_simulation_data.push_frame(0, out_simulation_data.original_payload.initial_positions)
	if _PRINT_REQUEST_AND_RESPONSE:
		print_rich("[color=orange] Header: %s[/color]" % str(out_simulation_data.original_payload.header))
		print_rich("[color=orange] Topology: %s[/color]" % str(out_simulation_data.original_payload.topology))
		print_rich("[color=orange] State: %s[/color]" % str(out_simulation_data.original_payload.state))
	_running_simulations[out_simulation_data.id] = out_simulation_data
	_subscription_bus.set_option(ZMQSocket.OPT_SUBSCRIBE, str(out_simulation_data.id))
	_subscription_bus.set_option(ZMQSocket.OPT_SUBSCRIBE, "err:"+str(out_simulation_data.id))
	if _subscription_thread == null:
		_subscription_thread = Thread.new()
		_subscription_thread.start(_listen_simulation_subscriptions_in_thread)
	var thread := Thread.new()
	_threads.push_back(thread)
	thread.start(_start_simulation_on_thread.bind(out_simulation_data))
	_dispose_thread_when_done.call_deferred(out_simulation_data.start_promise, thread)


func _request_abort_simulation(in_simulation: SimulationData) -> void:
	if !_CONNECT_TO_DEBUG_SOCKET and _bus_thread == null:
		# bus not running there should not be any simulation to abort
		return
	if _PRINT_REQUEST_AND_RESPONSE:
		print_rich("[color=orange]Abort simulation: %d[/color]" % str(in_simulation.id))
	var thread := Thread.new()
	_threads.push_back(thread)
	var abort_promise := Promise.new()
	thread.start(_abort_simulation_on_thread.bind(in_simulation.id, abort_promise))
	_dispose_thread_when_done.call_deferred(abort_promise, thread)


func _request_import(
	in_file_path: String,
	in_generate_bonds: bool,
	in_add_hydrogens: bool,
	in_remove_waters: bool,
	out_promise: Promise) -> void:
	
	if !_CONNECT_TO_DEBUG_SOCKET and _bus_thread == null:
		_bus_thread = Thread.new()
		_bus_thread.start(_launch_openmm_server_in_thread.bind(utils.globalize_path("user://python")))
	
	var payload := ImportFilePayload.new(in_file_path, in_generate_bonds, in_add_hydrogens, in_remove_waters)
	if _PRINT_REQUEST_AND_RESPONSE:
		print_rich("[color=orange] %s[/color]" % ", ".join(payload.to_multipart_message()))
	
	var thread := Thread.new()
	_threads.push_back(thread)
	thread.start(_process_import_file_request_on_thread.bind(payload, out_promise))
	_dispose_thread_when_done.call_deferred(out_promise, thread)


func _request_export(
	in_file_path: String,
	in_workspace_context: WorkspaceContext,
	out_promise: Promise) -> void:
	
	const SELECTION_ONLY: bool = false
	const INCLUDE_VIRTUAL_OBJECTS: bool = false
	const INCLUDE_SPRINGS: bool = false
	const LOCK_ATOMS: bool = false
	const PASSIVATE_MOLECULES: bool = false
	const NUDGE_ATOMS_FIX: bool = false
	var payload: OpenMMPayload = _create_payload(in_workspace_context,
			SELECTION_ONLY, INCLUDE_VIRTUAL_OBJECTS, INCLUDE_SPRINGS,
			LOCK_ATOMS, PASSIVATE_MOLECULES, NUDGE_ATOMS_FIX)
	
	var thread := Thread.new()
	_threads.push_back(thread)
	thread.start(_process_export_file_request_on_thread.bind(in_file_path, payload, out_promise))
	_dispose_thread_when_done.call_deferred(out_promise, thread)


func _schedule_app_re_focus() -> void:
	var re_focus_manager: Node = Node.new()
	# call_deferred is used to run the addition on main thread.
	get_tree().get_root().add_child.call_deferred(re_focus_manager)
	var script: Script = load("res://autoloads/openmm/re_focus_app.gd")
	re_focus_manager.set_script(script)


func _launch_openmm_server_in_thread(script_path: String) -> void:
	_capture_openmm_server_pid.call_deferred()
	var socket: String = _tmp_dir.path_join("msep-%d" % OS.get_process_id())
	
	var stdout: Array = []
	var result: int = -1
	if _is_windows:
		var commands: Array = [
			"C:",
			"cd " + utils.msep_environment_path.replace("/", "\\"),
			"Scripts\\activate.bat",
			"Scripts\\conda-unpack.exe",
			# this is to change drive in case of need. ie: "C:", "D:"
			script_path.left(2),
			"cd " + script_path.path_join("scripts"),
			"python openmm_server.py --ipc-socket="+socket,
		]
		_schedule_app_re_focus()
		result = OS.execute('CMD.EXE', ["/C", " && ".join(commands)], stdout, true)
	else:
		var args: String = "--ipc-socket="+socket
		#This is the location of the conda environment with the dependencies needed to run relaxation:
		var environment: String = utils.msep_environment_path
		environment = "\'%s\'" % environment
		script_path = script_path.path_join("launch_server.sh")
		script_path = "\'%s\'" % script_path
		result = OS.execute( "eval", [script_path, args, environment], stdout, true, true)
	_server_pid = -abs(result)
	if result != OK:
		push_error("OpenMM server finished with unexpected result: %X" % result)
	var print_color: String = "green" if result == OK else "red"
	print_rich("[color=%s]OpenMM server finished with result: %X[/color]" % [print_color, result])
	for line: String in _format_server_stdout(stdout):
		print_rich(">>  %s" % line)
	var needs_restart: bool = result != OK
	_dispose_bus_threads.call_deferred(needs_restart)


func _capture_openmm_server_pid() -> void:
	_server_pid = 0
	var thread := Thread.new()
	var promise := Promise.new()
	thread.start(_capture_openmm_server_pid_in_thread.bind(promise))
	_dispose_thread_when_done.call_deferred(promise, thread)
	if _CONNECT_TO_DEBUG_SOCKET:
		await promise.wait_for_fulfill()
		print_debug("Relax requests will only read responses from PID ", _server_pid,
		". If this process dies you will need to restart the debugging process",
		". Sorry for inconvenience")


func _capture_openmm_server_pid_in_thread(out_promise: Promise) -> void:
	const mutex_context: String = "OpenMM::_capture_openmm_server_pid_in_thread"
	_bus_lock.lock(mutex_context)
	_bus.send_string(ServerCommands.GET_PID)
	var response: PackedByteArray = _bus.receive_buffer()
	_bus_lock.unlock(mutex_context)
	_server_pid = -1 if response.is_empty() else response.decode_u64(0)
	out_promise.fulfill.call_deferred(null)


func _listen_simulation_subscriptions_in_thread() -> void:
	const mutex_context: String = "_listen_simulation_subscriptions_in_thread"
	_subscription_thread_lock.lock(mutex_context)
	_subscription_thread_running = true
	while _subscription_thread_running:
		var str_subscription_id: String = _subscription_bus.receive_string(ZMQSocket.RECEIVE_FLAG_DONT_WAIT)
		_subscription_thread_lock.unlock(mutex_context)
		if str_subscription_id.is_empty():
			OS.delay_msec(10)
		elif str_subscription_id.begins_with("err:"):
			# An error ocurred in the startup of a simulation
			var subscription_id: int = str_subscription_id.substr(4).to_int()
			if _running_simulations.has(subscription_id):
				var simulation_data: SimulationData = _running_simulations.get(subscription_id, null)
				_handle_request_error(simulation_data.start_promise, false, _subscription_thread_lock, _subscription_bus)
		else:
			assert(str_subscription_id.is_valid_int(), "Invalid Simulation ID: %s" % str_subscription_id)
			var subscription_id: int = str_subscription_id.to_int()
			if _running_simulations.has(subscription_id):
				var simulation_data: SimulationData = _running_simulations.get(subscription_id, null)
				_handle_simulation_data(simulation_data)
			else:
				assert(false, "Simulation %d is not running" % subscription_id)
				pass
		_subscription_thread_lock.lock(mutex_context)
	_subscription_thread_lock.unlock(mutex_context)


func _handle_simulation_data(simulation_data: SimulationData) -> void:
	assert(_subscription_bus.has_more(), "Unexpected end of message")
	var time_buffer: PackedByteArray = _subscription_bus.receive_buffer()
	var time: float = time_buffer.decode_double(0)
	assert(_subscription_bus.has_more(), "Unexpected end of message")
	var positions_buffer: PackedByteArray = _subscription_bus.receive_buffer()
	if positions_buffer == "err".to_utf8_buffer():
		simulation_data.invalidate()
		return
	var float_array: PackedFloat64Array = positions_buffer.to_float64_array()
	var positions: PackedVector3Array = []
	for i in range(0, float_array.size(), 3):
		var pos := Vector3(float_array[i], float_array[i+1], float_array[i+2])
		positions.push_back(pos)
	assert(!_subscription_bus.has_more(), "Unexpected length of message")
	assert(positions.size() == simulation_data.original_payload.initial_positions.size(),
		"Invalid state size")
	simulation_data.push_frame(time, positions)


func _dispose_bus_threads(in_restart_zmq_sockets: bool = false) -> void:
	assert(OS.get_thread_caller_id() == OS.get_main_thread_id(), "This method should only be called in the main thread!")
	if is_instance_valid(_bus_thread) and _bus_thread.is_started():
		_bus_thread.wait_to_finish()
	_bus_thread = null
	_subscription_thread_lock.lock("_dispose_bus_threads")
	_subscription_thread_running = false
	_subscription_thread_lock.unlock("_dispose_bus_threads")
	if is_instance_valid(_subscription_thread) and _subscription_thread.is_started():
		_subscription_thread.wait_to_finish()
	_subscription_thread = null
	if in_restart_zmq_sockets:
		while _threads.size():
			# Wait for all processes to end
			await get_tree().process_frame
		const mutex_context: String = "OpenMM::_dispose_bus_threads::in_restart_zmq_sockets"
		_bus_lock.lock(mutex_context)
		_bus = ZMQSocket.create(_ctx, ZMQSocket.TYPE_REQUEST)
		_subscription_bus = ZMQSocket.create(_ctx, ZMQSocket.TYPE_SUB)
		_bus_lock.unlock(mutex_context)
		_start_zmq_sockets()


func _process_relax_request_on_thread(out_relax_request: RelaxRequest,
			in_workspace_context: WorkspaceContext) -> void:
	const mutex_context: String = "OpenMM::_process_relax_request_on_thread"
	var initial_server_pid: int = 0
	while initial_server_pid <= 0:
		OS.delay_msec(100)
		initial_server_pid = _server_pid
	var relax_promise: Promise = out_relax_request.promise
	var other_objects_to_send: Array[String] = []
	other_objects_to_send.assign(out_relax_request.original_payload.other_objects_data.values())
	assert(other_objects_to_send.size() == out_relax_request.original_payload.other_objects_count)
	_bus_lock.lock(mutex_context)
	_bus.send_string(ServerCommands.RELAX, ZMQSocket.SEND_FLAG_SNDMORE)
	var temperature_bytes := PackedByteArray()
	temperature_bytes.resize(8)
	temperature_bytes.encode_float(0, out_relax_request.temperature_in_kelvins)
	_bus.send_buffer(temperature_bytes, ZMQSocket.SEND_FLAG_SNDMORE)
	var forcefield_list: String = ";".join(out_relax_request.original_payload.forcefield_files)
	_bus.send_string(forcefield_list, ZMQSocket.SEND_FLAG_SNDMORE)
	_bus.send_buffer(out_relax_request.original_payload.header, ZMQSocket.SEND_FLAG_SNDMORE)
	_bus.send_buffer(out_relax_request.original_payload.topology, ZMQSocket.SEND_FLAG_SNDMORE)
	var send_flags: ZMQSocket.SendFlags = ZMQSocket.SEND_FLAG_NONE if other_objects_to_send.is_empty() else ZMQSocket.SEND_FLAG_SNDMORE
	_bus.send_buffer(out_relax_request.original_payload.state, send_flags)
	
	while not other_objects_to_send.is_empty():
		var motor_data_buffer: String = other_objects_to_send.pop_front()
		send_flags = ZMQSocket.SEND_FLAG_NONE if other_objects_to_send.is_empty() else ZMQSocket.SEND_FLAG_SNDMORE
		_bus.send_string(motor_data_buffer, send_flags)
	
	var response: PackedByteArray = []
	while response.is_empty() and initial_server_pid == _server_pid:
		response = _bus.receive_buffer(ZMQSocket.RECEIVE_FLAG_DONT_WAIT)
		_bus_lock.unlock(mutex_context)
		# This makes the query non blocking
		OS.delay_msec(100)
		_bus_lock.lock(mutex_context)
	_bus_lock.unlock(mutex_context)
	var did_server_crash: bool = initial_server_pid != _server_pid
	if did_server_crash:
		out_relax_request.promise.fail.call_deferred(OPENMM_CRASH_MESSAGE)
		return
	if response == "err".to_utf8_buffer():
		var positions: PackedVector3Array = []
		_handle_request_error(relax_promise, RelaxResult.new(out_relax_request.original_payload, positions))
		return
	var positions: PackedVector3Array = []
	var float_array: PackedFloat64Array = response.to_float64_array()
	for i in range(0, float_array.size(), 3):
		positions.push_back(Vector3(float_array[i], float_array[i+1], float_array[i+2]))
	if _PRINT_REQUEST_AND_RESPONSE:
		print_rich("[color=green]Relaxed atom positions:\n\t%s[/color]" % str(positions))
	
	var error_msg: String = _position_integrity_check(out_relax_request, in_workspace_context, positions)
	if error_msg.is_empty():
		relax_promise.fulfill.call_deferred(RelaxResult.new(out_relax_request.original_payload, positions))
	else:
		relax_promise.fail.call_deferred(error_msg, RelaxResult.new(out_relax_request.original_payload, positions))


func _position_integrity_check(out_relax_request: RelaxRequest, in_workspace_context: WorkspaceContext,
			in_positions: PackedVector3Array) -> String:
	var out_error_msg: String = ""
	var payload: OpenMMPayload = out_relax_request.original_payload
	var nmb_of_atoms: int = in_positions.size()
	for i in range(nmb_of_atoms):
		var structure_atom_pair: Array = payload.request_atom_id_to_structure_and_atom_id_map[i]
		var structure_id: int = structure_atom_pair[0]
		var structure: NanoStructure = in_workspace_context.workspace.get_structure_by_int_guid(structure_id)
		var position: Vector3 = in_positions[i]
		if is_nan(position.x) or is_nan(position.y) or is_nan(position.z):
			out_error_msg += tr("Invalid position for ") + structure.get_structure_name() + "@" + \
					str(i) + "->" + str(position) + "\n"
	return out_error_msg


func _start_simulation_on_thread(in_simulation_data: SimulationData) -> void:
	const mutex_context: String = "OpenMM::_start_simulation_on_thread"
	var simulation_id: int = in_simulation_data.id
	var initial_server_pid: int = 0
	while initial_server_pid <= 0:
		OS.delay_msec(100)
		initial_server_pid = _server_pid
	var other_objects_to_send: Array[String] = []
	other_objects_to_send.assign(in_simulation_data.original_payload.other_objects_data.values())
	assert(other_objects_to_send.size() == in_simulation_data.original_payload.other_objects_count)
	_bus_lock.lock(mutex_context)
	_bus.send_string(ServerCommands.SIMULATE, ZMQSocket.SEND_FLAG_SNDMORE)
	var id_bytes := PackedByteArray()
	id_bytes.resize(8)
	id_bytes.encode_s64(0, in_simulation_data.id)
	_bus.send_buffer(id_bytes, ZMQSocket.SEND_FLAG_SNDMORE)
	var parameters_bytes: PackedByteArray = in_simulation_data.parameters.to_byte_array()
	_bus.send_buffer(parameters_bytes, ZMQSocket.SEND_FLAG_SNDMORE)
	var forcefield_list: String = ";".join(in_simulation_data.original_payload.forcefield_files)
	_bus.send_string(forcefield_list, ZMQSocket.SEND_FLAG_SNDMORE)
	_bus.send_buffer(in_simulation_data.original_payload.header, ZMQSocket.SEND_FLAG_SNDMORE)
	_bus.send_buffer(in_simulation_data.original_payload.topology, ZMQSocket.SEND_FLAG_SNDMORE)
	var send_flags: ZMQSocket.SendFlags = ZMQSocket.SEND_FLAG_NONE if other_objects_to_send.is_empty() else ZMQSocket.SEND_FLAG_SNDMORE
	_bus.send_buffer(in_simulation_data.original_payload.state, send_flags)
	
	while not other_objects_to_send.is_empty():
		var motor_data_buffer: String = other_objects_to_send.pop_front()
		send_flags = ZMQSocket.SEND_FLAG_NONE if other_objects_to_send.is_empty() else ZMQSocket.SEND_FLAG_SNDMORE
		_bus.send_string(motor_data_buffer, send_flags)
	
	var response: PackedByteArray = []
	while response.is_empty() and initial_server_pid == _server_pid and not _was_simulation_aborted(simulation_id):
		response = _bus.receive_buffer(ZMQSocket.RECEIVE_FLAG_DONT_WAIT)
		_bus_lock.unlock(mutex_context)
		# This makes the query non blocking
		OS.delay_msec(100)
		_bus_lock.lock(mutex_context)
	_bus_lock.unlock(mutex_context)
	
	var did_server_crash: bool = initial_server_pid != _server_pid
	if did_server_crash:
		in_simulation_data.start_promise.fail.call_deferred(OPENMM_CRASH_MESSAGE)
		return
	
	if response == "err".to_utf8_buffer():
		_handle_request_error(in_simulation_data.start_promise, false)
		return
	
	assert(response == "Running".to_utf8_buffer(), "Unexpected response")
	
	# OpenMM server makes an early return, but server can crash before the first frame was received
	# Lets track this corner case
	while initial_server_pid == _server_pid and _is_simulation_starting(simulation_id) and not _was_simulation_aborted(simulation_id):
		# This makes the query non blocking
		OS.delay_msec(100)
	did_server_crash = initial_server_pid != _server_pid
	if did_server_crash:
		in_simulation_data.start_promise.fail.call_deferred(OPENMM_CRASH_MESSAGE)
		return
	
	if _was_simulation_aborted(simulation_id):
		in_simulation_data.start_promise.fulfill.call_deferred(false)


func _is_simulation_starting(in_simulation_id: int) -> bool:
	_subscription_thread_lock.lock("_is_simulation_starting")
	var data: SimulationData = _running_simulations.get(in_simulation_id, null)
	var starting: bool = true if data == null else data.is_being_requested()
	_subscription_thread_lock.unlock("_is_simulation_starting")
	return starting


func _was_simulation_aborted(in_simulation_id: int) -> bool:
	_subscription_thread_lock.lock("_was_simulation_aborted")
	var data: SimulationData = _running_simulations.get(in_simulation_id, null)
	var aborted: bool = true if data == null else data.was_aborted()
	_subscription_thread_lock.unlock("_was_simulation_aborted")
	return aborted


func _abort_simulation_on_thread(in_simulation_id: int, out_abort_promise: Promise) -> void:
	const mutex_context: String = "OpenMM::_abort_simulation_on_thread"
	var initial_server_pid: int = 0
	while initial_server_pid <= 0:
		OS.delay_msec(100)
		initial_server_pid = _server_pid
	_bus_lock.lock(mutex_context)
	_bus.send_string(ServerCommands.ABORT_SIMULATION, ZMQSocket.SEND_FLAG_SNDMORE)
	var id_bytes := PackedByteArray()
	id_bytes.resize(8)
	id_bytes.encode_s64(0, in_simulation_id)
	_bus.send_buffer(id_bytes)
	
	var response: PackedByteArray = []
	while response.is_empty() and initial_server_pid == _server_pid:
		response = _bus.receive_buffer(ZMQSocket.RECEIVE_FLAG_DONT_WAIT)
		_bus_lock.unlock(mutex_context)
		# This makes the query non blocking
		OS.delay_msec(100)
		_bus_lock.lock(mutex_context)
	_bus_lock.unlock(mutex_context)
	var did_server_crash: bool = initial_server_pid != _server_pid
	if did_server_crash:
		# If server crashed, in practice simulation is no longer procesing, so it's a success
		out_abort_promise.fulfill.call_deferred(true)
		return
	
	if response != "ack".to_utf8_buffer():
		_subscription_thread_lock.lock(mutex_context)
		if in_simulation_id in _running_simulations:
			_running_simulations[in_simulation_id].abort()
		_subscription_thread_lock.unlock(mutex_context)
		_handle_request_error(out_abort_promise, false)
		return
	out_abort_promise.fulfill.call_deferred(true)


func _process_import_file_request_on_thread(out_payload: ImportFilePayload, out_promise: Promise) -> void:
	var mutex_context: String = "OpenMM::_process_import_file_request_on_thread"
	var messages: PackedStringArray = out_payload.to_multipart_message()
	var last: int = messages.size() - 1
	_bus_lock.lock(mutex_context)
	for i in range(messages.size()):
		var flag := ZMQSocket.SEND_FLAG_SNDMORE
		if i == last:
			flag = ZMQSocket.SEND_FLAG_NONE
		_bus.send_string(messages[i], flag)
	
	var buffer: PackedByteArray = _bus.receive_buffer()
	var atomic_numbers: PackedByteArray = []
	var positions: PackedVector3Array = []
	var bonds: PackedVector3Array = []
	if buffer == "err".to_utf8_buffer():
		_bus_lock.unlock(mutex_context)
		_handle_request_error(out_promise, ImportFileResult.new(out_payload, atomic_numbers, positions, bonds))
		return
	
	# First frame corresponds to atomic nombers, encoded as uint8 bytes
	# atom.atomic_number = chk[0]
	atomic_numbers = buffer.duplicate()
	
	# Second frame corresponds to positions, encoded as array of 64bits floats
	assert(_bus.has_more())
	buffer = _bus.receive_buffer()
	var float_array: PackedFloat64Array = buffer.to_float64_array()
	for i in range(0, float_array.size(), 3):
		positions.push_back(Vector3(float_array[i], float_array[i+1], float_array[i+2]))
	
	# Third frame are bonds, encoded in chunkscomposed of
	# (atom_1: uint32, atom_2: uint32, bond_order: uint8)
	assert(_bus.has_more())
	buffer = _bus.receive_buffer()
	_bus_lock.unlock(mutex_context)
	var pos: int = 0
	var bond_chunk_size: int = 4 + 4 + 1 # size in bytes
	while pos < buffer.size():
		var atom_1: int = buffer.decode_u32(pos)
		var atom_2: int = buffer.decode_u32(pos+4)
		var bond_order: int = buffer.decode_u8(pos+8)
		bonds.push_back(Vector3i(atom_1, atom_2, bond_order))
		pos += bond_chunk_size
	
	# End of stream
	assert(!_bus.has_more())
	
	var result := ImportFileResult.new(out_payload, atomic_numbers, positions, bonds)
	
	if _PRINT_REQUEST_AND_RESPONSE:
		print_rich("[color=green] Imported file containing %d Atoms and %d bonds[/color]" % [result.atoms_count, result.bonds_count])
	
	out_promise.fulfill.call_deferred(result)


func _process_export_file_request_on_thread(in_file_path: String, out_payload: OpenMMPayload, out_promise: Promise) -> void:
	const mutex_context: String = "OpenMM::_process_export_file_request_on_thread"
	_bus_lock.lock(mutex_context)
	_bus.send_string(ServerCommands.EXPORT, ZMQSocket.SEND_FLAG_SNDMORE)
	_bus.send_string(in_file_path, ZMQSocket.SEND_FLAG_SNDMORE)
	var forcefield_list: String = ";".join(out_payload.forcefield_files)
	_bus.send_string(forcefield_list, ZMQSocket.SEND_FLAG_SNDMORE)
	_bus.send_buffer(out_payload.header, ZMQSocket.SEND_FLAG_SNDMORE)
	_bus.send_buffer(out_payload.topology, ZMQSocket.SEND_FLAG_SNDMORE)
	_bus.send_buffer(out_payload.state, ZMQSocket.SEND_FLAG_NONE)
	var response: PackedByteArray = _bus.receive_buffer()
	_bus_lock.unlock(mutex_context)
	if response == "err".to_utf8_buffer():
		_handle_request_error(out_promise, null) # TMP
		return
	out_promise.fulfill.call_deferred(OK)


func _handle_request_error(
			out_promise: Promise, out_fallback_result: Variant = null,
			out_bus_mutex: TrackableMutex = _bus_lock, out_bus: ZMQSocket = _bus) -> void:
	const mutex_context: String = "OpenMM::_handle_request_error"
	out_bus_mutex.lock(mutex_context)
	if out_bus.has_more():
		var openff_atom_map_buffer: PackedByteArray = out_bus.receive_buffer()
		var openff_to_zmq_atom_id: Dictionary = {
		#	openff_atom_id<int> = zmq_atom_id<int>
		}
		for seek: int in range(0, openff_atom_map_buffer.size(), 8):
			var openff_atom_id: int = openff_atom_map_buffer.decode_s32(seek)
			var request_atom_id: int = openff_atom_map_buffer.decode_s32(seek+4)
			openff_to_zmq_atom_id[openff_atom_id] = request_atom_id
		var messages: PackedStringArray = out_bus.receive_multipart_string()
		out_bus_mutex.unlock(mutex_context)
		if _PRINT_REQUEST_AND_RESPONSE:
			print_rich("[color=red] Error:[/color]")
			for msg in messages:
				for line in msg.split("\n", false):
					line = line.lstrip(" \t").rstrip(" \t")
					if !line.is_empty():
						print_rich("[color=red]\t%s[/color]" % line)
		# HACK: we need to make this information available, but we dont have a better channel
		# unless someone has a better idea let's use the meta properties of the promise
		out_promise.set_meta(&"openff_to_zmq_atom_id", openff_to_zmq_atom_id)
		out_promise.fail.call_deferred("\n".join(messages), out_fallback_result)
	else:
		if _PRINT_REQUEST_AND_RESPONSE:
			print_rich("[color=red]Error: Failed request[/color]")
		out_promise.fail.call_deferred("Failed request", out_fallback_result)
	out_bus_mutex.unlock(mutex_context)


func _dispose_thread_when_done(out_promise: Promise, out_thread: Thread) -> void:
	await out_promise.wait_for_fulfill()
	out_thread.wait_to_finish()
	_threads.erase(out_thread)


func _create_payload(
			in_workspace_context: WorkspaceContext,
			in_selection_only: bool,
			in_virtual_objects: bool,
			in_include_springs: bool,
			in_lock_atoms: bool,
			in_passivate_molecules: bool,
			in_nudge_atoms_fix: bool = false) -> OpenMMPayload:
	var structure_contexts: Array[StructureContext] = in_workspace_context.get_all_structure_contexts()
	var virtual_object_contexts: Array[StructureContext] = structure_contexts.filter(_is_virtual_object_context)
	if in_selection_only:
		structure_contexts = structure_contexts.filter(_has_selected_atoms)
	var payload: OpenMMPayload = OpenMMPayload.new(in_workspace_context.workspace)
	payload.nudge_atoms_fix_enabled = in_nudge_atoms_fix
	payload.lock_atoms = in_lock_atoms
	payload.passivate_molecules = in_passivate_molecules
	payload.forcefield_files = [in_workspace_context.workspace.simulation_settings_forcefield]
	var extension: String = in_workspace_context.workspace.simulation_settings_forcefield_extension
	if not extension.is_empty():
		payload.forcefield_files.push_back(extension)
	for context: StructureContext in structure_contexts:
		var structure: NanoStructure = context.nano_structure
		if structure is AtomicStructure:
			var atom_ids: PackedInt32Array = context.nano_structure.get_valid_atoms()
			var bond_ids: PackedInt32Array = context.nano_structure.get_valid_bonds()
			var springs_ids: PackedInt32Array = context.nano_structure.springs_get_all()
			if in_selection_only:
				atom_ids = context.get_selected_atoms()
				bond_ids = context.get_selected_bonds()
				springs_ids = []
				for spring_id: int in context.get_selected_springs():
					# Only add the spring if the atom is also selected
					if structure.spring_get_atom_id(spring_id) in atom_ids:
						springs_ids.push_back(spring_id)
			payload.add_structure(structure, atom_ids, bond_ids)
		
			if in_include_springs:
				payload.add_springs(context, springs_ids)
	
	if in_virtual_objects:
		for context: StructureContext in virtual_object_contexts:
			if context.nano_structure is NanoShape:
				payload.add_shape(context.nano_structure)
			elif context.nano_structure is NanoVirtualMotor:
				payload.add_motor(context.nano_structure)
			elif context.nano_structure is NanoVirtualAnchor:
				# Anchors are added on demand when adding Springs. Skip
				continue
	return payload


func _has_selected_atoms(in_structure_context: StructureContext) -> bool:
	return in_structure_context.is_any_atom_selected()


func _has_visible_atoms(in_structure_context: StructureContext) -> bool:
	return in_structure_context.nano_structure.get_valid_atoms().size() > 0


func _is_virtual_object_context(in_structure_context: StructureContext) -> bool:
	return in_structure_context.nano_structure.is_virtual_object()


func _notification(what: int) -> void:
	const mutex_context: String = "OpenMM::_notification::NOTIFICATION_PREDELETE"
	if what in [NOTIFICATION_PREDELETE] and _bus != null:
		if is_instance_valid(_bus_thread):
			_bus_lock.lock(mutex_context)
			_bus.send_string(ServerCommands.QUIT)
			var _acknowledge_quit: PackedStringArray = _bus.receive_multipart_string()
			_bus_lock.unlock(mutex_context)
		_dispose_bus_threads()
		_bus.close()
		_bus = null
		_subscription_bus.close()
		_subscription_bus = null

func _format_server_stdout(stdout: Array) -> Array:
	var stdout_str: String = "\n".join(stdout).replace("\r\n", "\n").replace("\t", ">>  ")
	var style_change: Dictionary = {
		'[95m': "[color=magenta]", #HEADER
		'[94m': "[color=dodger_blue]",    #OKBLUE
		'[96m': "[color=cyan]",    #OKCYAN
		'[92m': "[color=green]",   #OKGREEN
		'[93m': "[color=yellow]",  #WARNING
		'[91m': "[color=red]",     #FAIL
		'[0m' : "[/color]",        #ENDC
	}
	for style: String in style_change.keys():
		stdout_str = stdout_str.replace(style, style_change[style])
	return stdout_str.split("\n")
