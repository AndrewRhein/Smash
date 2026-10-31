class_name ControllerAssignment
extends RefCounted
## Which physical controller drives which player.
##
## Godot joypad device ids are not guaranteed to be 0 and 1 (they can change on
## reconnect, and more than two pads may be connected), so players are mapped
## to devices here instead of binding fixed device ids into the InputMap.
##
## Rules: connected pads fill empty player slots in ascending device order;
## an assigned pad keeps its slot until it disconnects; extra pads are unused
## (and still navigate menus). Assignments can be changed from the Controllers
## screen (swap / cycle). Hot-plugging is handled automatically.

const PLAYER_COUNT := 4

static var _slots: Dictionary = {}       # player_id -> device id
static var _known_pads: Array = []
static var _manual: bool = false         # true once a test pinned slots


## Detect hot-plugging by comparing the connected-pad list (no signal
## connection, so nothing dangles at shutdown).
static func _ensure() -> void:
	var pads := Input.get_connected_joypads()
	if pads != _known_pads:
		refresh()


## Re-evaluate after connects/disconnects: free slots of missing pads, then
## give unassigned pads to empty slots.
static func refresh() -> void:
	var pads := Input.get_connected_joypads()
	_known_pads = pads.duplicate()
	pads.sort()
	if not _manual:
		for player_id in _slots.keys():
			if not pads.has(_slots[player_id]):
				_slots.erase(player_id)
	for device in pads:
		if _slots.values().has(device):
			continue
		for player_id in range(1, PLAYER_COUNT + 1):
			if not _slots.has(player_id):
				_slots[player_id] = device
				break


## Device id for a player, or -1 if no controller is assigned.
static func device_for(player_id: int) -> int:
	_ensure()
	return int(_slots.get(player_id, -1))


## Pin a device to a player (used by the Controllers screen and tests). A
## device already used by the other player is swapped over.
static func assign(player_id: int, device: int) -> void:
	_ensure()
	for other in _slots.keys():
		if other != player_id and _slots[other] == device:
			if _slots.has(player_id):
				_slots[other] = _slots[player_id]
			else:
				_slots.erase(other)
	if device < 0:
		_slots.erase(player_id)
	else:
		_slots[player_id] = device


static func swap_players() -> void:
	_ensure()
	var a: int = _slots.get(1, -1)
	var b: int = _slots.get(2, -1)
	_slots.erase(1)
	_slots.erase(2)
	if b >= 0:
		_slots[1] = b
	if a >= 0:
		_slots[2] = a


## Tests: forget everything and stop auto-releasing pinned (unconnected) pads.
static func reset(manual: bool = false) -> void:
	_slots.clear()
	_manual = manual
	if not manual:
		refresh()


static func describe(player_id: int) -> String:
	var device := device_for(player_id)
	if device < 0:
		return "Keyboard only"
	var name := Input.get_joy_name(device)
	return "%s (pad %d)" % [name if name != "" else "Controller", device]
