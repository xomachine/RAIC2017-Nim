from pbehavior import Action
from enhanced import VehicleId
from fastset import FastSet

proc wait*(ticks: Natural): Action
proc atMoveEnd*(group: FastSet[VehicleId]): Action

from model.move import Move
from analyze import WorldState
from pbehavior import PBResult, PBRType
from groupcounter import GroupCounter
from fastset import `*`, card

proc wait(ticks: Natural): Action =
  var targettick = -1
  proc inner(ws: WorldState, gc: var GroupCounter, m: var Move): PBResult =
    if unlikely(targettick < 0):
      targettick = ws.world.tickIndex + ticks
    elif ws.world.tickIndex > targettick:
      return PBResult(kind: PBRType.priority)
    return PBResult(kind: PBRType.empty)
  return inner

proc atMoveEnd(group: FastSet[VehicleId]): Action =
  var ticks = 0
  proc inner(ws: WorldState, gc: var GroupCounter, m: var Move): PBResult =
    let v = ws.vehicles
    let amountUpdated = card(group * v.updated)
    if amountUpdated > 0: ticks = 0
    else: ticks += 1
    if ticks > 1: PBResult(kind: PBRType.priority)
    else: PBResult(kind: PBRType.empty)
  return inner
