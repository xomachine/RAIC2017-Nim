from utils import Point
from enhanced import EVehicle, maxsize, gridsize
from math import sgn
from borders import Vertex
from model.move import Move

type
  Intensity = uint16
  FieldDescriptor* = proc(p: GridPoint): Intensity
  GridPoint* = object
    x: int
    y: int
  Vector* = object
    x: float64
    y: float64
  FieldGrid* = tuple
    grid: array[maxsize, array[maxsize, Intensity]]
    maximum: Intensity
    minimum: Intensity
    power: int

proc normalize*(self: var Vector) {.inline.}
proc attractionPoint*(p: Point): FieldDescriptor {.inline.}
proc applyField*(self: var FieldGrid, descriptor: FieldDescriptor)
proc applyFields*(self: var FieldGrid, descriptors: seq[FieldDescriptor])
proc applyVector*(m: var Move, v: Vector) {.inline.}
proc pointAttractiveField(p, attractor: GridPoint): Intensity {.inline.}
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
from math import ln, log10, log2, sqrt

template sqr[T: SomeNumber](a: T): T =
  a*a
proc gridFromPoint(p: Point): GridPoint {.inline.} =
  GridPoint(x: int(p.x / gridsize), y: int(p.y / gridsize))
proc `+=`(a: var Vector, b: Vector) {.inline.} =
  a.x = (a.x + b.x)
  a.y = (a.y + b.y)

proc attractionPoint(p: Point): FieldDescriptor =
  let gp = p.gridFromPoint()
  proc desc(p: GridPoint): Intensity =
    pointAttractiveField(p, gp)
  return desc

proc normalize(self: var Vector) =
  let factor = 1024/max(self.x.abs, self.y.abs)
  #echo factor
  #echo self.x, ":", self.y
  self.x *= factor
  self.y *= factor

proc getVector(self: FieldGrid, p: Point): Vector =
  let gridpoint = gridFromPoint(p)
  let startx = max(gridpoint.x - 1, 0)
  let starty = max(gridpoint.y - 1, 0)
  let endx = min(gridpoint.x + 1, maxsize-1)
  let endy = min(gridpoint.y + 1, maxsize-1)
  var y: float = 0
  var x: float = 0
  for j in starty..<endy:
    for i in startx..<endx:
      y += self.grid[j][i].float - self.grid[j+1][i].float
      x += self.grid[j][i].float - self.grid[j][i+1].float
  #let y = self.grid[starty][gridpoint.x].float - self.grid[endy][gridpoint.x].float
  #let x = self.grid[gridpoint.y][startx].float - self.grid[gridpoint.y][endx].float
  #echo("Resultx: " & $result.x)
  #echo("Resulty: " & $result.y)
  #echo self.grid[starty][gridpoint.x], "-", self.grid[endy][gridpoint.x]
  #echo self.grid[gridpoint.y][startx], "-", self.grid[gridpoint.y][endx].float
  result.x = x
  result.y = y

proc formationVector(self: FieldGrid, c: Point,
                     verticies: array[16, Vertex]): Vector =
  result = self.getVector(c)
  for v in verticies:
    if v.distanceToCenter > 0:
      result += self.getVector(v.point)
  normalize(result)

proc applyVector(m: var Move, v: Vector) =
  m.action = ActionType.MOVE
  m.x = v.x
  m.y = v.y

proc pointRepulsiveField(p, distractor: GridPoint): Intensity =
  let distance = (sqr(p.x - distractor.x) + sqr(p.y-distractor.y)).float
  if distance == 0: Intensity.high
  else: Intensity(Intensity.high.float / sqrt(distance))
proc pointAttractiveField(p, attractor: GridPoint): Intensity =
  let distance = float(sqr(p.x - attractor.x) + sqr(p.y-attractor.y))
  const maxdstln = (2*log10(sqrt(2*sqr(maxsize).float)))
  if distance == 0: Intensity.low
  else: Intensity(Intensity.high.float*log10(distance)/maxdstln)

