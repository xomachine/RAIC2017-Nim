from behavior import Behavior

proc initRotator*(): Behavior

from analyze import WorldState
from behavior import BehaviorStatus
from fastset import intersects, empty, `-`
from formation_info import FormationInfo
from model.action_type import ActionType
from model.vehicle_type import VehicleType
from model.move import Move
from math import arctan2, PI, sqrt
from tables import `[]`
from utils import Point, getSqDistance, debug


proc normalize(angle: float, base: float = PI): float =
  result = angle
  while result > base:
    result -= base
  while result < 0:
    result += base

proc relnorm(angle: float): float =
  if abs(angle) > PI/2:
    normalize(PI - angle)
  else:
    angle

proc initRotator(): Behavior =
  var rotating = 0
  var torotate: float
  var nexttick = 0
  var radius: float = 0
  const rotrange = 120
  result.reset = proc() =
    rotating = 0
    torotate = 0.0
  result.tick = proc(ws: WorldState, fi: FormationInfo): BehaviorStatus =
    if (rotating > 0):
      if ws.vehicles.byGroup[fi.group].intersects(ws.vehicles.updated):
        rotating = 1
      else:
        rotating -= 1
      debug("Continuing rotation")
      return BehaviorStatus.hold
    if ws.world.tickIndex >= nexttick:
      nexttick = ws.world.tickIndex + 20
    else:
      return BehaviorStatus.inactive
    if fi.units.len() < 20:
      return BehaviorStatus.inactive
    if empty(ws.vehicles.byGroup[fi.group] -
             ws.vehicles.byType[VehicleType.ARRV]):
      nexttick = 20000
      return BehaviorStatus.inactive
    var mindst: float = 2*rotrange*rotrange
    var mincenter: Point
    for c in ws.vehicles.byEnemyCluster:
      let distance = c.center.getSqDistance(fi.center)
      if distance < mindst:
        mindst = distance
        mincenter = c.center
    if mindst == 2*rotrange*rotrange:
      return BehaviorStatus.inactive
    let cangle = normalize(arctan2(mincenter.y - fi.center.y,
                                   mincenter.x - fi.center.x))
    var maxvert: Point
    var maxrad = -1.0
    var mean = 0.0
    for vtx in fi.vertices:
      mean += vtx.distanceToCenter
      if vtx.distanceToCenter > maxrad:
        maxrad = vtx.distanceToCenter
        maxvert = vtx.point
    mean /= 16
    if maxrad <= 0 or maxrad/mean < 3.0:
      return BehaviorStatus.inactive
    debug($fi.group & ": Mean: " & $mean & ", max: " & $maxrad)
    let fangle = normalize(arctan2(maxvert.y - fi.center.y,
                                   maxvert.x - fi.center.x) + PI/2)
    torotate = relnorm(cangle - fangle)
    debug($fi.group & ": Angle to enemy: " & $cangle & ", Direction: " &
          $fangle)
    if abs(torotate) > PI/4:
      radius = maxrad.sqrt
      BehaviorStatus.act
    else:
      BehaviorStatus.inactive
  result.action = proc (ws: WorldState, fi: FormationInfo, m: var Move) =
    m.x = fi.center.x
    m.y = fi.center.y
    m.action = ActionType.ROTATE
    m.angle = torotate
    m.maxAngularSpeed = fi.maxspeed/radius
    rotating = 2
