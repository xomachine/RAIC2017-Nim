from pbehavior import PlayerBehavior

proc initProduction*(): PlayerBehavior

from analyze import WorldState
from vehicles import inArea
from model.move import Move
from model.vehicle_type import VehicleType
from model.facility_type import FacilityType
from utils import Area
from tables import `[]`

proc initProduction(): PlayerBehavior =
  result.tick = proc(ws: WorldState, m: var Move) =
    let vehiclesPerLine {.global.} =
      ws.game.facilityWidth.int div (2*ws.game.vehicleRadius.int)
    let vehiclesPerCol {.global.} =
      ws.game.facilityHeight.int div (2*ws.game.vehicleRadius.int)
    let vehiclesPerFactory {.global.} = vehiclesPerCol * vehiclesPerLine
    let ungrouped = ws.vehicles.byGroup[0]
    let mine_factories =
      ws.facilities.mine * ws.facilities.byType[FacilityType.VEHICLE_FACTORY]
    for fid in mine_factories:
      let facility = ws.facilities.byId[fid]
      let farea: Area = (left: facility.left,
                         right: facility.left + ws.game.facilityWidth,
                         top: facility.top,
                         bottom: facility.top + ws.game.facilityHeight)
      let in_facility = ws.vehicles.inArea(farea)
      let producted = card(in_facility * ungrouped)
      if facility.vehicleType == VehicleType.UNKNOWN:
        discard
        # setup production
      elif producted == vehiclesPerFactory:
        discard
        # make formation setup flyers production
        # TODO: adding formations and others players behaviors
      elif producted == vehiclesPerLine:
        discard
        # switch vehicles type
