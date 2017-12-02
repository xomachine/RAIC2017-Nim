from behavior import Behavior
from selection import Selection
from vehicles import Vehicles
from analyze import WorldState
from model.move import Move

type
  Formation* = object
    selection: Selection
    behaviors: seq[Behavior]
    pendingSelection: int

proc newGroundFormation*(sel: Selection): Formation
proc newAerialFormation*(sel: Selection): Formation
proc tick*(self: var Formation, ws: WorldState, m: var Move)
proc empty*(self: Formation, vehicles: Vehicles): bool

from utils import debug
from together_behavior import initTogetherBehavior
from behavior import BehaviorStatus
from nukealert import initNukeAlert
from nuke import initNuke
from selection import select, SelectionStatus
from model.action_type import ActionType
from tables import `[]`, contains
from sets import card

proc newGroundFormation(sel: Selection): Formation =
  result.selection = sel
  result.pendingSelection = -1
  result.behaviors = @[
    initNukeAlert(sel.group),
    initTogetherBehavior(sel),
    initNuke(sel.group),
  ]
proc newAerialFormation(sel: Selection): Formation =
  result.selection = sel
  result.pendingSelection = -1
  result.behaviors = @[
    initNukeAlert(sel.group),
    initTogetherBehavior(sel),
    initNuke(sel.group),
  ]

proc empty(self: Formation, vehicles: Vehicles): bool =
  if self.selection.counter == self.selection.steps.len():
    not (self.selection.group in vehicles.byGroup) or
      card(vehicles.byGroup[self.selection.group]) == 0
  else: false

proc actOrSelect(self: var Formation, b: Behavior, ws: WorldState, m: var Move): bool =
  let status = self.selection.select(ws, m)
  case status
  of SelectionStatus.done, SelectionStatus.needMoreTicks:
    false
  else:
    b.action(ws, m)
    self.pendingSelection = -1
    true


proc tick(self: var Formation, ws: WorldState, m: var Move) =
  var resetFlag = false
  if self.pendingSelection >= 0:
    if not self.actOrSelect(self.behaviors[self.pendingSelection], ws, m):
      return
  for i, b in self.behaviors.pairs():
    if resetFlag:
      b.reset()
      continue
    let state = b.tick(ws)
    case state
    of BehaviorStatus.hold:
      resetFlag = true
    of BehaviorStatus.act:
      if not self.actOrSelect(b, ws, m):
        self.pendingSelection = i
      resetFlag = true
    of BehaviorStatus.actUnselected:
      b.action(ws, m)
    else: discard
