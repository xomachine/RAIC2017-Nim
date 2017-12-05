from behavior import Behavior
from vehicles import Vehicles
from borders import Vertex
from utils import Point
from enhanced import Group
from analyze import WorldState
from model.move import Move

type
  Formation* = object
    selection: Group
    behaviors: seq[Behavior]
    pendingAction: int
    aerial: bool

proc newGroundFormation*(sel: Group): Formation
proc newAerialFormation*(sel: Group): Formation
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

proc newGroundFormation(sel: Group): Formation =
  result.selection = sel
  result.pendingAction = -1
  result.behaviors = @[
    initNukeAlert(),
    initTogetherBehavior(sel),
    initNuke(),
    initCapture()
  ]
proc newAerialFormation(sel: Group): Formation =
  result.selection = sel
  result.pendingAction = -1
  result.aerial = true
  result.behaviors = @[
    initNukeAlert(),
    initTogetherBehavior(sel),
    initNuke(),
  ]

proc empty(self: Formation, vehicles: Vehicles): bool =
  not (self.selection in vehicles.byGroup) or
    vehicles.byGroup[self.selection].empty

proc tick(self: var Formation, ws: WorldState, m: var Move) =
  var resetFlag = false
  let finfo = self.selection.updateFormationInfo(ws, self.aerial)
  if self.pendingAction >= 0:
    let behavior = self.behaviors[self.pendingAction]
    self.pendingAction = -1
    behavior.action(ws, finfo, m)
    if m.action != ActionType.NONE:
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
      if self.selection.select(ws, m) == SelectionStatus.alreadyDone:
        b.action(ws, finfo, m)
      else:
        self.pendingAction = i
      resetFlag = true
    of BehaviorStatus.actUnselected:
      b.action(ws, finfo, m)
    else: discard
