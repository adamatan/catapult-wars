class_name Damage
extends RefCounted

## Blast contact model.
##
## A hit is binary — a graze at the edge of the blast counts the same as a
## bullseye, which is what makes "did it land close enough" the only question
## worth asking rather than a race to stack fractional damage.

## The sole threshold for losing a life: land within BLAST_RADIUS of a
## catapult and it is hit, full stop. It is deliberately wider than
## Catapult.HIT_RADIUS (36px) — HIT_RADIUS only decides when a flying stone
## stops and counts as a "direct hit" for the projectile's own purposes, and
## plays no part in is_hit below. So a shot that lands well short of a direct
## hit, anywhere inside these 96px, already costs a life: a near miss still
## injures. This is the one and only radius; a second, narrower band would
## just be a disguised way of shrinking BLAST_RADIUS, and would contradict
## the "a hit is binary" rule above.
const BLAST_RADIUS := 96.0   ## px, beyond this a shot does nothing
const CRATER_RADIUS := 72.0  ## px, how much ground a shot removes

## Whether a target `distance` px from the impact point counts as struck.
static func is_hit(distance: float) -> bool:
	return distance < BLAST_RADIUS
