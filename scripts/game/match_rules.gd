extends RefCounted
class_name MatchRules

## Shared gameplay constants. The server is the only authority that applies them
## to hits, progress, and movement. Clients use the same numbers for prediction.

const WALK_SPEED := 3.35
const RUN_SPEED := 6.15
const CROUCH_SPEED := 1.65
const JUMP_VELOCITY := 5.6
const GRAVITY := 18.5
const ACCEL := 24.0
const AIR_ACCEL := 8.0
const INTERACT_DISTANCE := 2.75
const ESCAPE_DISTANCE := 3.2
const FIRE_INTERVAL := 0.38
const FIRE_RANGE := 42.0
const FIRE_DAMAGE := 34
const MAX_HEALTH := 100
const MATCH_SECONDS := 240.0
const HOLD_SECONDS := 18.0
const HOLD_SECONDS_TEST := 3.0
const BLEED_SECONDS := 12.0
const MAX_PLAYERS := 8
const INPUT_TIMEOUT := 0.35
const RECONNECT_SECONDS := 90.0
const STAND_HEIGHT := 1.7
const CROUCH_HEIGHT := 1.05
const BODY_RADIUS := 0.32

const VAULT := Vector3(20, 0, -18)
const VAULT_STAND := Vector3(20, 0.05, -17.05)
const ESCAPE := Vector3(0, 0, 28)
const POLICE_SPAWN := Vector3(-12, 0.05, 1.5)
const CRIMINAL_SPAWN := Vector3(20, 0.05, 0)
const BANK_DOOR := Vector3(20, 0.05, -6.6)
const BANK_INSIDE := Vector3(20, 0.05, -10.2)

const LAYER_WORLD := 1
const LAYER_ACTOR := 2

enum Team { NONE = -1, POLICE = 0, CRIMINAL = 1 }
enum Phase { WAITING, ACTIVE, CRIMINAL_WIN, POLICE_WIN }

static func finitef(value: float, fallback: float = 0.0) -> float:
	if is_nan(value) or is_inf(value):
		return fallback
	return value

static func clamp_axes(x: float, z: float) -> Vector2:
	x = finitef(x)
	z = finitef(z)
	var v := Vector2(x, z)
	if v.length() > 1.0:
		v = v.normalized()
	return v
