from pbehavior import PlayerBehavior
from model.game import Game

proc initProduction*(g: Game): PlayerBehavior

from analyze import WorldState
from gparams import flyers
from selection import initSelection
from formation import newGroundFormation, newAerialFormation
from actions import newSelection, group, ActionStatus
from pbehavior import PBResult, PBRType
from vehicles import inArea
from groupcounter import GroupCounter, getFreeGroup
from enhanced import FacilityId
from model.move import Move
from model.action_type import ActionType
from model.vehicle_type import VehicleType
from model.facility_type import FacilityType
from utils import Area, debug
from tables import `[]`, initTable, contains, `[]=`
from fastset import `*`, card, `-`, intersects, items

proc initProduction(g: Game): PlayerBehavior =
  var flyermakers = 0
  var groundmakers = 0
  var lastchanged = initTable[FacilityId, int]()
  let vehiclesPerLine = (g.facilityWidth.int div g.vehicleRadius.int + 1) div 3
  let vehiclesPerCol = (g.facilityHeight.int div g.vehicleRadius.int + 1) div 3
  let vehiclesPerFactory = vehiclesPerCol * vehiclesPerLine
  result.tick = proc(ws: WorldState, gc: var GroupCounter, m: var Move): PBResult =
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
      #echo mine_in_facility
      if facility.vehicleType == VehicleType.UNKNOWN and not mine_in_facility:
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
      elif producted mod vehiclesPerLine == 0 and producted > 0 and
           (fid notin lastchanged or lastchanged[fid] != producted):
        # switch vehicles type
        case facility.vehicleType
        of VehicleType.IFV: m.vehicleType = VehicleType.ARRV
        of VehicleType.ARRV: m.vehicleType = VehicleType.IFV
        of VehicleType.FIGHTER: m.vehicleType = VehicleType.HELICOPTER
        of VehicleType.HELICOPTER: m.vehicleType = VehicleType.FIGHTER
        else: continue
        m.action = ActionType.SETUP_VEHICLE_PRODUCTION
        m.facilityId = fid.int64
        lastchanged[fid] = producted
        return
      elif facility.vehicleType != VehicleType.UNKNOWN:
        if ord(facility.vehicleType) in flyers:
          inc(tmpflyermakers)
          inc(tmpgroundmakers)
    flyermakers = tmpflyermakers
    groundmakers = tmpgroundmakers
