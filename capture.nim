from fieldbehavior import FieldBehavior

proc initCapture*(): FieldBehavior

from analyze import WorldState, Players
from formation_info import FormationInfo
from fastset import `-`, items, `*`, card
from pf import FieldGrid, applyFields, gridFromPoint, PointField
from tables import `[]`
from model.facility_type import FacilityType
from vehicles import inArea, resolve
from utils import getSqDistance, Point

proc initCapture(): FieldBehavior =
  result.apply = proc(f: var FieldGrid, ws: WorldState, fi: FormationInfo) =
    let enemyid = ws.players[Players.enemy].id
    f = ws.facilities.field
    let notmine = ws.facilities.all - ws.facilities.mine
    let enemycapturers = ws.vehicles.all-ws.vehicles.aerials-ws.vehicles.mine
    #let enemygroundunits = ws.vehicles.resolve(enemycapturers)
    var nearest: Point
    var mindst: float = 1024*1024*2
    var additionals = newSeq[PointField]()
    for f in notmine:
      let facility = ws.facilities.byId[f]
      let fapoint = (x: facility.left+32.0, y: facility.top+32.0)
      let farea = (left: facility.left, right: facility.left+64.0,
                   top: facility.top, bottom: facility.top+64.0)
      let enemies_in_farea = card(ws.vehicles.inArea(farea) * enemycapturers)
      if fi.units.len <= enemies_in_farea +
         int(facility.ownerPlayerId == enemyid and
             facility.theType == FacilityType.VEHICLE_FACTORY)*20:
        additionals.add((point: fapoint.gridFromPoint(), power: 3.0))
        continue
      let distance =
        fi.center.getSqDistance(fapoint)
      if distance < mindst:
        mindst = distance
        nearest = fapoint
    if nearest.x > 0:
      additionals.add((point: nearest.gridFromPoint, power: -1.0))
    f.applyFields(additionals)
