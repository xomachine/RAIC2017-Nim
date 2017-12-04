from model.move import Move
from model.action_type import ActionType
from utils import Point
from selection import Selection
from behavior import BehaviorStatus, Behavior
from analyze import WorldState

proc initTogetherBehavior*(holder: Selection): Behavior

from vehicles import resolve, toGroup
from borders import obtainCenter, obtainBorders, area
from formation_info import FormationInfo
from utils import debug
from math import PI
from tables import `[]`
from fastset import intersects

proc initTogetherBehavior(holder: Selection): Behavior =
  # fields (perfecly incapsulated!)
  var holder = holder
  var lastAngle = PI
  var lastAction: ActionType
  var counter: int
  # methods
  let reset = proc() =
    lastAction = ActionType.NONE
    counter = 0
  result.reset = reset
  result.tick = proc(ws: WorldState, finfo: FormationInfo): BehaviorStatus =
    const criticalDensity = 1/16
    if finfo.units.len() == 0:
      return BehaviorStatus.inactive
    let area = area(finfo.vertices)
    let density = finfo.units.len().toFloat() / area
    if density < criticaldensity:
      debug("Density: " & $density & ", critical: " & $criticaldensity)
      return BehaviorStatus.act
    else:
      reset()
      return BehaviorStatus.inactive
  result.action = proc(ws: WorldState, fi: FormationInfo, m: var Move) =
    const maxcount = 50
    if lastAction != ActionType.SCALE:
      if counter <= 0:
        let center = fi.center
        m.action = ActionType.SCALE
        lastAction = ActionType.SCALE
        m.x = center.x
        m.y = center.y
        m.factor = 0.1
        debug("Scaling:" & $m.factor)
      else:
        counter -= 1
    elif not ws.vehicles.updated.intersects(ws.vehicles.byGroup[holder.group]):
      let center = fi.center
      m.action = ActionType.ROTATE
      m.angle = lastAngle
      m.x = center.x
      m.y = center.y
      lastAngle *= -1
      lastAction = ActionType.ROTATE
      counter = maxcount
