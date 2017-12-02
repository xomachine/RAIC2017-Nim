from utils import Point
from enhanced import EVehicle, maxsize, gridsize
from math import sgn
from borders import Vertex

type
  Some2D = concept d
    d.x is SomeNumber
    d.x is SomeNumber
  GridPoint = object
    x: int
    y: int
  Vector = object
    x: float64
    y: float64
  FieldGrid = array[maxsize, array[maxsize, Vector]]

proc getField*(self: FieldGrid, p: EVehicle): Vector {.inline.}
proc pointGrid*(p: Point, cutoff, power: float): FieldGrid
proc formationField*(center: Point, vertices: array[16, Vertex]): FieldGrid
proc `+`*(a, b: FieldGrid): FieldGrid
proc `-`(a, b: Some2D): Some2D {.inline.}

proc sqr(a: SomeNumber): SomeNumber {.inline.} =
  a*a

proc getField(self: FieldGrid, p: EVehicle): Vector =
  self[p.gridx][p.gridy]

proc pointField(p, distractor: GridPoint, cutoff, power: float): Vector =
  let relToPoint = p - distractor
  let distance = sqr(relToPoint.x) + sqr(relToPoint.y)
  let scutoff = sqr(cutoff)
  let shift = max(scutoff - distance.toFloat(), 0) * power
  Vector(x: shift*relToPoint.x.toFloat(), y: shift*relToPoint.y.toFloat())

proc borderField(p: GridPoint, width, height: int): Vector =
  let xpadding = width div 10
  let ypadding = height div 10
  let center = GridPoint(x: width div 2, y: height div 2)
  let toCenter: GridPoint = p - center
  let xcutoff = center.x - xpadding
  let ycutoff = center.y - ypadding
  let x = -sgn(toCenter.x) * sqr(max(abs(toCenter.x) - xcutoff, 0))
  let y = -sgn(toCenter.y) * sqr(max(abs(toCenter.y) - ycutoff, 0))
  Vector(x: x.toFloat(), y: y.toFloat())

proc pointGrid(p: Point, cutoff, power: float): FieldGrid =
  let pp = GridPoint(x: p.x.int div gridsize, y: p.y.int div gridsize)
  let gridoff = (cutoff.int div gridsize) + 1
  let startx = max(pp.x - gridoff, 0)
  let endx = min(pp.x + gridoff, maxsize-1)
  let endy = min(pp.y + gridoff, maxsize-1)
  let starty = max(pp.y - gridoff, 0)
  for i in startx..endx:
    for j in starty..endy:
      result[i][j] = pointField(GridPoint(x:i,y:j), pp, cutoff, power)

proc borderGrid(): FieldGrid =
  for i in 0..<maxsize:
    for j in 0..<maxsize:
      result[i][j] = borderField(GridPoint(x: i, y: j), maxsize, maxsize)

proc formationField(center: Point, vertices: array[16, Vertex]): FieldGrid =
  const cutoff = 50
  const power = 10
  result = pointGrid(center, cutoff, power)
  for v in vertices:
    if v.distanceToCenter > 0:
      result = result + pointGrid(v.point, cutoff/5, power)

proc `+`(a, b: Vector): Vector {.inline.} =
  result.x = (a.x + b.x)*abs(a.x)*abs(b.x)
  result.y = (a.y + b.y)*abs(a.y)*abs(b.y)
proc `-`(a, b: Some2D): Some2D =
  result.x = a.x - b.x
  result.y = a.y - b.y


proc `+`(a, b: FieldGrid): FieldGrid =
  for i in 0..<maxsize:
    for j in 0..<maxsize:
      result[i][j] = a[i][j] + b[i][j]
