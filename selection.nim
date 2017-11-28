from model.move import Move
from model.vehicle_type import VehicleType
from model.action_type import ActionType
from enhanced import Group
from analyze import WorldState, getFreeGroup
from utils import Area

type
  SelectionStatus* {.pure.} = enum
    alreadyDone
    done
    needMoreTicks
  Step* = object
    act: ActionType
    area: Area
    vtype: VehicleType
    group: Group
  Selection* = tuple
    group: Group
    steps: seq[Step]
    counter: Natural

proc initSelection*(ws: var WorldState, steps: seq[Step]): Selection
proc select*(self: var Selection, ws: WorldState, m: var Move): SelectionStatus
proc make(s: Step, m: var Move)

from tables import `[]`

proc make(s: Step, m: var Move) =
  m.action = s.act
  m.left = s.area.left
  m.right = s.area.right
  m.top = s.area.top
  m.bottom = s.area.bottom
  m.vehicleType = s.vtype
  m.group = s.group.int32

proc initSelection(ws: var WorldState, steps: seq[Step]): Selection =
  result.group = ws.getFreeGroup()
  result.counter = 0
  result.steps = steps & Step(act: ActionType.ASSIGN, group: result.group)

proc isSelected(self: Selection, ws: WorldState): bool =
  card(ws.vehicles.byGroup[self.group] *
       ws.vehicles.selected) == card(ws.vehicles.byGroup[self.group])

proc select(self: var Selection, ws: WorldState, m: var Move): SelectionStatus =
  if self.isSelected(ws):
    SelectionStatus.alreadyDone
  elif self.counter == self.steps.len():
    m.group = self.group.int32
    SelectionStatus.done
  else:
    self.steps[self.counter].make(m)
    inc(self.counter)
    SelectionStatus.needMoreTicks
