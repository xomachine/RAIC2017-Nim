from tables import Table
from model.facility import Facility
from model.facility_type import FacilityType
from model.player import Player
from model.world import World
from enhanced import FacilityId
from pf import FieldGrid
from fastset import FastSet

type
  Facilities* = tuple
    byId: Table[FacilityId, Facility]
    byType: Table[FacilityType, FastSet[FacilityId]]
    mine: FastSet[FacilityId]
    neutral: FastSet[FacilityId]
    all: FastSet[FacilityId]
    field: FieldGrid

proc initFacilities*(w: World, p: Player): Facilities
proc update*(self: var Facilities, w: World, myid: int64)
proc genFacilityField(self: Facilities, myid: int64): FieldGrid

from tables import initTable, `[]`, `[]=`, mgetOrPut, values, len
from math import nextPowerOfTwo
from pf import applyField, EdgeField, PointField, applyFields, gridFromPoint
from fastset import incl, excl

proc genFacilityField(self: Facilities, myid: int64): FieldGrid =
  result = EdgeField
  var descs = newSeqOfCap[PointField](self.byId.len)
  for f in self.byId.values:
    if f.ownerPlayerId != myid:
      let p = (x: f.left+30, y: f.top+30)
      if f.theType == FacilityType.VEHICLE_FACTORY:
        descs.add((point: p.gridFromPoint, power: -1.0))
      else:
        descs.add((point: p.gridFromPoint, power: -0.8))
      #echo "Attraction point:", $p
      #result.applyField(attractionPoint(p))
      #var dummy: FieldGrid
      #dummy.applyField(attractionPoint(p))
      #echo "d=", $dummy
  result.applyFields(descs)
proc initFacilities(w: World, p: Player): Facilities =
  result.byId =
    initTable[FacilityId, Facility](w.facilities.len.nextPowerOfTwo)
  result.byType = initTable[FacilityType, FastSet[FacilityId]](2)
  for i in [FacilityType.CONTROL_CENTER, FacilityType.VEHICLE_FACTORY]:
    result.byType[i] = FastSet[FacilityId]()
  for f in w.facilities:
    let id = f.id.FacilityId
    result.byId[id] = f
    result.all.incl(id)
    result.byType[f.thetype].incl(id)
    if f.ownerPlayerId == -1:
      result.neutral.incl(id)
    elif f.ownerPlayerId == p.id:
      result.mine.incl(id)
  result.field = result.genFacilityField(p.id)

proc update(self: var Facilities, w: World, myid: int64) =
  var updateRequired = false
  for f in w.facilities:
    let id = f.id.FacilityId
    let prev = self.byId[id]
    if prev.ownerPlayerId != f.ownerPlayerId:
      # if owner changed
      updateRequired = true
      if prev.ownerPlayerId == -1:
        self.neutral.excl(id)
      elif prev.ownerPlayerId == myid:
        self.mine.excl(id)
      if f.ownerPlayerId == -1:
        self.neutral.incl(id)
      elif f.ownerPlayerId == myid:
        self.mine.incl(id)
    self.byId[id] = f
  if updateRequired:
    self.field = self.genFacilityField(myid)
