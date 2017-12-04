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

from tables import `[]`, contains
from fastset import `==`, card
from groupcounter import GroupCounter
from actions import ActionStatus, group
from model.action_type import ActionType
from utils import debug
from vehicles import resolve, toGroup

proc initSelection(group: Group, steps: seq[Action]): Selection =
  result.group = group
  result.counter = 0
  if not steps.isNil():
    result.steps = steps & group(result.group)

proc isSelected(self: Selection, ws: WorldState): bool =
  if self.group in ws.vehicles.byGroup:
    ws.vehicles.selected == ws.vehicles.byGroup[self.group]
  else: false

proc select(self: var Selection, ws: WorldState, m: var Move): SelectionStatus =
  debug("Selecting group " & $self.group)
  if self.isSelected(ws):
    debug("Group " & $self.group & " is already selected!")
    debug("Group " & $self.group & " contains " & $ws.vehicles.byGroup[self.group].card)
    SelectionStatus.alreadyDone
  elif self.counter == self.steps.len():
    debug("Selection by group " & $self.group)
    m.action = ActionType.CLEAR_AND_SELECT
    m.group = self.group.int32
    SelectionStatus.done
  else:
    debug("Reproducing selection steps " & $self.group)
    var gc: GroupCounter
    let status = self.steps[self.counter](ws, gc, m)
    inc(self.counter)
    if status == ActionStatus.next and m.action == ActionType.NONE:
      return self.select(ws, m)
    SelectionStatus.needMoreTicks
