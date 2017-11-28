from tables import Table
from model.vehicle import Vehicle, update
from model.vehicle_type import VehicleType
from model.world import World
from model.game import Game
from model.player import Player
from enhanced import VehicleId, EVehicle, Group
from utils import Area

const maxHealthRange = 4

type
  HealthLevel* = 0..maxHealthRange
  Conv = proc (self: Vehicles): set[VehicleId]
  Vehicles* = tuple
    updated: set[VehicleId]
    mine: set[VehicleId]
    byType: Table[VehicleType, set[VehicleId]]
    byId: Table[VehicleId, EVehicle]
    byGroup: Table[Group, set[VehicleId]]
    byHealth: array[HealthLevel, set[VehicleId]]
    all: set[VehicleId]
    selected: set[VehicleId]
    aerials: set[VehicleId]
    clusterCacheInvalid: set[VehicleId]

proc initVehicles*(w: World, g: Game, p: Player): Vehicles
proc update*(self: var Vehicles, w: World, myid: int64)
proc resolve*(self: Vehicles, conds: Conv): seq[EVehicle]
proc inArea*(self: Vehicles, area: Area): set[VehicleId]
converter toType*(a: VehicleType): Conv
converter toGroup*(a: Group): Conv
converter toHealth*(a: HealthLevel): Conv
proc `*`*(a, b: Conv): Conv
proc `+`*(a, b: Conv): Conv
proc `-`*(a, b: Conv): Conv

from tables import initTable, `[]`, `[]=`, mgetOrPut, keys, del, contains, pairs
from math import nextPowerOfTwo
from enhanced import fromVehicle

converter toType(a: VehicleType): Conv =
  result = proc (self: Vehicles): set[VehicleId] = self.byType[a]
converter toGroup(a: Group): Conv =
  result = proc (self: Vehicles): set[VehicleId] = self.byGroup[a]
converter toHealth(a: HealthLevel): Conv =
  result = proc (self: Vehicles): set[VehicleId] = self.byHealth[a]
proc `*`(a, b: Conv): Conv =
  result = proc (self: Vehicles): set[VehicleId] = a(self) * b(self)
proc `+`(a, b: Conv): Conv =
  result = proc (self: Vehicles): set[VehicleId] = a(self) + b(self)
proc `-`(a, b: Conv): Conv =
  result = proc (self: Vehicles): set[VehicleId] = a(self) - b(self)
proc resolve(self: Vehicles, conds: Conv): seq[EVehicle] =
  let c = conds(self)
  result = newSeq[EVehicle](c.card)
  var i = 0
  for id in c:
    result[i] = self.byId[id]
    inc(i)

proc initVehicles(w: World, g: Game, p: Player): Vehicles =
  result.byId =
    initTable[VehicleId, EVehicle](w.newVehicles.len.nextPowerOfTwo)
  result.byType = initTable[VehicleType, set[VehicleId]](8)
  result.byGroup =
    initTable[Group, set[VehicleId]](g.maxUnitGroup.nextPowerOfTwo())
  result.update(w, p.id)

proc update(self: var Vehicles, w: World, myid: int64) =
  for v in w.newVehicles:
    let vehicle = fromVehicle(v)
    let id = vehicle.sid
    self.byId[id] = vehicle
    self.byType.mgetOrPut(v.thetype, {}).incl(id)
    self.byHealth[HealthLevel.high()].incl(id)
    if v.aerial:
      self.aerials.incl(id)
    if v.player_id == myid:
      self.mine.incl(id)
      self.byGroup.mgetOrPut(0, {}).incl(id)
  self.updated = {}
  for vu in w.vehicleUpdates:
    let id = vu.id.VehicleId
    let unit = self.byId[id]
    if vu.durability == 0:
      # dead
      self.selected.excl(id)
      self.aerials.excl(id)
      self.mine.excl(id)
      self.all.excl(id)
      self.byType[unit.thetype].excl(id)
      self.byId.del(id)
      for g in self.byGroup.keys():
        self.byGroup[g].excl(id)
      continue
    elif unit.durability != vu.durability:
      let tenmaximum = 10 / unit.maxDurability
      let healthstate =
        HealthLevel(int(vu.durability.float*tenmaximum) div maxHealthRange)
      let oldhealthstate =
        HealthLevel(int(unit.durability.float*tenmaximum) div maxHealthRange)
      if healthstate != oldhealthstate:
        self.byHealth[oldhealthstate].excl(id)
        self.byHealth[healthstate].incl(id)
      self.byId[id].durability = vu.durability
    if unit.player_id == myid:
      if vu.selected: self.selected.incl(id)
      else: self.selected.excl(id)
      if unit.x != vu.x or unit.y != vu.y:
        self.updated.incl(id)
        self.byId[id].x = vu.x
        self.byId[id].y = vu.y
      var newgroups: set[uint8]
      for g in vu.groups:
        newgroups.incl(g.Group)
      let oldgroups = unit.groups
      for g in (newgroups - oldgroups).items():
        self.byGroup[g].incl(id)
      for g in (oldgroups - newgroups).items():
        self.byGroup[g].excl(id)
      self.byId[id].groups = newgroups
      if vu.groups.len() > 0: self.byGroup[0].excl(id)
      else: self.byGroup[0].incl(id)
  self.clusterCacheInvalid = self.clusterCacheInvalid + self.updated

proc inArea(self: Vehicles, area: Area): set[VehicleId] =
  for k, v in self.byId.pairs:
    if v.x in area.left..area.right and v.y in area.top..area.bottom:
      result.incl(k)
