from model.move import Move
from analyze import WorldState

type
  PlayerBehavior* = tuple
    tick: proc (ws: WorldState, m: var Move)

