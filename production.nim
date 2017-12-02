from pbehavior import PlayerBehavior

proc initProduction*(): PlayerBehavior

from analyze import WorldState, flyers
from selection import initSelection
from formation import newGroundFormation, newAerialFormation
from actions import newSelection, group, ActionStatus
from pbehavior import PBResult, PBRType
from vehicles import inArea
from groupcounter import GroupCounter, getFreeGroup
from model.move import Move
from model.action_type import ActionType
from model.vehicle_type import VehicleType
from model.facility_type import FacilityType
from utils import Area
from tables import `[]`
from fastset import `*`, card, `-`, intersects

var vehiclesPerLine: int = 0
var vehiclesPerCol: int = 0
var vehiclesPerFactory: int = 0
proc initProduction(): PlayerBehavior =
  var flyermakers = 0
  var groundmakers = 0
  result.tick = proc(ws: WorldState, gc: var GroupCounter, m: var Move): PBResult =
    if unlikely(vehiclesPerLine == 0):
      vehiclesPerLine =
        ws.game.facilityWidth.int div (2*ws.game.vehicleRadius.int)
      vehiclesPerCol =
        ws.game.facilityHeight.int div (2*ws.game.vehicleRadius.int)
      vehiclesPerFactory = vehiclesPerCol * vehiclesPerLine
    let ungrouped = ws.vehicles.byGroup[0]
    let mine_factories =
      ws.facilities.mine * ws.facilities.byType[FacilityType.VEHICLE_FACTORY]
    let mine_flyers = ws.vehicles.mine * ws.vehicles.aerials
    let mine_grounds = ws.vehicles.mine - ws.vehicles.aerials
    var tmpflyermakers = 0
    var tmpgroundmakers = 0
    for fid in mine_factories:
      let facility = ws.facilities.byId[fid]
      let farea: Area = (left: facility.left,
                         right: facility.left + ws.game.facilityWidth,
                         top: facility.top,
                         bottom: facility.top + ws.game.facilityHeight)
      let in_facility = ws.vehicles.inArea(farea)
      let mine_in_facility = in_facility.intersects(ws.vehicles.mine)
      let producted = card(in_facility * ungrouped)
      if mine_in_facility and facility.vehicleType == VehicleType.UNKNOWN:
        # initial setup production
        m.action = ActionType.SETUP_VEHICLE_PRODUCTION
        m.facilityId = fid.int64
        let mflen = card(mine_flyers)
        let mglen = card(mine_grounds)
        if mflen < mglen and mglen > 100 and groundmakers > 0:
          m.vehicleType = VehicleType.FIGHTER
        else:
          m.vehicleType = VehicleType.IFV
        return
      elif producted == vehiclesPerFactory:
        # make formation setup flyers production
        m.action = ActionType.SETUP_VEHICLE_PRODUCTION
        m.facilityId = fid.int64
        m.vehicleType = VehicleType.UNKNOWN
        let newgroup = gc.getFreeGroup()
        let selection = initSelection(newgroup, @[newSelection(farea)])
        let theformation =
          if facility.vehicleType.ord in flyers:
            newAerialFormation(selection)
          else:
            newGroundFormation(selection)
        return PBResult(kind: PBRType.addFormation, formation: theformation)
      elif producted mod vehiclesPerLine == 0 and producted > 0:
        # switch vehicles type
        case facility.vehicleType
        of VehicleType.IFV: m.vehicleType = VehicleType.ARRV
        of VehicleType.ARRV: m.vehicleType = VehicleType.IFV
        of VehicleType.FIGHTER: m.vehicleType = VehicleType.HELICOPTER
        of VehicleType.HELICOPTER: m.vehicleType = VehicleType.FIGHTER
        else: continue
        m.action = ActionType.SETUP_VEHICLE_PRODUCTION
        m.facilityId = fid.int64
        return
      elif facility.vehicleType != VehicleType.UNKNOWN:
        if ord(facility.vehicleType) in flyers:
          inc(tmpflyermakers)
          inc(tmpgroundmakers)
    flyermakers = tmpflyermakers
    groundmakers = tmpgroundmakers
