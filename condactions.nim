from actions import Action
from enhanced import VehicleId
from sets import HashSet

proc wait*(ticks: Natural): Action
proc atMoveEnd*(group: HashSet[VehicleId]): Action

from model.move import Move
from analyze import WorldState
from actions import ActionStatus
from groupcounter import GroupCounter
from sets import `*`, card

proc wait(ticks: Natural): Action =
  var targettick = -1
  proc inner(ws: WorldState, gc: var GroupCounter, m: var Move): ActionStatus =
    if unlikely(targettick < 0):
      targettick = ws.world.tickIndex + ticks
    elif ws.world.tickIndex > targettick:
      return ActionStatus.next
    return ActionStatus.skip
  return inner

proc atMoveEnd(group: HashSet[VehicleId]): Action =
  var ticks = 0
  proc inner(ws: WorldState, gc: var GroupCounter, m: var Move): ActionStatus =
    let v = ws.vehicles
    let amountUpdated = card(group * v.updated)
    if amountUpdated > 0: ticks = 0
    else: ticks += 1
    if ticks > 1: ActionStatus.next
    else: ActionStatus.skip
  return inner
