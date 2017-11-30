from analyze import WorldState
from groupcounter import GroupCounter
from utils import Point
from model.move import Move

type
  ActionStatus* {.pure.} = enum
    skip
    take
    next
  Action* =
    proc(ws: WorldState, gc: var GroupCounter, m: var Move): ActionStatus

proc move*(shift: Point, maxspeed: float64): Action
proc scale*(center: Point, factor,maxspeed: float64): Action
proc rotate*(center: Point, angle, maxspeed: float64): Action

from model.action_type import ActionType
from model.vehicle_type import VehicleType
from enhanced import Group
from utils import Area
import macros

macro genSelectsNGroups(): untyped =
  let names = [!"newSelection", !"addToSelection", !"deselect",
               !"group", !"ungroup", !"disband"]
  let actions = [ActionType.CLEAR_AND_SELECT,
                 ActionType.ADD_TO_SELECTION,
                 ActionType.DESELECT,
                 ActionType.ASSIGN,
                 ActionType.DISMISS,
                 ActionType.DISBAND]
  result = newStmtList()
  for i in 0..<names.len():
    let name = names[i]
    let action = newIntLitNode(actions[i].ord)
    result.add quote do:
      proc `name`*(group: Group): Action =
        proc innerproc(ws: WorldState, gc: var GroupCounter, m: var Move): ActionStatus =
          m.action = `action`.ActionType
          m.group = group.int32
        innerproc
    if i > 2: continue
    result.add quote do:
      proc `name`*(area: Area, vtype: VehicleType = VehicleType.UNKNOWN): Action =
        proc innerproc(ws: WorldState, gc: var GroupCounter, m: var Move): ActionStatus =
          m.action = `action`.ActionType
          m.vehicleType = vtype
          m.left = area.left
          m.right = area.right
          m.top = area.top
          m.bottom = area.bottom
        innerproc

genSelectsNGroups()

# TODO!
proc move(shift: Point, maxspeed: float64): Action =
  discard
proc scale(center: Point, factor,maxspeed: float64): Action =
  discard
proc rotate(center: Point, angle, maxspeed: float64): Action =
  discard
