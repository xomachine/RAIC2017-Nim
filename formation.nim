from behavior import Behavior
from selection import Selection
from vehicles import Vehicles
from analyze import WorldState
from model.move import Move

type
  Formation* = object
    selection: Selection
    behaviors: seq[Behavior]
    pendingSelection: bool

proc newGroundFormation*(sel: Selection): Formation
proc newAerialFormation*(sel: Selection): Formation
proc tick*(self: var Formation, ws: WorldState, m: var Move)
proc empty*(self: Formation, vehicles: Vehicles): bool

from together_behavior import initTogetherBehavior
from behavior import BehaviorStatus
from selection import select, SelectionStatus
from model.action_type import ActionType
from tables import `[]`, contains

proc newGroundFormation(sel: Selection): Formation =
  result.selection = sel
  result.behaviors = @[
    initTogetherBehavior(sel),
  ]
proc newAerialFormation(sel: Selection): Formation =
  result.selection = sel
  result.behaviors = @[
    initTogetherBehavior(sel)
  ]

proc empty(self: Formation, vehicles: Vehicles): bool =
  if self.selection.counter == self.selection.steps.len():
    not (self.selection.group in vehicles.byGroup) or
      card(vehicles.byGroup[self.selection.group]) == 0
  else: false

proc tick(self: var Formation, ws: WorldState, m: var Move) =
  var resetFlag = false
  if self.pendingSelection:
    let status = self.selection.select(ws, m)
    case status
    of SelectionStatus.done:
      self.pendingSelection = false
      return
    of SelectionStatus.needMoreTicks:
      return
    else: discard
  for b in self.behaviors:
    if resetFlag:
      b.reset()
      continue
    let state = b.tick(ws)
    case state
    of BehaviorStatus.hold:
      resetFlag = true
    of BehaviorStatus.act:
      let status = self.selection.select(ws, m)
      resetFlag = true
      case status
      of SelectionStatus.alreadyDone:
        b.action(ws, m)
      of SelectionStatus.needMoreTicks:
        self.pendingSelection = true
      else: discard
    else: discard
