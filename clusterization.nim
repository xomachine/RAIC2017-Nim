from enhanced import VehicleId
from analyze import Vehicles

type Clusters* = seq[set[VehicleId]]
proc clusterize*(self: var Vehicles, unitset: set[VehicleId]): Clusters

const gridsize = 11
const thresh = 10
const squaredthresh = thresh * thresh
const maxsize = (1024 div gridsize) + 1

from tables import `[]`, initTable, contains, `[]=`
from model.unit import getSquaredDistanceTo

var cache = initTable[set[VehicleId], Clusters]()

proc clusterize(self: var Vehicles, unitset: set[VehicleId]): Clusters =
  if unitset in cache and card(unitset * self.clusterCacheInvalid) == 0:
    return cache[unitset]
  var data = newSeq[set[VehicleId]]()
  var indicies: set[uint16]
  var allclusters: set[VehicleId] # already finished units
  var grid: array[maxsize, array[maxsize, set[VehicleId]]]
  for id in unitset.items():
    # Filling the grid with units
    let unit = self.byId[id]
    let gridx = int(unit.x) div gridsize
    let gridy = int(unit.y) div gridsize
    grid[gridx][gridy].incl(id)
  for id in unitset.items():
    if id in allclusters:
      continue
    var newcluster: set[VehicleId]
    newcluster.incl(id)
    let unit = self.byId[id]
    let gridx = int(unit.x) div gridsize
    let gridy = int(unit.y) div gridsize
    # Checking neighbour cells
    for gx in (gridx-1)..(gridx+1):
      if gx notin 0..maxsize:
        continue
      for gy in (gridy-1)..(gridy+1):
        if gy notin 0..maxsize:
          continue
        let cell = grid[gx][gy]
        for nid in cell.items():
          let dst = self.byId[nid].getSquaredDistanceTo(unit.x, unit.y)
          if dst <= squaredthresh:
            newcluster.incl(nid)
    # Checking and uniting intersecting clusters
    var to_remove: set[VehicleId]
    for c in indicies:
      let cluster = data[c.int]
      if card(cluster * newcluster) == 0:
        to_remove.incl(c)
        newcluster = cluster + newcluster
    indicies = indicies - to_remove
    indicies.incl(data.len().uint16)
    data.add(newcluster)
    allclusters = allclusters + newcluster
  result = newSeq[set[VehicleId]](indicies.card())
  var i = 0
  for c in indicies:
    result[i] = data[c.int]
    inc(i)
  cache[unitset] = result
  self.clusterCacheInvalid = self.clusterCacheInvalid - unitset

