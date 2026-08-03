class_name Knockback
extends RefCounted

## Blast knockback: how far a nearby catapult gets shoved sideways.
##
## Pure and node-free, same pattern as Ballistics — a static function so it
## can be unit tested without spinning up a scene tree.

const RADIUS := 160.0   ## px, beyond this a blast cannot move a catapult
const MAX_PUSH := 60.0  ## px, sideways shift for a blast landing exactly on the catapult

## Linear falloff: full MAX_PUSH at distance 0, zero at and beyond RADIUS.
static func push_for(distance: float) -> float:
	return MAX_PUSH * clampf(1.0 - distance / RADIUS, 0.0, 1.0)
