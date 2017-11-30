from model.move import Move
from model.action_type import ActionType
from utils import Point
from selection import Selection
from behavior import BehaviorStatus, Behavior
from analyze import WorldState

proc initTogetherBehavior*(holder: Selection): Behavior

from vehicles import resolve, toGroup
from borders import obtainCenter, obtainBorders, area
from math import PI
from tables import `[]`

proc initTogetherBehavior(holder: Selection): Behavior =
  # fields (perfecly incapsulated!)
  var holder = holder
  var lastAngle = PI
  var center: Point
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
    center = obtainCenter(units)
    let area = area(obtainBorders(center, units))
    let density = units.len().toFloat() / area
    if density < criticaldensity:
      BehaviorStatus.act
    else:
      reset()
      BehaviorStatus.inactive
  result.action = proc(ws: WorldState, m: var Move) =
    const maxcount = 50
    if lastAction != ActionType.SCALE:
      if counter <= 0:
        m.action = ActionType.SCALE
        lastAction = m.action
        m.x = center.x
        m.y = center.y
        m.factor = 0.1
      else:
        counter -= 1
    elif card(ws.vehicles.updated *
              ws.vehicles.byGroup[holder.group]) == 0:
      m.action = ActionType.ROTATE
      m.angle = lastAngle
      m.x = center.x
      m.y = center.y
      lastAngle *= -1
      lastAction = m.action
      counter = maxcount
