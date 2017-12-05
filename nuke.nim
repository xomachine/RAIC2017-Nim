from behavior import Behavior
from enhanced import Group

proc initNuke*(): Behavior

from analyze import WorldState, Players
from behavior import BehaviorStatus
from clusterization import clusterize
from enhanced import EVehicle
from gparams import flyers
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
  var vid: int64
  var stopped = false
  let do_reset = proc() =
    target = (x: 0'f64, y: 0'f64)
    stopped = false
  result.tick = proc(ws: WorldState, fi: FormationInfo): BehaviorStatus =
    let me = ws.players[Players.me]
    if me.next_nuclear_strike_tick_index > 0:
      return BehaviorStatus.hold
    elif me.remainingNuclearStrikeCooldownTicks > 0:
      return BehaviorStatus.inactive
    let v = ws.vehicles
    let hcenter = fi.center
    let sqVision = ws.game.fighterVisionRange * ws.game.fighterVisionRange
    for cluster in v.byEnemyCluster:
      let center = cluster.center
      let distance = hcenter.getSqDistance(center)
      if distance < sqVision:
        debug("Found target:" & $center.x & ":" & $center.y)
        for u in fi.units:
          let pu = (x: u.x, y: u.y)
          let sqdistance = pu.getSqDistance(center)
          let is_flyer = u.thetype.ord in flyers
          let celltype =
            if is_flyer: ws.world.weatherByCellXY[int(u.x/32)][int(u.y/32)].ord
            else: ws.world.terrainByCellXY[int(u.x/32)][int(u.y/32)].ord
          let vision = ws.gparams.visionByType[u.thetype.ord] *
                       ws.gparams.visionFactorsByEnv[int(is_flyer)][celltype]
          if sqdistance < vision * vision:
            vid = u.id
            target = center
            return BehaviorStatus.act
    return BehaviorStatus.inactive
  result.action = proc (ws: WorldState, fi: FormationInfo, m: var Move) =
    if not stopped:
      m.action = ActionType.MOVE
      m.x = 0.001
      m.y = 0.001
      stopped = true
    else:
      m.action = ActionType.TACTICAL_NUCLEAR_STRIKE
      m.vehicleId = vid
      m.x = target.x
      m.y = target.y
  result.reset = do_reset
