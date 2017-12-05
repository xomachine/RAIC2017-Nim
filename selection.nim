from model.move import Move
from enhanced import Group
from analyze import WorldState

type
  SelectionStatus* {.pure.} = enum
    alreadyDone
    done
    needMoreTicks

proc select*(self: Group, ws: WorldState, m: var Move): SelectionStatus

from tables import `[]`, contains
from fastset import `==`, card
from groupcounter import GroupCounter
from model.action_type import ActionType
from utils import debug
from vehicles import resolve, toGroup

proc isSelected(self: Group, ws: WorldState): bool =
  if self in ws.vehicles.byGroup:
    ws.vehicles.selected == ws.vehicles.byGroup[self]
  else: false

proc select(self: Group, ws: WorldState, m: var Move): SelectionStatus =
  debug("Selecting group " & $self)
  if self.isSelected(ws):
    debug("Group " & $self & " is already selected!")
    debug("Group " & $self & " contains " &
          $ws.vehicles.byGroup[self].card)
    SelectionStatus.alreadyDone
  else:
    debug("Selection by group " & $self)
    m.action = ActionType.CLEAR_AND_SELECT
    m.group = self.int32
    SelectionStatus.done
