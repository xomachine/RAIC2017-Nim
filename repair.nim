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
