from analyze import WorldState
from groupcounter import GroupCounter
from utils import Point
from model.move import Move

type
  ActionStatus* {.pure.} = enum
    take
    skip
    next
  Action* =
    proc(ws: WorldState, gc: var GroupCounter, m: var Move): ActionStatus

proc actmove*(shift: Point, maxspeed: float64 = 0): Action
proc scale*(center: Point, factor, maxspeed: float64 = 0): Action
proc rotate*(center: Point, angle, maxspeed: float64 = 0): Action

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
        proc r(ws: WorldState, gc: var GroupCounter, m: var Move): ActionStatus =
          m.action = `action`.ActionType
          m.group = group.int32
          ActionStatus.take
        r
    if i > 2: continue
    result.add quote do:
      proc `name`*(a: Area, vt: VehicleType = VehicleType.UNKNOWN): Action =
        proc r(ws: WorldState, gc: var GroupCounter, m: var Move): ActionStatus =
          m.action = `action`.ActionType
          m.vehicleType = vt
          m.left = a.left
          m.right = a.right
          m.top = a.top
          m.bottom = a.bottom
          ActionStatus.take
        r

genSelectsNGroups()

proc actmove(shift: Point, maxspeed: float64 = 0): Action =
  proc i_move(ws: WorldState, gc: var GroupCounter, m: var Move): ActionStatus =
    m.action = ActionType.MOVE
    m.x = shift.x
    m.y = shift.y
    m.maxspeed = maxspeed
    ActionStatus.take
  return imove
proc scale(center: Point, factor, maxspeed: float64 = 0): Action =
  proc inner(ws: WorldState, gc: var GroupCounter, m: var Move): ActionStatus =
    m.action = ActionType.SCALE
    m.x = center.x
    m.y = center.y
    m.factor = factor
    m.maxspeed = maxspeed
    ActionStatus.take
  return inner
proc rotate(center: Point, angle, maxspeed: float64 = 0): Action =
  proc inner(ws: WorldState, gc: var GroupCounter, m: var Move): ActionStatus =
    m.action = ActionType.ROTATE
    m.x = center.x
    m.y = center.y
    m.angle = angle
    m.maxAngularSpeed = maxspeed
    ActionStatus.take
  return inner
