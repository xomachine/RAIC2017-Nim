from enhanced import VehicleId
from vehicles import Vehicles
from sets import HashSet

type Clusters* = seq[HashSet[VehicleId]]
proc clusterize*(self: Vehicles, unitset: HashSet[VehicleId]): Clusters
proc invalidate*(updated: HashSet[VehicleId])

const gridsize = 11
const thresh = 10
const squaredthresh = thresh * thresh
const maxsize = (1024 div gridsize) + 1

from tables import `[]`, initTable, contains, `[]=`
from model.unit import getSquaredDistanceTo
from enhanced import EVehicle
from vehicles import resolve
from utils import debug
from sets import initSet, contains, incl, excl, items, card, `-`, `+`, `*`, init
from sequtils import toSeq

var cacheInValid = initSet[VehicleId]()

proc invalidate(updated: HashSet[VehicleId]) =
  cacheInValid = cacheInvalid + updated

{.push checks:off,optimization:speed.}
proc initGrid(): seq[array[maxsize, HashSet[VehicleId]]] =
  result = newSeq[array[maxsize, HashSet[VehicleId]]](maxsize)
  for i in 0..<result.len():
    for j in 0..<maxsize:
      result[i][j] = initSet[VehicleId]()

proc clusterize(self: Vehicles, unitset: HashSet[VehicleId]): Clusters =
  let units = self.resolve(unitset)
  let uc = toSeq(unitset.items)
  var cache {.global.} = initTable[seq[VehicleId], Clusters]()
  if uc in cache and card(unitset * cacheInValid) == 0:
    return cache[uc]
  var data = newSeq[HashSet[VehicleId]]()
  var indicies = initSet[VehicleId]()
  var allclusters: HashSet[VehicleId] # already finished units
  allclusters.init()
  # WARNING! stack size is not infinity!
  var grid = initGrid()
  #debug("Cluster alive!")
  for unit in units:
    # Filling the grid with units
    grid[unit.gridx][unit.gridy].incl(unit.sid)
  for unit in units:
    let id = unit.sid
    if id in allclusters:
      continue
    var newcluster = initSet[VehicleId]()
    newcluster.incl(id)
    # Checking neighbour cells
    for gx in (unit.gridx-1)..(unit.gridx+1):
      if gx notin 0..maxsize:
        continue
      for gy in (unit.gridy-1)..(unit.gridy+1):
        if gy notin 0..maxsize:
          continue
        let cell = grid[gx][gy]
        newcluster = newcluster + cell
        #for nid in cell.items():
        #  let dst = self.byId[nid].getSquaredDistanceTo(unit.x, unit.y)
        #  if dst <= squaredthresh:
        #    newcluster.incl(nid)
    # Checking and uniting intersecting clusters
    var to_remove = initSet[VehicleId]()
    for c in indicies:
      let cluster = data[c.int]
      if card(cluster * newcluster) == 0:
        to_remove.incl(c)
        newcluster = cluster + newcluster
    indicies = indicies - to_remove
    indicies.incl(data.len().uint16)
    data.add(newcluster)
    allclusters = allclusters + newcluster
  result = newSeq[HashSet[VehicleId]](indicies.card())
  var i = 0
  for c in indicies:
    result[i] = data[c.int]
    inc(i)
  cache[uc] = result
  cacheInvalid = cacheInvalid - unitset
{.pop.}
