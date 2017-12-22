from model.move import Move
from model.action_type import ActionType
from utils import Point
from behavior import BehaviorStatus, Behavior
from analyze import WorldState
from enhanced import Group

type LastAction {.pure.} = enum
  none
  tight
  rotate
  spread

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
  var lastAction: LastAction
  var counter: int
  var factor: float = 1.0
  # methods
  let reset = proc() =
    lastAction = LastAction.none
    counter = 0
    factor = 1.0
  result.reset = reset
  result.tick = proc(ws: WorldState, finfo: FormationInfo): BehaviorStatus =
    const criticalDensity = 1/12
    const maxDensity = 1/9
    const criticalNukeDensity = 1/14
    if finfo.units.len() < 4:
      return BehaviorStatus.inactive
    let area = area(finfo.vertices)
    let density = finfo.units.len().toFloat() / area
    if ws.players[Players.enemy].remainingNuclearStrikeCooldownTicks < 20:
      for c in ws.vehicles.byEnemyCluster:
        for v in @(c.vertices) & (distanceToCenter: -1.0, point: c.center):
          if v.distanceToCenter == 0:
            continue
          let distance = v.point.getSqDistance(finfo.center)
          if distance < ws.game.fighterVisionRange*ws.game.fighterVisionRange:
            debug("Nuke alert near me, spreading!")
            if density > criticalNukeDensity:
              if lastAction == LastAction.spread:
                return BehaviorStatus.hold
              reset()
              factor = density / criticalNukeDensity
              return BehaviorStatus.act
            else:
              reset()
              return BehaviorStatus.inactive
    if density > maxDensity:
      factor = density / maxDensity
      if lastAction == LastAction.spread and
         not ws.vehicles.updated.intersects(ws.vehicles.byGroup[holder]):
        debug("Holding due to still spreading")
        return BehaviorStatus.hold
      else:
        return BehaviorStatus.act
    elif density < criticaldensity:
      factor = density / criticalDensity
      if lastAction != LastAction.tight:
        if lastAction != LastAction.rotate or counter <= ws.world.tickIndex:
          debug($finfo.group & ": Density: " & $density & ", critical: " & $criticaldensity)
          return BehaviorStatus.act
        else:
          debug($finfo.group & ": Rotation continued till " & $counter & " but now " & $ws.world.tickIndex)
          return BehaviorStatus.hold
      elif not ws.vehicles.updated.intersects(ws.vehicles.byGroup[holder]):
        factor = 1.0
        return BehaviorStatus.act
      elif lastAction == LastAction.rotate:
        debug("Holding due to no condition meet (rotation continues)")
        return BehaviorStatus.hold
      else:
        reset()
        return BehaviorStatus.inactive
    else:
      reset()
      return BehaviorStatus.inactive
  result.action = proc(ws: WorldState, fi: FormationInfo, m: var Move) =
    const maxcount = 6
    if (lastAction != LastAction.tight and factor < 1.0) or
       (lastAction != LastAction.spread and factor > 1.0):
      while abs(factor - 1.0) < 0.2:
        factor *= factor
      let center = fi.center
      m.action = ActionType.SCALE
      m.x = center.x
      m.y = center.y
      if factor > 1.0:
        m.factor = min(10.0, factor)
        lastAction = LastAction.spread
      else:
        m.factor = max(0.1, factor)
        lastAction = LastAction.tight
      debug("Scaling:" & $m.factor)
    else:
      let center = fi.center
      m.action = ActionType.ROTATE
      m.angle = lastAngle
      m.x = center.x
      m.y = center.y
      lastAngle *= -1
      lastAction = LastAction.rotate
      debug("Rotating:" & $lastAngle)
      counter = ws.world.tickIndex + int(maxcount.float / fi.maxspeed)
