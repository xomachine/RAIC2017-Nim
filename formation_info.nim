from utils import Point
from borders import Vertex
from enhanced import EVehicle, Group
from analyze import WorldState

type
  FormationInfo* = tuple
    center: Point
    vertices: array[16, Vertex]
    units: seq[EVehicle]
    associatedClusterIdx: int

proc updateFormationInfo*(self: Group, ws: WorldState, isAerial: bool): FormationInfo

from vehicles import resolve, toGroup
from borders import obtainCenter, obtainBorders

proc updateFormationInfo(self: Group, ws: WorldState, isAerial: bool): FormationInfo =
  result.units = ws.vehicles.resolve(self)
  if result.units.len() == 0:
    return
  result.center = obtainCenter(result.units)
  result.vertices = obtainBorders(result.center, result.units)
  var mindist: float = 1024
  let clusters = 
    if isAerial: ws.vehicles.byMyAerialCluster
    else: ws.vehicles.byMyGroundCluster
  for i, c in clusters.pairs():
    let dist = abs(c.center.x - result.center.x) +
               abs(c.center.y - result.center.y)
    if dist < mindist:
      mindist = dist
      result.associatedClusterIdx = i

