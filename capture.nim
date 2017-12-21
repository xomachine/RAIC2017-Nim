from fieldbehavior import FieldBehavior

proc initCapture*(): FieldBehavior

from analyze import WorldState, Players
from formation_info import FormationInfo
from fastset import `-`, items, `*`, card, FastSet, incl, clear, contains
from enhanced import FacilityId
from pf import FieldGrid, applyFields, gridFromPoint, PointField
from tables import `[]`
from model.facility_type import FacilityType
from vehicles import inArea, resolve
from utils import getSqDistance, Point, debug

var excludes: FastSet[FacilityId]
#var cachetick = 0
var groups: array[128, uint16]

proc initCapture(): FieldBehavior =
  result.apply = proc(f: var FieldGrid, ws: WorldState, fi: FormationInfo) =
    groups[fi.group] += 1
    if groups[fi.group] > groups[0]:
      groups[0] = groups[fi.group]
      #debug($fi.group & ": cachetick = " & $cachetick)
      debug($fi.group & ": tick = " & $ws.world.tickIndex)
      debug($fi.group & ": excludes = " & $excludes.card())
      #cachetick = ws.world.tickIndex
      excludes.clear
    let enemyid = ws.players[Players.enemy].id
    f = ws.facilities.field
    let notmine = ws.facilities.all - ws.facilities.mine
    let notminelen = card(notmine)
    let enemycapturers = ws.vehicles.all-ws.vehicles.aerials-ws.vehicles.mine
    #let enemygroundunits = ws.vehicles.resolve(enemycapturers)
    var nearest: Point
    var mindst: float = 1024*1024*2
    var additionals = newSeq[PointField]()
    var nearestid: FacilityId
    for f in notmine:
      let facility = ws.facilities.byId[f]
      let fapoint = (x: facility.left+32.0, y: facility.top+32.0)
      if notminelen > 2 and f in excludes:
        debug($fi.group & ": Excluding " & $f)
        additionals.add((point: fapoint.gridFromPoint(), power: 2.0))
        continue
      let farea = (left: facility.left, right: facility.left+64.0,
                   top: facility.top, bottom: facility.top+64.0)
      let enemies_in_farea = card(ws.vehicles.inArea(farea) * enemycapturers)
      if fi.units.len <= enemies_in_farea +
         int(facility.ownerPlayerId == enemyid and
             facility.theType == FacilityType.VEHICLE_FACTORY)*20:
        additionals.add((point: fapoint.gridFromPoint(), power: 4.0))
        continue
      let distance = fi.center.getSqDistance(fapoint)
      if distance < mindst:
        mindst = distance
        nearest = fapoint
        nearestid = f
    if nearest.x > 0:
      if fi.units.len > 20:
        excludes.incl(nearestid)
      additionals.add((point: nearest.gridFromPoint, power: -1.0))
    f.applyFields(additionals)
