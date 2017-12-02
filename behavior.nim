from model.move import Move
from analyze import WorldState

type
  BehaviorStatus* {.pure.} = enum
    inactive
    hold
    act
    actUnselected
  Behavior* = object
    tick*: proc (ws: WorldState): BehaviorStatus {.closure.}
    action*: proc (ws: WorldState, m: var Move) {.closure.}
    reset*: proc() {.closure.}

