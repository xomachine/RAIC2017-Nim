from model.move import Move
from actions import Action
from enhanced import Group
from analyze import WorldState

type
  SelectionStatus* {.pure.} = enum
    alreadyDone
    done
    needMoreTicks
  Selection* = tuple
    group: Group
    steps: seq[Action]
    counter: Natural

proc initSelection*(group: Group, steps: seq[Action]): Selection
proc select*(self: var Selection, ws: WorldState, m: var Move): SelectionStatus

from tables import `[]`
from groupcounter import GroupCounter
from actions import ActionStatus, group
from model.action_type import ActionType

proc initSelection(group: Group, steps: seq[Action]): Selection =
  result.group = group
  result.counter = 0
  result.steps = steps & group(result.group)

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
    var gc: GroupCounter
    let status = self.steps[self.counter](ws, gc, m)
    inc(self.counter)
    if status == ActionStatus.next and m.action == ActionType.NONE:
      return self.select(ws, m)
    SelectionStatus.needMoreTicks
