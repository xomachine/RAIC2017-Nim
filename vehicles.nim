from tables import Table
from lists import DoublyLinkedList
from model.vehicle import Vehicle, update
from model.vehicle_type import VehicleType
from model.world import World
from model.game import Game
from model.player import Player
from enhanced import VehicleId, EVehicle, Group, gridsize, maxsize
from utils import Area
from fastset import FastSet
from pf import FieldGrid
from borders import Vertex
from utils import Point, debug

const maxHealthRange* = 4

type
  HealthLevel* = 0..maxHealthRange
  Conv = proc (self: Vehicles): FastSet[VehicleId]
  Cluster* = tuple
    cluster: FastSet[VehicleId]
    center: Point
    vertices: array[16, Vertex]
    size: int
  Vehicles* = tuple
    updated: FastSet[VehicleId]
    mine: FastSet[VehicleId]
    byType: Table[VehicleType, FastSet[VehicleId]]
    byId: Table[VehicleId, EVehicle]
    byGroup: Table[Group, FastSet[VehicleId]]
    byGrid: array[maxsize, array[maxsize, FastSet[VehicleId]]]
    byHealth: array[HealthLevel, FastSet[VehicleId]]
    byMyAerialCluster: seq[Cluster]
    byMyGroundCluster: seq[Cluster]
    byEnemyCluster: seq[Cluster]
    all: FastSet[VehicleId]
    selected: FastSet[VehicleId]
    aerials: FastSet[VehicleId]
    clusterUpdateRequired: FastSet[VehicleId]

proc initVehicles*(w: World, g: Game, p: Player): Vehicles
proc update*(self: var Vehicles, w: World, myid: int64)
proc resolve*(self: Vehicles, conds: Conv): seq[EVehicle]
proc resolve*(self: Vehicles, ids: FastSet[VehicleId]): seq[EVehicle]
proc inArea*(self: Vehicles, area: Area): FastSet[VehicleId]
converter toType*(a: VehicleType): Conv
converter toArea*(a: Area): Conv
converter toGroup*(a: Group): Conv
converter toHealth*(a: HealthLevel): Conv
proc `*`*(a, b: Conv): Conv
proc `+`*(a, b: Conv): Conv
proc `-`*(a, b: Conv): Conv

from tables import initTable, `[]`, `[]=`, mgetOrPut, keys, del, contains, pairs
from math import nextPowerOfTwo
from lists import initDoublyLinkedList, DoublyLinkedList, append, remove, nodes
from enhanced import fromVehicle, gridsize
from clusterization import clusterize
from borders import obtainCenter, obtainBorders
from algorithm import sort
#from sets import initSet, `*`, `+`, `-`, contains, items, card, init, incl, excl
from fastset import `*`, `+`, `-`, contains, items, card, incl, excl, clear,
                    intersects, `+=`

converter toType(a: VehicleType): Conv =
  result = proc (self: Vehicles): FastSet[VehicleId] = self.byType[a]
converter toArea(a: Area): Conv =
  result = proc (self: Vehicles): FastSet[VehicleId] = self.inArea(a)
converter toGroup(a: Group): Conv =
  result = proc (self: Vehicles): FastSet[VehicleId] =
    if a in self.byGroup: return self.byGroup[a]
    #else: initSet[VehicleId]()
converter toHealth(a: HealthLevel): Conv =
  result = proc (self: Vehicles): FastSet[VehicleId] = self.byHealth[a]
proc `*`(a, b: Conv): Conv =
  result = proc (self: Vehicles): FastSet[VehicleId] = a(self) * b(self)
proc `+`(a, b: Conv): Conv =
  result = proc (self: Vehicles): FastSet[VehicleId] = a(self) + b(self)
proc `-`(a, b: Conv): Conv =
  result = proc (self: Vehicles): FastSet[VehicleId] = a(self) - b(self)
proc resolve(self: Vehicles, conds: Conv): seq[EVehicle] =
  let c = conds(self)
  self.resolve(c)
proc resolve(self: Vehicles, ids: FastSet[VehicleId]): seq[EVehicle] =
  result = newSeq[EVehicle](ids.card)
  var i = 0
  for id in ids:
    if id in self.byId:
      result[i] = self.byId[id]
      inc(i)

proc initVehicles(w: World, g: Game, p: Player): Vehicles =
  result.byId =
    initTable[VehicleId, EVehicle](w.newVehicles.len.nextPowerOfTwo)
  result.byType = initTable[VehicleType, FastSet[VehicleId]](8)
  result.byMyAerialCluster = newSeq[Cluster]()
  result.byMyGroundCluster = newSeq[Cluster]()
  result.byEnemyCluster = newSeq[Cluster]()
  #for x in 0..<maxsize:
  #  for y in 0..<maxsize:
  #    result.byGrid[x][y] = initDoublyLinkedList[VehicleId]()
  for i in VehicleType.ARRV..VehicleType.TANK:
    result.byType[i] = FastSet[VehicleId]()
  result.byGroup =
    initTable[Group, FastSet[VehicleId]](g.maxUnitGroup.nextPowerOfTwo())
  result.update(w, p.id)

