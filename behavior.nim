from model.move import Move
from analyze import WorldState
from formation_info import FormationInfo

type
  BehaviorStatus* {.pure.} = enum
    inactive
    hold
    act
    actUnselected
  Behavior* = object
    tick*: proc (ws: WorldState, fi: FormationInfo): BehaviorStatus {.closure.}
    action*: proc (ws: WorldState, fi: FormationInfo, m: var Move) {.closure.}
    reset*: proc() {.closure.}

