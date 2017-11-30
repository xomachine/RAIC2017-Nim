from model.move import Move
from analyze import WorldState
from formation import Formation
from groupcounter import GroupCounter

type
  PBRType* {.pure.} = enum
    empty
    addFormation
    addPBehavior
    removeMe
    priority
  PBResult* = object
    case kind*: PBRType
    of addFormation:
      formation*: Formation
    of addPBehavior:
      behavior*: PlayerBehavior
    else: discard
  PlayerBehavior* = tuple
    tick: proc (ws: WorldState, gc: var GroupCounter, m: var Move): PBResult

