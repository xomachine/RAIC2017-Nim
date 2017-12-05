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
    of PBRType.addFormation:
      formation*: Formation
    of PBRType.addPBehavior:
      behavior*: PlayerBehavior
    else: discard
  Action* = proc (ws: WorldState, gc: var GroupCounter, m: var Move): PBResult
  PlayerBehavior* = tuple
    tick: Action