proc borderField(p: GridPoint): Intensity =
  const cutoff = maxsize div 8
  let center = GridPoint(x: maxsize div 2, y: maxsize div 2)
  let relativeToCenter = GridPoint(x: p.x - center.x, y: p.y - center.y)
  let xcutoff = center.x - cutoff
  let ycutoff = center.y - cutoff
  min((sqr(max(abs(relativeToCenter.x) - xcutoff, 0)) +
       sqr(max(abs(relativeToCenter.y) - ycutoff, 0))), Intensity.high.int).Intensity

proc applyFields(self: var FieldGrid, descriptors: seq[FieldDescriptor]) =
  let sumpower = self.power + descriptors.len()
  let minimum = self.minimum.int
  let diff = self.maximum.int - minimum
  let factor = self.power*Intensity.high.int/diff
  self.maximum = Intensity.low()
  self.minimum = Intensity.high()
  for y in 0..<maxsize:
    for x in 0..<maxsize:
      var fieldpoint: int = 0
      for d in descriptors:
        fieldpoint += d(GridPoint(x:x,y:y)).int
      self.grid[y][x] =
        Intensity((fieldpoint.float + factor *
                   float(self.grid[y][x].int - minimum))/
                   sumpower.float)
      self.maximum = max(self.grid[y][x], self.maximum)
      self.minimum = min(self.grid[y][x], self.minimum)
  self.power = sumpower
proc applyField(self: var FieldGrid, descriptor: FieldDescriptor) =
  let sumpower = self.power + 1
  let minimum = self.minimum.int
  let diff = self.maximum.int - minimum
  let factor = self.power*Intensity.high.int/diff
  self.maximum = Intensity.low()
  self.minimum = Intensity.high()
  for j in 0..<maxsize:
    for i in 0..<maxsize:
      self.grid[j][i] =
        Intensity((descriptor(GridPoint(x:i,y:j)).float +
                   factor*float(self.grid[j][i].int - minimum))/
                   sumpower.float)
      self.maximum = max(self.grid[j][i], self.maximum)
      self.minimum = min(self.grid[j][i], self.minimum)
  self.power = sumpower

proc borderGrid(): FieldGrid =
  result.power = 1
  result.maximum = Intensity.low()
  result.minimum = Intensity.high()
  for j in 0..<maxsize:
    for i in 0..<maxsize:
      result.grid[j][i] = borderField(GridPoint(x: i, y: j))
      result.maximum = max(result.grid[j][i], result.maximum)
      result.minimum = min(result.grid[j][i], result.minimum)

proc applyAttackField(self: var FieldGrid, center: Point,
                      vertices: array[16, Vertex]) =
  let centercell = center.gridFromPoint()
  var desc: FieldDescriptor = proc(p: GridPoint): Intensity =
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
        desc = proc(p:GridPoint): Intensity =
          pointAttractiveField(p, cell)
      self.applyField(desc)
  # applying weakest point id twice to make it more attractive
  let cell = vertices[maxdstid].point.gridFromPoint()
  desc = proc(p:GridPoint): Intensity =
    pointAttractiveField(p, cell)
  self.applyField(desc)

proc applyRepulsiveFormationField(self: var FieldGrid, center: Point,
                                  vertices: array[16, Vertex]) =
  let centercell = center.gridFromPoint()
  let cdesc: FieldDescriptor = proc(p: GridPoint): Intensity =
    pointRepulsiveField(p, centercell)
  self.applyField(cdesc)
  for v in vertices:
    if v.distanceToCenter > 0:
      #closureScope:
      let cell = v.point.gridFromPoint()
      let desc = proc(p:GridPoint): Intensity =
        pointRepulsiveField(p, cell)
      self.applyField(desc)

proc `+`(a, b: FieldGrid): FieldGrid =
  let sumpower = a.power + b.power
  result.maximum = Intensity.low()
  result.minimum = Intensity.high()
  let afactor = Intensity.high.int*a.power/int(a.maximum-a.minimum)
  let bfactor = Intensity.high.int*b.power/int(b.maximum-b.minimum)
  for j in 0..<maxsize:
    for i in 0..<maxsize:
      result.grid[j][i] =
        Intensity((float(a.grid[j][i].int - a.minimum.int)*afactor +
                   float(b.grid[j][i].int - b.minimum.int)*bfactor)/
                   sumpower.float)
      result.maximum = max(result.grid[j][i], result.maximum)
      result.minimum = min(result.grid[j][i], result.minimum)
