from utils import Point
from enhanced import EVehicle
from math import sqrt, sin, PI

type
  Vertex* = tuple
    distanceToCenter: float
    point: Point

proc obtainCenter*(units: seq[EVehicle]): Point
proc obtainBorders*(center: Point, units: seq[EVehicle]): array[16, Vertex]
proc area*(verticies: array[16, Vertex]): float

from algorithm import sortedByIt

proc obtainCenter(units: seq[EVehicle]): Point =
  ## Obtains units center using median algorithm
  let median = len(units) div 2
  let byx = units.sortedByIt(it.x)
  let byy = units.sortedByIt(it.y)
  (x: byx[median].x, y: byy[median].y)

proc obtainBorders(center: Point, units: seq[EVehicle]): array[16, Vertex] =
  ## Obtains units with maximal distance from center for 16 sectors
  #  const order = [13, 9,  1,  5, 4, 0,  8, 12, 14, 10, 2,  6, 7, 3, 11, 15]
  const reversed = [ 5, 2, 10, 13, 4, 3, 11, 12,  6,  1, 9, 14, 7, 0,  8, 15]
  # the order and reversed are the clockwise sectornums representation
  for vehicle in units:
    let relx = vehicle.x - center.x
    let rely = vehicle.y - center.y
    let arelx = relx * relx
    let arely = rely * rely
    let sectornum = (int(arelx>arely) shl 3) or
                    (int(max(arelx, arely)>4*min(arelx, arely)) shl 2) or
                    (int(rely<0) shl 1) or int(relx>0) 
    let orderedNum = reversed[sectornum]
    let distance = arelx + arely
    if result[orderedNum].distanceToCenter < distance:
      result[orderedNum] = (distanceToCenter: distance,
                            point: (x:vehicle.x, y: vehicle.y))

proc makeSinuses(): array[8, float] {.compileTime.} =
  for i in 0..<result.len():
    result[i] = sin(PI*i.toFloat()/16)/2

proc area(verticies: array[16, Vertex]): float =
  var last_point = -1
  var begining = -1
  const sinuses = makeSinuses()
  for i in 0..<32:
    let ap = i and 0xF
    if verticies[ap].distanceToCenter > 0:
      if last_point > 0:
        let skipped = i - last_point
        let li = last_point and 0xF
        if skipped < 8:
          # the distances are actually squared
          result += sqrt(verticies[li].distanceToCenter *
                         verticies[ap].distanceToCenter) * sinuses[skipped]
      if begining == -1:
        begining = ap
      elif ap == begining:
        break
      last_point = i
