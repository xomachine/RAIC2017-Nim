from behavior import Behavior
from enhanced import Group


proc initNukeAlert*(): Behavior

from analyze import WorldState, Players
from behavior import BehaviorStatus
from vehicles import resolve, toGroup
from utils import areaFromUnits, inArea, debug
from formation_info import FormationInfo
from model.action_type import ActionType
from model.move import Move

proc initNukeAlert(): Behavior =
  result.tick = proc (ws: WorldState, fi: FormationInfo): BehaviorStatus =
    let enemy = ws.players[Players.enemy]
    if enemy.nextNuclearStrikeTickIndex > 0:
      let epicenter = (x: enemy.nextNuclearStrikeX, y: enemy.nextNuclearStrikeY)
      debug("Nuke detected in " & $epicenter)
      let uarea = areaFromUnits(fi.units)
      if epicenter.inArea(uarea):
        debug("Nuke on me!")
        return BehaviorStatus.act
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
