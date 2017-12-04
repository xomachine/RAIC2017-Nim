from behavior import Behavior
from selection import Selection
from vehicles import Vehicles
from borders import Vertex
from utils import Point
from analyze import WorldState
from model.move import Move

type
  Formation* = object
    selection: Selection
    behaviors: seq[Behavior]
    pendingSelection: int
    aerial: bool

proc newGroundFormation*(sel: Selection): Formation
proc newAerialFormation*(sel: Selection): Formation
proc tick*(self: var Formation, ws: WorldState, m: var Move)
proc empty*(self: Formation, vehicles: Vehicles): bool

from utils import debug
from together_behavior import initTogetherBehavior
from capture import initCapture
from behavior import BehaviorStatus
from formation_info import updateFormationInfo, FormationInfo
from nukealert import initNukeAlert
from nuke import initNuke
from selection import select, SelectionStatus
from model.action_type import ActionType
from tables import `[]`, contains
from fastset import empty

proc newGroundFormation(sel: Selection): Formation =
  result.selection = sel
  result.pendingSelection = -1
  result.behaviors = @[
    initNukeAlert(),
    initTogetherBehavior(sel),
    initNuke(),
    initCapture()
  ]
proc newAerialFormation(sel: Selection): Formation =
  result.selection = sel
  result.pendingSelection = -1
  result.aerial = true
  result.behaviors = @[
    initNukeAlert(),
    initTogetherBehavior(sel),
    initNuke(),
  ]

proc empty(self: Formation, vehicles: Vehicles): bool =
  if self.selection.counter == self.selection.steps.len():
    not (self.selection.group in vehicles.byGroup) or
      vehicles.byGroup[self.selection.group].empty
  else: false

proc actOrSelect(self: var Formation, b: Behavior, ws: WorldState, fi: FormationInfo, m: var Move): bool =
  let status = self.selection.select(ws, m)
  case status
  of SelectionStatus.done, SelectionStatus.needMoreTicks:
    false
  else:
    b.action(ws, fi, m)
    self.pendingSelection = -1
    true


proc tick(self: var Formation, ws: WorldState, m: var Move) =
  var resetFlag = false
  let finfo = self.selection.group.updateFormationInfo(ws, self.aerial)
  if self.pendingSelection >= 0:
    if not self.actOrSelect(self.behaviors[self.pendingSelection], ws, finfo, m):
      return
  for i, b in self.behaviors.pairs():
    if resetFlag:
      b.reset()
      continue
    let state = b.tick(ws, finfo)
    case state
    of BehaviorStatus.hold:
      resetFlag = true
    of BehaviorStatus.act:
      if not self.actOrSelect(b, ws, finfo, m):
        self.pendingSelection = i
      resetFlag = true
    of BehaviorStatus.actUnselected:
      b.action(ws, finfo, m)
    else: discard
