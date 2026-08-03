class_name Damage
extends RefCounted

## Blast contact model.
##
## Two hits and a machine is out — a graze at the edge of the blast counts the
## same as a bullseye, which is what makes "did it land close enough" the only
## question worth asking rather than a race to stack fractional damage.

const BLAST_RADIUS := 96.0   ## px, beyond this a shot does nothing
const CRATER_RADIUS := 72.0  ## px, how much ground a shot removes

## Whether a target `distance` px from the impact point counts as struck.
static func is_hit(distance: float) -> bool:
	return distance < BLAST_RADIUS
