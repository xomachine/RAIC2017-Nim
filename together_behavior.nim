from model.move import Move
from model.action_type import ActionType
from utils import Point
from selection import Selection
from behavior import BehaviorStatus, Behavior
from analyze import WorldState

proc initTogetherBehavior*(holder: Selection): Behavior

from vehicles import resolve, toGroup
from borders import obtainCenter, obtainBorders, area
from utils import debug
from math import PI
from tables import `[]`
from fastset import `*`, card

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
  result.tick = proc(ws: WorldState): BehaviorStatus =
    const criticalDensity = 1/16
    let units = ws.vehicles.resolve(holder.group)
    if units.len() == 0:
      return BehaviorStatus.inactive
    let center = obtainCenter(units)
    let area = area(obtainBorders(center, units))
    let density = units.len().toFloat() / area
    if density < criticaldensity:
      debug("Density: " & $density & ", critical: " & $criticaldensity)
      return BehaviorStatus.act
    else:
      reset()
      return BehaviorStatus.inactive
  result.action = proc(ws: WorldState, m: var Move) =
    const maxcount = 50
    if lastAction != ActionType.SCALE:
      if counter <= 0:
        let center = obtainCenter(ws.vehicles.resolve(holder.group))
        m.action = ActionType.SCALE
        lastAction = ActionType.SCALE
        m.x = center.x
        m.y = center.y
        m.factor = 0.1
        debug("Scaling:" & $m.factor)
      else:
        counter -= 1
    elif card(ws.vehicles.updated *
              ws.vehicles.byGroup[holder.group]) == 0:
      let center = obtainCenter(ws.vehicles.resolve(holder.group))
      m.action = ActionType.ROTATE
      m.angle = lastAngle
      m.x = center.x
      m.y = center.y
      lastAngle *= -1
      lastAction = ActionType.ROTATE
      counter = maxcount
