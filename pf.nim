from utils import Point
from enhanced import EVehicle, maxsize, gridsize
from math import sgn
from borders import Vertex
from model.move import Move

type
  FieldDescriptor* = proc(p: GridPoint): uint8
  GridPoint* = object
    x: int
    y: int
  Vector* = object
    x: float64
    y: float64
  FieldGrid* = tuple
    grid: array[maxsize, array[maxsize, uint8]]
    power: int

proc attractionPoint*(p: Point): FieldDescriptor {.inline.}
proc applyField*(self: var FieldGrid, descriptor: FieldDescriptor)
proc applyFields*(self: var FieldGrid, descriptors: seq[FieldDescriptor])
proc applyVector*(m: var Move, v: Vector) {.inline.}
proc pointAttractiveField(p, attractor: GridPoint): uint8 {.inline.}
proc getVector*(self: FieldGrid, p: Point): Vector {.inline.}
proc formationVector*(self: FieldGrid, c: Point,
                     verticies: array[16, Vertex]): Vector
proc applyAttackField*(self: var FieldGrid, center: Point,
                       vertices: array[16, Vertex])
proc applyRepulsiveFormationField*(self: var FieldGrid, center: Point,
                                   vertices: array[16, Vertex])
proc borderGrid(): FieldGrid
let EdgeField* = borderGrid()
proc `+`*(a, b: FieldGrid): FieldGrid

from model.action_type import ActionType
from tables import values
from utils import debug
from math import ln, log10, log2

template sqr[T: SomeNumber](a: T): T =
  a*a
proc gridFromPoint(p: Point): GridPoint {.inline.} =
  GridPoint(x: int(p.x / gridsize), y: int(p.y / gridsize))
proc `+=`(a: var Vector, b: Vector) {.inline.} =
  a.x = (a.x + b.x)/2
  a.y = (a.y + b.y)/2

proc attractionPoint(p: Point): FieldDescriptor =
  let gp = p.gridFromPoint()
  proc desc(p: GridPoint): uint8 =
    pointAttractiveField(p, gp)
  return desc

proc getVector(self: FieldGrid, p: Point): Vector =
  let gridpoint = gridFromPoint(p)
  let startx = max(gridpoint.x - 1, 0)
  let starty = max(gridpoint.y - 1, 0)
  let endx = min(gridpoint.x + 1, maxsize-1)
  let endy = min(gridpoint.y + 1, maxsize-1)
  const factor = 1024 div 256
  result.x = float(self.grid[startx][gridpoint.y] - self.grid[endx][gridpoint.y]) * factor
  result.y = float(self.grid[gridpoint.x][starty] - self.grid[gridpoint.x][endy]) * factor
  debug("Resultx: " & $result.x)
  debug("Resulty: " & $result.y)

proc formationVector(self: FieldGrid, c: Point,
                     verticies: array[16, Vertex]): Vector =
  result = self.getVector(c)
  for v in verticies:
    if v.distanceToCenter > 0:
      result += self.getVector(v.point)

proc applyVector(m: var Move, v: Vector) =
  m.action = ActionType.MOVE
  m.x = v.x
  m.y = v.y

proc pointRepulsiveField(p, distractor: GridPoint): uint8 =
  let distance = sqr(p.x - distractor.x) + sqr(p.y-distractor.y)
  if distance == 0: 255'u8
  else: min(255 div distance, 255).uint8
proc pointAttractiveField(p, attractor: GridPoint): uint8 =
  let distance = sqr(p.x - attractor.x) + sqr(p.y-attractor.y)
  const lg = (2*log10(maxsize.float))
  if distance == 0: 0'u8
  else: min(max(255*(log10(distance.float)/lg), 0), 255).uint8

proc borderField(p: GridPoint): uint8 =
  const cutoff = maxsize div 8
  let center = GridPoint(x: maxsize div 2, y: maxsize div 2)
  let relativeToCenter = GridPoint(x: p.x - center.x, y: p.y - center.y)
  let xcutoff = center.x - cutoff
  let ycutoff = center.y - cutoff
  min((sqr(max(abs(relativeToCenter.x) - xcutoff, 0)) +
       sqr(max(abs(relativeToCenter.y) - ycutoff, 0))), 255).uint8

proc applyFields(self: var FieldGrid, descriptors: seq[FieldDescriptor]) =
  let sumpower = self.power + descriptors.len()
  for i in 0..<maxsize:
    for j in 0..<maxsize:
      var fieldpoint: int = 0
      for d in descriptors:
        fieldpoint += d(GridPoint(x:i,y:j)).int
      self.grid[i][j] = min((fieldpoint +
                             self.power*self.grid[i][j].int) div sumpower, 255).uint8
  self.power = sumpower
proc applyField(self: var FieldGrid, descriptor: FieldDescriptor) =
  let sumpower = self.power + 1
  for i in 0..<maxsize:
    for j in 0..<maxsize:
      self.grid[i][j] = min((descriptor(GridPoint(x:i,y:j)).int +
                             self.power*self.grid[i][j].int) div sumpower, 255).uint8
  self.power = sumpower

proc borderGrid(): FieldGrid =
  result.power = 1
  for i in 0..<maxsize:
    for j in 0..<maxsize:
      result.grid[i][j] = borderField(GridPoint(x: i, y: j))

proc applyAttackField(self: var FieldGrid, center: Point,
                      vertices: array[16, Vertex]) =
  let centercell = center.gridFromPoint()
  var desc: FieldDescriptor = proc(p: GridPoint): uint8 =
    pointAttractiveField(p, centercell)
  self.applyField(desc)
  var maxdst:float = 0
  var maxdstid = -1
  for i, v in vertices.pairs():
    if v.distanceToCenter > 0:
      if v.distanceToCenter > maxdst:
        maxdst = v.distanceToCenter
        maxdstid = i
      closureScope:
        let cell = v.point.gridFromPoint()
        desc = proc(p:GridPoint): uint8 =
          pointAttractiveField(p, cell)
      self.applyField(desc)
  # applying weakest point id twice to make it more attractive
  let cell = vertices[maxdstid].point.gridFromPoint()
  desc = proc(p:GridPoint): uint8 =
    pointAttractiveField(p, cell)
  self.applyField(desc)

proc applyRepulsiveFormationField(self: var FieldGrid, center: Point,
                                  vertices: array[16, Vertex]) =
  let centercell = center.gridFromPoint()
  var desc: FieldDescriptor = proc(p: GridPoint): uint8 =
    pointRepulsiveField(p, centercell)
  self.applyField(desc)
  for v in vertices:
    if v.distanceToCenter > 0:
      closureScope:
        let cell = v.point.gridFromPoint()
        desc = proc(p:GridPoint): uint8 =
          pointRepulsiveField(p, cell)
      self.applyField(desc)

proc `+`(a, b: FieldGrid): FieldGrid =
  let sumpower = a.power + b.power
  for i in 0..<maxsize:
    for j in 0..<maxsize:
      result.grid[i][j] = min((a.grid[i][j].int*a.power +
                               b.grid[i][j].int*b.power) div sumpower, 255).uint8