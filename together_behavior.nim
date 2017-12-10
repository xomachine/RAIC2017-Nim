from model.move import Move
from model.action_type import ActionType
from utils import Point
from behavior import BehaviorStatus, Behavior
from analyze import WorldState
from enhanced import Group

proc initTogetherBehavior*(holder: Group): Behavior

from vehicles import resolve, toGroup
from borders import obtainCenter, obtainBorders, area, Vertex
from formation_info import FormationInfo
from utils import debug, getSqDistance
from math import PI
from tables import `[]`
from fastset import intersects
from analyze import Players

# TODO: unexpected rotation instead of scaling for second selected group
proc initTogetherBehavior(holder: Group): Behavior =
  # fields (perfecly incapsulated!)
  var holder = holder
  var lastAngle = PI
  var lastAction: ActionType
  var counter: int
  var spread = false
  # methods
  let reset = proc() =
    lastAction = ActionType.NONE
    counter = 0
    spread = false
  result.reset = reset
  result.tick = proc(ws: WorldState, finfo: FormationInfo): BehaviorStatus =
    const criticalDensity = 1/10
    const criticalNukeDensity = 1/12
    if finfo.units.len() == 0:
      return BehaviorStatus.inactive
    let area = area(finfo.vertices)
    let density = finfo.units.len().toFloat() / area
    if ws.players[Players.enemy].remainingNuclearStrikeCooldownTicks == 0:
      for c in ws.vehicles.byEnemyCluster:
        for v in @(c.vertices) & (distanceToCenter: -1.0, point: c.center):
          if v.distanceToCenter == 0:
            continue
          let distance = v.point.getSqDistance(finfo.center)
          if distance < ws.game.fighterVisionRange*ws.game.fighterVisionRange:
            debug("Nuke alert near me, spreading!")
            if density > criticalNukeDensity:
              if spread:
                return BehaviorStatus.hold
              reset()
              spread = true
              return BehaviorStatus.act
            else:
              reset()
              return BehaviorStatus.inactive
    if density < criticaldensity:
      if lastAction != ActionType.SCALE or spread:
        if counter <= 0:
          debug("Density: " & $density & ", critical: " & $criticaldensity)
          spread = false
          return BehaviorStatus.act
        else:
          counter -= 1
          return BehaviorStatus.hold
      elif not ws.vehicles.updated.intersects(ws.vehicles.byGroup[holder]):
        return BehaviorStatus.act
      return BehaviorStatus.hold
    else:
      reset()
      return BehaviorStatus.inactive
  result.action = proc(ws: WorldState, fi: FormationInfo, m: var Move) =
    const maxcount = 3
    if lastAction != ActionType.SCALE or spread:
      let center = fi.center
      m.action = ActionType.SCALE
      lastAction = ActionType.SCALE
      m.x = center.x
      m.y = center.y
      if spread:
        m.factor = 1.5
      else:
        m.factor = 0.1
      debug("Scaling:" & $m.factor)
    else:
      let center = fi.center
      m.action = ActionType.ROTATE
      m.angle = lastAngle
      m.x = center.x
      m.y = center.y
      lastAngle *= -1
      lastAction = ActionType.ROTATE
      debug("Rotating:" & $lastAngle)
      counter = int(maxcount.float / fi.maxspeed)
