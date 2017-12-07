from behavior import Behavior
from enhanced import Group


proc initNukeAlert*(): Behavior

from analyze import WorldState, Players
from behavior import BehaviorStatus
from vehicles import resolve, toGroup
from utils import areaFromUnits, inArea, debug, getSqDistance
from formation_info import FormationInfo
from model.action_type import ActionType
from model.move import Move

proc initNukeAlert(): Behavior =
  var silent = true
  result.tick = proc (ws: WorldState, fi: FormationInfo): BehaviorStatus =
    let enemy = ws.players[Players.enemy]
    if enemy.nextNuclearStrikeTickIndex > 0:
      let epicenter = (x: enemy.nextNuclearStrikeX, y: enemy.nextNuclearStrikeY)
      let sqRad = ws.game.tacticalNuclearStrikeRadius *
                  ws.game.tacticalNuclearStrikeRadius
      debug("Nuke detected in " & $epicenter)
      let centerdistance = epicenter.getSqDistance(fi.center)
      if centerdistance < sqRad:
        debug("Nuke on me!")
        return BehaviorStatus.act
      for v in fi.vertices:
        if v.distanceToCenter != 0:
          let distance = epicenter.getSqDistance(v.point)
          if distance < sqRad:
            debug("Nuke on me!")
            return BehaviorStatus.act
      if silent:
        # give other formation a tick to check if nuke on it
        silent = false
        return BehaviorStatus.hold
    else:
      silent = true
    return BehaviorStatus.inactive
  result.action = proc (ws: WorldState, fi: FormationInfo, m: var Move) =
    let enemy = ws.players[Players.enemy]
    m.action = ActionType.SCALE
    m.x = enemy.nextNuclearStrikeX
    m.y = enemy.nextNuclearStrikeY
    m.factor = 10
    debug("Scalling out")
  result.reset = proc () =
    discard
