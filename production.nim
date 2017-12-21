from pbehavior import PlayerBehavior
from model.game import Game

proc initProduction*(g: Game): PlayerBehavior

from analyze import WorldState
from gparams import flyers
from formation import newGroundFormation, newAerialFormation
from actions import newSelection, group
from actionchain import initActionChain
from pbehavior import PBResult, PBRType
from pbactions import addFormation
from vehicles import inArea, Vehicles
from groupcounter import GroupCounter, getFreeGroup
from enhanced import FacilityId
from model.move import Move
from model.action_type import ActionType
from model.vehicle_type import VehicleType
from model.facility_type import FacilityType
from utils import Area, debug
from tables import `[]`, initTable, contains, `[]=`, len
from fastset import `*`, card, `-`, intersects, items, `+`

proc getRecomendation(v: Vehicles, tick: int): bool =
  var recomendation {.global.} = false
  var cachetick {.global.} = -1
  if tick != cachetick:
    let enemies = v.all - v.mine
    let forFighter = card((v.byType[VehicleType.FIGHTER] +
                           v.byType[VehicleType.HELICOPTER]) * enemies)
    let forCopter = card((v.byType[VehicleType.TANK] +
                          v.byType[VehicleType.IFV]) * enemies)
    recomendation = forCopter >= forFighter
    cachetick = tick
  recomendation

proc initProduction(g: Game): PlayerBehavior =
  var flyermakers = 0
  var groundmakers = 0
  var lastchanged = initTable[FacilityId, int]()
  var tickcheck: array[32, int]
  let vehiclesPerLine = (g.facilityWidth.int div g.vehicleRadius.int + 1) div 3
  let vehiclesPerCol = (g.facilityHeight.int div g.vehicleRadius.int + 1) div 3
  let vehiclesPerFactory = ((vehiclesPerCol div 2)+2) * vehiclesPerLine
  #debug $vehiclesPerLine
  #debug $vehiclesPerFactory
  result.tick = proc(ws: WorldState, gc: var GroupCounter, m: var Move): PBResult =
    let ungrouped = ws.vehicles.byGroup[0]
    let mine_factories =
      ws.facilities.mine * ws.facilities.byType[FacilityType.VEHICLE_FACTORY]
    let v = ws.vehicles
    let mine_flyers = ws.vehicles.mine * ws.vehicles.aerials
    let mine_grounds = ws.vehicles.mine - ws.vehicles.aerials
    let myfacilen = card(mine_factories)
    let facilen = card(ws.facilities.byType[FacilityType.VEHICLE_FACTORY]) div 2
    var tmpflyermakers = 0
    var tmpgroundmakers = 0
    for fid in mine_factories:
      let facility = ws.facilities.byId[fid]
      let farea: Area = (left: facility.left,
                         right: facility.left + ws.game.facilityWidth,
                         top: facility.top,
                         bottom: facility.top + ws.game.facilityHeight)
      let in_facility = ws.vehicles.inArea(farea)
      let productedset = in_facility * ungrouped
      let producted = card(productedset)
      #debug "FAREA:", $farea
      #debug "In facility total:", $card(in_facility)
      #debug $mine_in_facility
      #debug $fid & ": Produced:" & $producted
      #debug $fid & ": Making:" & $facility.vehicleType
      #if fid in lastchanged:
      #  debug $fid & ": LastChanged:" & $lastchanged[fid]
      let productedmod = (producted-1) mod 22
      if tickcheck[fid] < ws.world.tickIndex and
         facility.vehicleType == VehicleType.UNKNOWN:
        # initial setup production
        let mflen = card(mine_flyers)
        let mglen = card(mine_grounds)
        if mflen + 200 < mglen and mglen > 100 and groundmakers > 1 and
           myfacilen >= facilen and
           not in_facility.intersects(mine_flyers - productedset):
          if v.getRecomendation(ws.world.tickIndex):
            m.vehicleType = VehicleType.HELICOPTER
          else:
            m.vehicleType = VehicleType.FIGHTER
        elif not in_facility.intersects(mine_grounds - productedset):
          if v.getRecomendation(ws.world.tickIndex):
            m.vehicleType = VehicleType.TANK
          else:
            m.vehicleType = VehicleType.IFV
        else: continue
        m.action = ActionType.SETUP_VEHICLE_PRODUCTION
        m.facilityId = fid.int64
        return
      elif fid in lastchanged and lastchanged[fid] == producted:
        # not so elegant but helps to avoid doubling this condition
        discard
      elif producted >= vehiclesPerFactory or
           (facility.vehicleType in
            [VehicleType.FIGHTER, VehicleType.HELICOPTER] and
            producted >= (vehiclesPerFactory div 2) + 5):
        # make formation setup flyers production
        m.action = ActionType.SETUP_VEHICLE_PRODUCTION
        m.facilityId = fid.int64
        m.vehicleType = VehicleType.UNKNOWN
        let newgroup = gc.getFreeGroup()
        let ac = @[
          newSelection(farea),
          group(newgroup),
          addFormation(newgroup, facility.vehicleType.ord in flyers)
        ]
        debug("Adding behavior for group: " & $newgroup)
        lastchanged[fid] = producted
        tickcheck[fid] = ws.world.tickIndex + 10
        return PBResult(kind: PBRType.addPBehavior,
                        behavior: initActionChain(ac))
      elif facility.vehicleType in
           [VehicleType.FIGHTER, VehicleType.HELICOPTER] and
           (producted mod vehiclesPerLine) == 0 and producted > 0:
        # switch vehicles type
        case facility.vehicleType
        of VehicleType.TANK, VehicleType.IFV: m.vehicleType = VehicleType.ARRV
        of VehicleType.ARRV:
          if v.getRecomendation(ws.world.tickIndex):
            m.vehicleType = VehicleType.TANK
          else:
            m.vehicleType = VehicleType.IFV
        of VehicleType.FIGHTER, VehicleType.HELICOPTER:
          if v.getRecomendation(ws.world.tickIndex):
            m.vehicleType = VehicleType.HELICOPTER
          else:
            m.vehicleType = VehicleType.FIGHTER
        else: continue
        m.action = ActionType.SETUP_VEHICLE_PRODUCTION
        m.facilityId = fid.int64
        lastchanged[fid] = producted
        return
      elif facility.vehicleType notin
           [VehicleType.FIGHTER, VehicleType.HELICOPTER] and
           productedmod in [11, 20]:
        case productedmod
        of 11: m.vehicleType = VehicleType.ARRV
        of 20:
          if v.getRecomendation(ws.world.tickIndex):
            m.vehicleType = VehicleType.TANK
          else:
            m.vehicleType = VehicleType.IFV
        else: continue
        m.action = ActionType.SETUP_VEHICLE_PRODUCTION
        m.facilityId = fid.int64
        lastchanged[fid] = producted
      if ord(facility.vehicleType) in flyers:
        inc(tmpflyermakers)
      else:
        inc(tmpgroundmakers)
    flyermakers = tmpflyermakers
    groundmakers = tmpgroundmakers
