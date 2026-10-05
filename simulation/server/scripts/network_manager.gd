# NETWORK MANAGER is responsible for establishing and maintaining
# connection to server. it can hook up to any valid mesh constructor
# that is in the same scene which is a sibling to it.
#
# Network Manager will emit signals of its events, which
# mesh constructors will listen for.
#

extends Node
# ---------------------------------------
# EXPORTS
# ---------------------------------------

## the url of the server simulation.
@export var url: String = "ws://127.0.0.1:8000/ws/simulation"

# b
@export var mesh_constructor: PackedScene = PackedScene.new()

# ---------------------------------------
# CONSTANTS & VARIABLES
# ---------------------------------------
const RECONNECT_DELAY := 2.0
var ws := WebSocketPeer.new()
var connected := false
# Grid layout settings
const BOATS_PER_ROW := 5
const SPACING_X := 5.0
const SPACING_Z := 5.0
var spawned_boats: Dictionary = {}

const ROTATION_SPEED := 1.8 # Radians per second
var active_rotations: Dictionary = {} # boat_id (String) -> bool
