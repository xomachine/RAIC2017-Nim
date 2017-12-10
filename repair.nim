from fieldbehavior import FieldBehavior

proc initRepair*(): FieldBehavior

from analyze import WorldState
from clusterization import clusterize
from formation_info import FormationInfo
from pf import FieldGrid, applyRepairFields, PointField, gridFromPoint
from vehicles import maxHealthRange, resolve
from model.vehicle_type import VehicleType
from borders import obtainCenter
from fastset import `-`, empty, card, `*`
from tables import `[]`
from utils import Point, debug

proc initRepair(): FieldBehavior =
  result.apply = proc (f: var FieldGrid, ws: WorldState, fi: FormationInfo) =
    let v = ws.vehicles
    let damaged = v.byGroup[fi.group] - v.byHealth[maxHealthRange]
    debug("FH: " & $card(v.byHealth[maxHealthRange]))
    if damaged.empty:
      return
    let arrvs = v.clusterize(v.byType[VehicleType.ARRV] * v.mine)
    var healPoints = newSeq[PointField](arrvs.len)
    let damagedlen = card(damaged)
    let fulllen = fi.units.len()
    debug($fi.group & ": " & $damagedlen & " of " & $fulllen &
          " damaged units detected!")
    var unitscounter = newSeq[int](arrvs.len)
    var maxunits = 0
    for i, arrv in arrvs.pairs():
      let units = v.resolve(arrv)
      if maxunits < units.len:
        maxunits = units.len
      unitscounter[i] = units.len
      let center = obtainCenter(units)
      healPoints[i].point = center.gridFromPoint()
      healPoints[i].power = max(-5.0, min(-2.0, -3*damagedlen/fulllen))
    for i, ul in unitscounter.pairs:
      healPoints[i].power *= ul/maxunits
    f.applyRepairFields(healPoints)

from behavior import Behavior, BehaviorStatus
from model.move import Move
from model.action_type import ActionType

proc initRepairBh*(): Behavior =
  var tgridx = -1
  var tgridy = -1
  var target: Point
  proc doreset() =
    tgridx = -1
    tgridy = -1
  result.reset = doreset
  result.tick = proc (ws: WorldState, fi: FormationInfo): BehaviorStatus =
    let v = ws.vehicles
    let damaged = v.byGroup[fi.group] - v.byHealth[maxHealthRange]
    debug("FH: " & $card(v.byHealth[maxHealthRange]))
    if damaged.empty:
      doreset()
      return BehaviorStatus.inactive
    elif damaged.card/fi.units.len > 0.9:
      let arrvs = v.clusterize(v.byType[VehicleType.ARRV] * v.mine)
      #let damagedlen = card(damaged)
      #let fulllen = fi.units.len()
      var maxunits = 0
      for i, arrv in arrvs.pairs():
        let units = v.resolve(arrv)
        let center = obtainCenter(units)
        if maxunits < units.len():
          maxunits = units.len()
          target = center
      if maxunits > 0:
        let gridx = int(target.x / 16)
        let gridy = int(target.y / 16)
        let mgridx = int(fi.center.x / 16)
        let mgridy = int(fi.center.y / 16)
        if mgridx == tgridx and mgridy == tgridy:
          return BehaviorStatus.inactive
        elif gridx != tgridx or gridy != tgridy:
          tgridx = gridx
          tgridy = gridy
          return BehaviorStatus.act
        else:
          return BehaviorStatus.hold
    else:
      doreset()
      return BehaviorStatus.inactive
  result.action = proc(ws: WorldState, fi: FormationInfo, m: var Move) =
    m.action = ActionType.MOVE
    m.x = target.x - fi.center.x
    m.y = target.y - fi.center.y
    tgridx = int(target.x / 16)
    tgridy = int(target.y / 16)