proc update(self: var Vehicles, w: World, myid: int64) =
  self.updated.clear()
  var updateRequired {.global.} = false
  for v in w.newVehicles:
    let vehicle = fromVehicle(v)
    let id = vehicle.sid
    self.byId[id] = vehicle
    self.byType[v.thetype].incl(id)
    self.byHealth[HealthLevel.high()].incl(id)
    self.byGrid[vehicle.gridx][vehicle.gridy].incl(id)
    if v.aerial:
      self.aerials.incl(id)
    if v.player_id == myid:
      self.mine.incl(id)
      self.byGroup.mgetOrPut(0, FastSet[VehicleId]()).incl(id)
    self.updated.incl(id)
    self.all.incl(id)
  for vu in w.vehicleUpdates:
    let id = vu.id.VehicleId
    let unit = self.byId[id]
    if vu.durability == 0:
      updateRequired = true
      self.selected.excl(id)
      self.aerials.excl(id)
      self.mine.excl(id)
      self.all.excl(id)
      self.byType[unit.thetype].excl(id)
      self.byId.del(id)
      self.byGrid[unit.gridx][unit.gridy].excl(id)
      for g in self.byGroup.keys():
        self.byGroup[g].excl(id)
      continue
    elif unit.durability != vu.durability:
      let healthstate =
        HealthLevel(int(vu.durability/unit.maxDurability) * maxHealthRange)
      let oldhealthstate =
        HealthLevel(int(unit.durability/unit.maxDurability) * maxHealthRange)
      if healthstate != oldhealthstate:
        self.byHealth[oldhealthstate].excl(id)
        self.byHealth[healthstate].incl(id)
      self.byId[id].durability = vu.durability
    if unit.x != vu.x or unit.y != vu.y:
      self.updated.incl(id)
      self.byId[id].x = vu.x
      self.byId[id].y = vu.y
      let gridx = vu.x.int div gridsize
      let gridy = vu.y.int div gridsize
      if gridx != unit.gridx or gridy != unit.gridy:
        self.byGrid[unit.gridx][unit.gridy].excl(id)
        self.byGrid[gridx][gridy].incl(id)
        self.byId[id].gridx = gridx
        self.byId[id].gridy = gridy
    if unit.player_id == myid:
      if vu.selected: self.selected.incl(id)
      else: self.selected.excl(id)
      var newgroups: set[uint8]
      for g in vu.groups:
        newgroups.incl(g.Group)
      let oldgroups = unit.groups
      for g in (newgroups - oldgroups).items():
        self.byGroup.mgetOrPut(g, FastSet[VehicleId]()).incl(id)
      for g in (oldgroups - newgroups).items():
        self.byGroup[g].excl(id)
      self.byId[id].groups = newgroups
      if vu.groups.len() > 0: self.byGroup[0].excl(id)
      else: self.byGroup[0].incl(id)
  self.clusterUpdateRequired += self.updated
  if w.tickIndex mod 10 == 0:
    let enemyset = self.all - self.mine
    if updateRequired or self.clusterUpdateRequired.intersects(enemyset):
      let enemies = self.clusterize(enemyset)
      debug("Detected " & $enemies.len() & " enemy clusters")
      self.byEnemyCluster.setLen(enemies.len())
      for i, e in enemies.pairs():
        let units = self.resolve(e)
        let center = obtainCenter(units)
        let vertices = obtainBorders(center, units)
        self.byEnemyCluster[i] = (cluster: e, center: center,
                                  vertices: vertices, size: units.len)
    self.byEnemyCluster.sort do (x, y: Cluster) -> int:
      result = -cmp(x.size, y.size)
    let mineaerial = self.mine * self.aerials
    let mineground = self.mine - mineaerial
    if updateRequired or self.clusterUpdateRequired.intersects(mineground):
      let mine = self.clusterize(mineground)
      debug("Detected " & $mine.len() & " my ground clusterss")
      self.byMyGroundCluster.setLen(mine.len())
      for i, e in mine.pairs():
        let units = self.resolve(e)
        let center = obtainCenter(units)
        let vertices = obtainBorders(center, units)
        self.byMyGroundCluster[i] = (cluster: e, center: center,
                                     vertices: vertices, size: units.len)
    if updateRequired or self.clusterUpdateRequired.intersects(mineaerial):
      let mine = self.clusterize(mineaerial)
      debug("Detected " & $mine.len() & " my aerial clusterss")
      self.byMyAerialCluster.setLen(mine.len())
      for i, e in mine.pairs():
        let units = self.resolve(e)
        let center = obtainCenter(units)
        let vertices = obtainBorders(center, units)
        self.byMyAerialCluster[i] = (cluster: e, center: center,
                                     vertices: vertices, size: units.len)
    self.clusterUpdateRequired.clear()
    updateRequired = false

proc inArea(self: Vehicles, area: Area): FastSet[VehicleId] =
  #result = initSet[VehicleId]()
  for k, v in self.byId.pairs:
    if v.x in area.left..area.right and v.y in area.top..area.bottom:
      result.incl(k)
