from model.move import Move
from analyze import WorldState
from pbehavior import PlayerBehavior, Action
from enhanced import Group, VehicleId, FacilityId
from groupcounter import GroupCounter
from utils import Area, Point

type
  ActionChain* = seq[Action]

proc initActionChain*(actions: ActionChain): PlayerBehavior

from model.action_type import ActionType
from pbehavior import PBResult, PBRType
from utils import debug

proc initActionChain(actions: ActionChain): PlayerBehavior =
  var counter = 0
  result.tick =
    proc (ws: WorldState, gc: var GroupCounter, m: var Move): PBResult =
      while counter < actions.len():
        let status = actions[counter](ws, gc, m)
        debug($actions.len() & ": Action " & $counter & " returned " & $status)
        case status.kind
        of PBRType.priority:
          counter += 1
          if m.action != ActionType.NONE:
            return PBResult(kind: PBRType.priority)
        of PBRType.empty:
          return status
        else:
          counter += 1
          return status
      return PBResult(kind: PBRType.removeMe)

