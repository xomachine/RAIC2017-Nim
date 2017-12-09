from utils import Point
from borders import Vertex
from enhanced import EVehicle, Group, VehicleId
from analyze import WorldState
from tables import Table
from fastset import FastSet

type
  PartInfo* = tuple
    cluster: FastSet[VehicleId]
    center: Point
    vertices: array[16, Vertex]
    units: seq[EVehicle]
  FormationInfo* = tuple
    group: Group
    center: Point
    vertices: array[16, Vertex]
    units: seq[EVehicle]
    maxspeed: float
    support: seq[FastSet[VehicleId]]
    associatedClusters: Table[int, PartInfo]

proc updateFormationInfo*(self: Group, ws: WorldState, isAerial: bool): FormationInfo

from vehicles import resolve, toGroup
from borders import obtainCenter, obtainBorders
from fastset import intersects, empty, `-`, FastSet, `*`
from tables import `[]`, initTable, `[]=`
from model.vehicle_type import VehicleType
from gparams import flyers
from math import floor

proc slowestCellUnderUnits(ws: WorldState, units: seq[EVehicle]): float =
  result = 1000
  for u in units:
    let env = int(u.aerial)
    let t = u.thetype
    let celltype =
      if u.aerial:
        ws.world.weatherByCellXY[floor(u.x/32).int][floor(u.y/32).int].ord
      else:
        ws.world.terrainByCellXY[floor(u.x/32).int][floor(u.y/32).int].ord
    let speed = ws.gparams.speedByType[t.ord] *
                ws.gparams.speedFactorsByEnv[env][celltype]
    if speed < result:
      result = speed


proc updateFormationInfo(self: Group, ws: WorldState, isAerial: bool): FormationInfo =
  result.group = self
  let uset = ws.vehicles.byGroup[self]
  result.units = ws.vehicles.resolve(uset)
  if result.units.len() == 0:
    return
  result.maxspeed = slowestCellUnderUnits(ws, result.units)
  result.center = obtainCenter(result.units)
  result.vertices = obtainBorders(result.center, result.units)
  let (clusters, remaincluster) =
    if isAerial: (ws.vehicles.byMyAerialCluster, ws.vehicles.byMyGroundCluster)
    else: (ws.vehicles.byMyGroundCluster, ws.vehicles.byMyAerialCluster)
  result.associatedClusters = initTable[int, PartInfo]()
  for i, c in clusters.pairs():
    if c.cluster.intersects(uset):
      let remains =
        if isAerial: (c.cluster - uset) * ws.vehicles.aerials
        else: (c.cluster - uset) - ws.vehicles.aerials
      var pi: PartInfo
      if not remains.empty:
        pi.cluster = remains
        pi.units = ws.vehicles.resolve(remains)
        pi.center = obtainCenter(pi.units)
        pi.vertices = obtainBorders(pi.center, pi.units)
      result.associatedClusters[i] = pi

