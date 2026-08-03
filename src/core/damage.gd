class_name Damage
extends RefCounted

## Blast damage model.
##
## Linear falloff from the centre out to BLAST_RADIUS. Linear rather than
## quadratic on purpose: near misses need to be worth something, otherwise the
## only viable play is a pixel-perfect direct hit and ranging shots feel wasted.

const BLAST_RADIUS := 96.0   ## px, beyond this a shot does nothing
const MAX_DAMAGE := 42.0     ## dealt at the centre of the blast
const CRATER_RADIUS := 72.0  ## px, how much ground a shot removes

## Damage dealt to a target `distance` px from the impact point.
static func at_distance(distance: float) -> int:
	if distance >= BLAST_RADIUS:
		return 0
	var falloff := 1.0 - distance / BLAST_RADIUS
	return int(round(MAX_DAMAGE * falloff))
