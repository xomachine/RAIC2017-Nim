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
from fastset import `-`, card
from formation_info import FormationInfo
from model.vehicle_type import VehicleType
from model.move import Move
from model.game import Game
from model.action_type import ActionType
from math import floor

proc initNuke(): Behavior =
  var target: Point
  var stopped = false
  let do_reset = proc() =
    target = (x: -1'f64, y: -1'f64)
    stopped = false
  do_reset()
  result.tick = proc(ws: WorldState, fi: FormationInfo): BehaviorStatus =
    let me = ws.players[Players.me]
    if me.next_nuclear_strike_tick_index > 0:
      return BehaviorStatus.hold
    elif me.remainingNuclearStrikeCooldownTicks > 0:
      do_reset()
      return BehaviorStatus.inactive
    let v = ws.vehicles
    let hcenter = fi.center
    let sqVision = ws.game.fighterVisionRange * ws.game.fighterVisionRange
    #let vplusc = (distanceToCenter: 1.0, point: hcenter) & @(fi.vertices)
    debug("Iterating over " & $v.byEnemyCluster.len & " clusters...")
    for i, cluster in v.byEnemyCluster.pairs():
      let center = cluster.center
     # for vv in vplusc:
     #   if vv.distanceToCenter == 0:
     #     continue
     #   let distance = vv.point.getSqDistance(center)
      let distance = hcenter.getSqDistance(center)
      debug("Cluster " & $i & " has " & $(cluster.cluster.card) &
            " units and sits " & $distance & " away")
      if distance < sqVision * 0.9:
        target = center
        if stopped:
          return BehaviorStatus.actUnselected
        else:
          return BehaviorStatus.act
    do_reset()
    return BehaviorStatus.inactive
  result.action = proc (ws: WorldState, fi: FormationInfo, m: var Move) =
    if not stopped:
      debug("Stopping...")
      m.action = ActionType.MOVE
      m.x = 0.01
      m.y = 0.01
      stopped = true
    elif target.x >= 0 and target.y >= 0:
      for u in fi.units:
        if u.durability == 0:
          continue
        let pu = (x: u.x, y: u.y)
        let sqdistance = pu.getSqDistance(target)
        let is_flyer = u.thetype.ord in flyers
        let celltype =
          if is_flyer: ws.world.weatherByCellXY[int(floor(u.x/32))][int(floor(u.y/32))].ord
          else: ws.world.terrainByCellXY[int(floor(u.x/32))][int(floor(u.y/32))].ord
        let vision = ws.gparams.visionByType[u.thetype.ord] *
                     1#ws.gparams.visionFactorsByEnv[int(is_flyer)][celltype]
        if sqdistance < vision * vision * 0.8:
          debug("Distance**2: " & $sqdistance)
          debug("Vision: " & $vision)
          debug("Id: " & $u.id)
          debug("Navigator: " & $pu)
          debug("CellType: " & $celltype)
          debug("NType:" & $ u.thetype)
          m.action = ActionType.TACTICAL_NUCLEAR_STRIKE
          m.vehicleId = u.id
          m.x = target.x
          m.y = target.y
          debug("Nuking on: " & $target.x & ":" & $target.y & " via " & $u.id)
      #do_reset()
    else:
      debug("No target for me!")
  result.reset = do_reset
