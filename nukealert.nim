from behavior import Behavior
from enhanced import Group


proc initNukeAlert*(holder: Group): Behavior

from analyze import WorldState, Players
from behavior import BehaviorStatus
from vehicles import resolve, toGroup
from utils import areaFromUnits, inArea, debug
from model.action_type import ActionType
from model.move import Move

proc initNukeAlert(holder: Group): Behavior =
  result.tick = proc (ws: WorldState): BehaviorStatus =
    let enemy = ws.players[Players.enemy]
    if enemy.nextNuclearStrikeTickIndex > 0:
      debug("Nuke detected!")
      let epicenter = (x: enemy.nextNuclearStrikeX, y: enemy.nextNuclearStrikeY)
      let uarea = areaFromUnits(ws.vehicles.resolve(holder))
      if epicenter.inArea(uarea):
        debug("Nuke on me!")
        return BehaviorStatus.act
    return BehaviorStatus.inactive
  result.action = proc (ws: WorldState, m: var Move) =
    let enemy = ws.players[Players.enemy]
    m.action = ActionType.SCALE
    m.x = enemy.nextNuclearStrikeX
    m.y = enemy.nextNuclearStrikeY
    m.factor = 10
    debug("Scalling out")
  result.reset = proc () =
    discard
