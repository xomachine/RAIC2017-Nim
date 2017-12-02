from enhanced import VehicleId
from vehicles import Vehicles
from fastset import FastSet

type Clusters* = seq[FastSet[VehicleId]]
proc clusterize*(self: Vehicles, unitset: FastSet[VehicleId]): Clusters
proc invalidate*(updated: FastSet[VehicleId])

const thresh = 10
const squaredthresh = thresh * thresh

from tables import `[]`, initTable, contains, `[]=`
from lists import items, initDoublyLinkedList, remove, append, nodes
from model.unit import getSquaredDistanceTo
from enhanced import EVehicle, maxsize
from vehicles import resolve
from utils import debug
#from sets import initSet, contains, incl, excl, items, card, `-`, `+`, `*`, init
from fastset import contains, incl, excl, items, card, `-`, `+`, `*`,
                    intersects, `+=`, `-=`
from sequtils import toSeq

#var cacheInValid = initSet[VehicleId]()
var cacheInValid: FastSet[VehicleId]
proc invalidate(updated: FastSet[VehicleId]) =
  cacheInValid += updated

{.push checks:off,optimization:speed.}

proc clusterize(self: Vehicles, unitset: FastSet[VehicleId]): Clusters =
  let units = self.resolve(unitset)
  #let uc = toSeq(unitset.items())
  #var cache {.global.} = initTable[seq[VehicleId], Clusters]()
  #if uc in cache and card(unitset * cacheInValid) == 0:
  #  return cache[uc]
  var clusters = initDoublyLinkedList[FastSet[VehicleId]]()
  var allclusters: FastSet[VehicleId] # already finished units
  # WARNING! stack size is not infinity!
  for unit in units:
    let id = unit.sid
    if id in allclusters:
      continue
    var newcluster = FastSet[VehicleId]()
    newcluster.incl(id)
    # Checking neighbour cells
    for gx in (unit.gridx-1)..(unit.gridx+1):
      if gx notin 0..maxsize:
        continue
      for gy in (unit.gridy-1)..(unit.gridy+1):
        if gy notin 0..maxsize:
          continue
        let cell = self.byGrid[gx][gy]
        #newcluster = newcluster + cell
        for nid in cell.items():
          let dst = self.byId[nid].getSquaredDistanceTo(unit.x, unit.y)
          if dst <= squaredthresh:
            newcluster.incl(nid)
    # Checking and uniting intersecting clusters
    if newcluster.intersects(allclusters):
      for cn in clusters.nodes():
        let cluster = cn.value
        if cluster.intersects(newcluster):
          clusters.remove(cn)
          newcluster += cluster
    clusters.append(newcluster)
    allclusters += newcluster
  result = newSeq[FastSet[VehicleId]]()
  for c in clusters:
    result.add(c)
  #cache[uc] = result
  #cacheInvalid = cacheInvalid - unitset
{.pop.}
