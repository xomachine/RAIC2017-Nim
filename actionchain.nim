from model.move import Move
from analyze import WorldState
from pbehavior import PlayerBehavior
from enhanced import Group, VehicleId, FacilityId
from groupcounter import GroupCounter
from utils import Area, Point
from actions import Action

type
  ActionChain* = seq[Action]

proc initActionChain*(actions: ActionChain): PlayerBehavior

from model.action_type import ActionType
from pbehavior import PBResult, PBRType
from actions import ActionStatus
from utils import debug

proc initActionChain(actions: ActionChain): PlayerBehavior =
  var counter = 0
  result.tick =
    proc (ws: WorldState, gc: var GroupCounter, m: var Move): PBResult =
      while counter < actions.len():
        let status = actions[counter](ws, gc, m)
        debug($actions.len() & ": Action " & $counter & " returned " & $status)
        case status
        of ActionStatus.skip:
          return PBResult(kind: PBRType.empty)
        of ActionStatus.take:
          counter += 1
          return PBResult(kind: PBRType.priority)
        of ActionStatus.next:
          counter += 1
      return PBResult(kind: PBRType.removeMe)

