from tables import Table
from model.facility import Facility
from model.facility_type import FacilityType
from model.player import Player
from model.world import World
from enhanced import FacilityId

type
  Facilities* = tuple
    byId: Table[FacilityId, Facility]
    byType: Table[FacilityType, set[FacilityId]]
    mine: set[FacilityId]
    neutral: set[FacilityId]
    all: set[FacilityId]

proc initFacilities*(w: World, p: Player): Facilities
proc update*(self: var Facilities, w: World, myid: int64)

from tables import initTable, `[]`, `[]=`, mgetOrPut
from math import nextPowerOfTwo

proc initFacilities(w: World, p: Player): Facilities =
  result.byId =
    initTable[FacilityId, Facility](w.facilities.len.nextPowerOfTwo)
  result.byType = initTable[FacilityType, set[FacilityId]](2)
  for i in [FacilityType.CONTROL_CENTER, FacilityType.VEHICLE_FACTORY]:
    result.byType[i] = {}
  for f in w.facilities:
    let id = f.id.FacilityId
    result.byId[id] = f
    result.all.incl(id)
    result.byType[f.thetype].incl(id)
    if f.ownerPlayerId == -1:
      result.neutral.incl(id)
    elif f.ownerPlayerId == p.id:
      result.mine.incl(id)

proc update(self: var Facilities, w: World, myid: int64) =
  self.mine = {}
  for f in w.facilities:
    let id = f.id.FacilityId
    self.byId[id] = f
    if f.ownerPlayerId == -1:
      self.neutral.incl(id)
    elif f.ownerPlayerId == myid:
      self.mine.incl(id)
