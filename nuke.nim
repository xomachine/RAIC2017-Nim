from behavior import Behavior
from enhanced import Group

proc initNuke*(): Behavior

from analyze import WorldState
from behavior import BehaviorStatus
from clusterization import clusterize
from enhanced import EVehicle
from vehicles import resolve, toGroup
from utils import Point, getSqDistance, debug
from fastset import `-`
from formation_info import FormationInfo
from model.vehicle_type import VehicleType
from model.move import Move
from model.game import Game
from model.action_type import ActionType

proc initNuke(): Behavior =
  var target: Point
  var stopped = false
  let do_reset = proc() =
    target = (x: 0'f64, y: 0'f64)
    stopped = false
  result.tick = proc(ws: WorldState, fi: FormationInfo): BehaviorStatus =
    let v = ws.vehicles
    let hcenter = fi.center
    let sqVision = ws.game.fighterVisionRange * ws.game.fighterVisionRange
    for cluster in v.byEnemyCluster:
      let center = cluster.center
      let distance = hcenter.getSqDistance(center)
      if distance < sqVision:
        debug("Found target:" & $center.x & ":" & $center.y)
        target = center
        return BehaviorStatus.act
    return BehaviorStatus.inactive
  result.action = proc (ws: WorldState, fi: FormationInfo, m: var Move) =
    if not stopped:
      m.action = ActionType.MOVE
      m.x = 0.1
      m.y = 0.1
      stopped = true
      return
    for u in fi.units:
      let pu = (x: u.x, y: u.y)
      let sqdistance = pu.getSqDistance(target)
      let vision = ws.gparams.visionByType[u.thetype.ord]*0.8
      if sqdistance < vision * vision:
        m.vehicleId = u.id
        m.x = target.x
        m.y = target.y
        m.action = ActionType.TACTICAL_NUCLEAR_STRIKE
        return
    debug("No navigator found")
    do_reset()
  result.reset = do_reset
