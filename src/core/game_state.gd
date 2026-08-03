class_name GameState
extends RefCounted

## Match bookkeeping: who is playing, whose turn it is, who has won.
##
## Players live in an ordered array, never as `player_a`/`player_b`. v1 ships
## two, but the reference mockups show four banners and turn rotation over a
## list costs nothing now and is a rewrite later.

const MAX_HP := 100
const MAX_STEPS := 3        ## repositioning allowance per turn, either direction
const STEP_PIXELS := 26.0   ## ground distance covered by one step

class Player extends RefCounted:
	var name: String
	var color: Color
	var hp: int = MAX_HP
	var angle: float = 45.0    ## degrees, 0..90
	var power: float = 60.0    ## percent, 0..100
	var facing: int = 1        ## +1 aims right, -1 aims left
	var catapult: Node2D = null

	func _init(p_name: String, p_color: Color, p_facing: int) -> void:
		name = p_name
		color = p_color
		facing = p_facing

	func is_alive() -> bool:
		return hp > 0

var players: Array[Player] = []
var current_index: int = 0
var round_number: int = 1

func add_player(name: String, color: Color, facing: int) -> Player:
	var p := Player.new(name, color, facing)
	players.append(p)
	return p

func current() -> Player:
	return players[current_index]

func living() -> Array[Player]:
	return players.filter(func(p: Player) -> bool: return p.is_alive())

## True once fewer than two players are still standing.
func is_over() -> bool:
	return living().size() <= 1

## The sole survivor, or null while the match is still running (or on a draw).
func winner() -> Player:
	var alive := living()
	return alive[0] if alive.size() == 1 else null

## Advance to the next living player, incrementing the round when the turn
## order wraps. Returns false if nobody can take a turn.
func advance_turn() -> bool:
	if is_over():
		return false
	for offset in range(1, players.size() + 1):
		var idx := (current_index + offset) % players.size()
		if players[idx].is_alive():
			if idx <= current_index:
				round_number += 1
			current_index = idx
			return true
	return false
