from enhanced import Group
from pbehavior import Action, PBResult, PBRType, PlayerBehavior
from analyze import WorldState
from groupcounter import GroupCounter
from model.move import Move
from formation import newAerialFormation, newGroundFormation
from utils import debug

proc addFormation*(g: Group, aerial: bool): Action =
  proc do_add(ws: WorldState, gc: var GroupCounter, m: var Move): PBResult =
    let theformation =
      if aerial: newAerialFormation(g)
      else: newGroundFormation(g)
    debug("Added formation for group: " & $g)
    PBResult(kind: PBRType.addFormation, formation: theformation)
  return do_add

proc addPBehavior*(pb: PlayerBehavior): Action =
  proc do_add(ws: WorldState, gc: var GroupCounter, m: var Move): PBResult =
    PBResult(kind: PBRType.addPBehavior, behavior: pb)
  return do_add
