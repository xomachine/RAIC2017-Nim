from pbehavior import PlayerBehavior

proc initProduction*(): PlayerBehavior

from analyze import WorldState, flyers
from pbehavior import PBResult
from vehicles import inArea
from groupcounter import GroupCounter
from model.move import Move
from model.action_type import ActionType
from model.vehicle_type import VehicleType
from model.facility_type import FacilityType
from utils import Area
from tables import `[]`

proc initProduction(): PlayerBehavior =
  var flyermakers = 0
  var groundmakers = 0
  result.tick = proc(ws: WorldState, gc: var GroupCounter, m: var Move): PBResult =
    let vehiclesPerLine {.global.} =
      ws.game.facilityWidth.int div (2*ws.game.vehicleRadius.int)
    let vehiclesPerCol {.global.} =
      ws.game.facilityHeight.int div (2*ws.game.vehicleRadius.int)
    let vehiclesPerFactory {.global.} = vehiclesPerCol * vehiclesPerLine
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
      let mine_in_facility = in_facility * ws.vehicles.mine
      let producted = card(in_facility * ungrouped)
      if card(mine_in_facility) == 0 and
         facility.vehicleType == VehicleType.UNKNOWN:
        m.action = ActionType.SETUP_VEHICLE_PRODUCTION
        m.facilityId = fid.int64
        let mflen = card(mine_flyers)
        let mglen = card(mine_grounds)

        if mflen < mglen and mglen > 100 and groundmakers > 0:
          m.vehicleType = VehicleType.FIGHTER
        else:
          m.vehicleType = VehicleType.IFV
        return
        # setup production
      elif producted == vehiclesPerFactory:
        discard
        # make formation setup flyers production
        # TODO: adding formations and others players behaviors
      elif producted == vehiclesPerLine:
        # switch vehicles type
        m.action = ActionType.SETUP_VEHICLE_PRODUCTION
        m.facilityId = fid.int64
        if facility.vehicleType == VehicleType.IFV:
          m.vehicleType = VehicleType.ARRV
        elif facility.vehicleType == VehicleType.ARRV:
          m.vehicleType = VehicleType.IFV
        return
      elif facility.vehicleType != VehicleType.UNKNOWN:
        if ord(facility.vehicleType) in flyers:
          inc(tmpflyermakers)
          inc(tmpgroundmakers)
    flyermakers = tmpflyermakers
    groundmakers = tmpgroundmakers
