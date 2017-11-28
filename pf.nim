from utils import Point
from math import sgn

const gridsize = 128
const staticWidth = 1024
const staticHeight = 1024
const cellWidth = staticWidth div gridsize
const cellHeight = staticHeight div gridsize
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
  FieldGrid = array[gridsize, array[gridsize, Vector]]

proc getSumField*(self: FieldGrid, p: Point): Vector
proc pointGrid*(p: Point, cutoff, power: float): FieldGrid
proc `-`(a, b: Some2D): Some2D {.inline.}

proc sqr(a: SomeNumber): SomeNumber =
  a*a

proc getSumField(self: FieldGrid, p: Point): Vector =
  let x = int(p.x) div cellWidth
  let y = int(p.y) div cellHeight
  self[x][y]

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
  let pp = GridPoint(x: p.x.int div cellWidth, y: p.y.int div cellHeight)
  for i in 0..<gridsize:
    for j in 0..<gridsize:
      result[i][j] = pointField(GridPoint(x:i,y:j), pp, cutoff, power)


proc borderGrid(): FieldGrid =
  for i in 0..<gridsize:
    for j in 0..<gridsize:
      result[i][j] = borderField(GridPoint(x: i, y: j), gridsize, gridsize)


proc `+`(a, b: Vector): Vector {.inline.} =
  result.x = a.x + b.x
  result.y = a.y + b.y
proc `-`(a, b: Some2D): Some2D =
  result.x = a.x - b.x
  result.y = a.y - b.y

proc `+`(a, b: FieldGrid): FieldGrid =
  for i in 0..<gridsize:
    for j in 0..<gridsize:
      result[i][j] = a[i][j] + b[i][j]

