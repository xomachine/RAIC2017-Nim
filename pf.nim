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
  PointField* = tuple
    point: GridPoint
    power: float

proc normalize*(self: var Vector) {.inline.}
proc gridFromPoint*(p: Point): GridPoint {.inline.}
proc applyField*(self: var FieldGrid, descriptor: FieldDescriptor)
proc applyFields*(self: var FieldGrid, descriptors: seq[PointField])
proc applyRepairFields*(self: var FieldGrid, descriptors: seq[PointField])
proc applyVector*(m: var Move, v: Vector) {.inline.}
#proc pointAttractiveField(p, attractor: GridPoint): Intensity {.inline.}
proc getVector*(self: FieldGrid, p: Point): Vector {.inline.}
proc formationVector*(self: FieldGrid, c: Point,
                     verticies: array[16, Vertex]): Vector
proc applyAttackField*(self: var FieldGrid, center: Point,
                       vertices: array[16, Vertex], eff: float)
proc applyRepulsiveFormationField*(self: var FieldGrid, center: Point,
                                   vertices: array[16, Vertex], ground: bool)
proc borderGrid(): FieldGrid
let EdgeField* = borderGrid()
proc `+`*(a, b: FieldGrid): FieldGrid

from model.action_type import ActionType
from tables import values
from utils import debug
from bitops import fastLog2
from math import sqrt, log10, cos, PI

template sqr[T: SomeNumber](a: T): T =
  a*a
proc gridFromPoint(p: Point): GridPoint =
  GridPoint(x: int(p.x / gridsize), y: int(p.y / gridsize))
proc `+=`(a: var Vector, b: Vector) {.inline.} =
  a.x = (a.x + b.x)
  a.y = (a.y + b.y)

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

template pointRepulsiveField(p, distractor: GridPoint): Intensity =
  let distance = (sqr(p.x - distractor.x) + sqr(p.y-distractor.y)).float.sqrt
  const safedst = 96/16
  const safeln = 1/(safedst+1)
  if distance < 0: Intensity.high
    #Intensity(min(1,(cos(sqrt(distance)/safedst*PI)+1)/2*(1-safeln)+
    #          safeln) * Intensity.high.float)
  else: Intensity(Intensity.high.float / (distance))
template pointAttractiveField*(p, attractor: GridPoint): Intensity =
  let distance = float(sqr(p.x - attractor.x) + sqr(p.y-attractor.y))
  const maxdstln = (2*log10(2*sqr(maxsize).float))
  if distance == 0: Intensity.low
  else: Intensity(Intensity.high.float*log10(distance)/maxdstln)
  #Intensity(Intensity.high.float*distance/(6+distance))
template repairField(p, rp: GridPoint): Intensity =
  let distance = sqr(p.x - rp.x) + sqr(p.y-rp.y)
  Intensity(Intensity.high.int*distance/(2*sqr(maxsize)))
template attackField(p, enemy: GridPoint, eff: float): Intensity =
  const safedst = 96/16
  const safedstsq = sqr(safedst).int
  #const maxdstln = (2*log10(2*sqr(maxsize).float))
  #const safeln = log10(safedst+1)/maxdstln
  #const safeln = safedstsq/(128+128*safedst+safedstsq)
  #const safeln = Intensity.high.int / 2
  const safeln = safedst/(2*sqr(maxsize))
  let distance = float(sqr(p.x - enemy.x) + sqr(p.y-enemy.y))
  if eff >= 0:
    Intensity((Intensity.high.float*distance)/(1+4*eff*distance.sqrt+distance))
  elif distance >= safedstsq:
    Intensity(Intensity.high.float*distance/(2*sqr(maxsize)))
    #Intensity(Intensity.high.float*log10(distance+1)/maxdstln)
    #Intensity.high() div 2
    #Intensity((Intensity.high.float*distance)/(128+64*distance.sqrt+distance))
  else:
    Intensity(min(1,(cos(sqrt(distance)/safedst*PI)+1)/2*((1-eff)*1-safeln)+
               safeln) * Intensity.high.float)
#    Intensity(Intensity.high.float* (safedst.float + (distance.toFloat()*eff/2))/safedst.float)

proc borderField(p: GridPoint): Intensity =
  const cutoff = maxsize div 32
  let center = GridPoint(x: maxsize div 2, y: maxsize div 2)
  let relativeToCenter = GridPoint(x: p.x - center.x, y: p.y - center.y)
  let xcutoff = center.x - cutoff
  let ycutoff = center.y - cutoff
  min((sqr(max(abs(relativeToCenter.x) - xcutoff, 0)) +
       sqr(max(abs(relativeToCenter.y) - ycutoff, 0))), Intensity.high.int).Intensity

template withField(self: var FieldGrid, actions: untyped) {.dirty.} =
  let minimum = self.minimum.int
  let diff = self.maximum.int - minimum
  let factor = self.power*Intensity.high.int/diff
  self.maximum = Intensity.low()
  self.minimum = Intensity.high()
  for y in 0..<maxsize:
    for x in 0..<maxsize:
      let oldfield = factor * float(self.grid[y][x].int - minimum)
      self.grid[y][x] = Intensity(actions)
      self.maximum = max(self.grid[y][x], self.maximum)
      self.minimum = min(self.grid[y][x], self.minimum)

proc applyAttackFields(self: var FieldGrid, descriptors: seq[PointField]) =
  let sumpower = descriptors.len + self.power
  withField(self):
    var fieldPoint: float = 0
    for d in descriptors:
      fieldPoint += attackField(GridPoint(x:x, y:y), d.point, d.power).float
    (oldfield + fieldPoint)/sumpower.float
  self.power = sumpower

proc applyRepairFields(self: var FieldGrid, descriptors: seq[PointField]) =
  let sumpower = descriptors.len + self.power
  withField(self):
    var fieldPoint: float = 0
    for d in descriptors:
      fieldPoint += repairField(GridPoint(x:x, y:y), d.point).float * -d.power
    (oldfield + fieldPoint)/sumpower.float
  self.power = sumpower

proc applyFields(self: var FieldGrid, descriptors: seq[PointField]) =
  let sumpower = self.power + descriptors.len()
  withField(self):
    var fieldpoint: float64 = 0
    for d in descriptors:
      if d.power >= 0:
        fieldpoint +=
          pointRepulsiveField(GridPoint(x:x, y:y), d.point).float * d.power
      else:
        fieldpoint +=
          -pointAttractiveField(GridPoint(x:x, y:y), d.point).float * d.power
    (oldfield + fieldpoint)/sumpower.float
  self.power = sumpower

proc applyField(self: var FieldGrid, descriptor: FieldDescriptor) =
  let sumpower = self.power + 1
  withField(self):
    (descriptor(GridPoint(x:x,y:y)).float + oldfield)/sumpower.float
  self.power = sumpower

proc borderGrid(): FieldGrid =
  result.power = 1
  withField(result):
    borderField(GridPoint(x: x, y: y))

proc applyAttackField(self: var FieldGrid, center: Point,
                      vertices: array[16, Vertex], eff: float) =
  let centercell = center.gridFromPoint()
  var descriptors = newSeq[PointField]()
  descriptors.add((point: centercell, power: eff))
  var maxdst:float = 0
  var maxdstid = -1
  var amount = 1
  for i, v in vertices.pairs():
    if v.distanceToCenter > 0:
      if v.distanceToCenter > maxdst:
        maxdst = v.distanceToCenter
        maxdstid = i
      let cell = v.point.gridFromPoint()
      var uniq = true
      for c in descriptors:
        if c.point == cell:
          uniq = false
          break
      if uniq:
        descriptors.add((point: cell, power: eff))
        inc(amount)
  # applying weakest point id twice to make it more attractive
  for d in descriptors.mitems():
    d.power *= 1/amount
  if maxdstid > 0:
    let cell = vertices[maxdstid].point.gridFromPoint()
    descriptors.add((point: cell, power: 0.5))
  self.applyAttackFields(descriptors)

proc applyRepulsiveFormationField(self: var FieldGrid, center: Point,
                                  vertices: array[16, Vertex], ground: bool) =
  let centercell = center.gridFromPoint()
  var points = newSeq[PointField]()
  points.add((point: centercell, power: 3.0 + 2*ground.float))
  var amount = 1
  for v in vertices:
    if v.distanceToCenter > 0:
      #closureScope:
      let cell = v.point.gridFromPoint()
      var uniq = true
      for c in points:
        if c.point == cell:
          uniq = false
          break
      if uniq:
        points.add((point: cell, power: 3.0 + ground.float))
        inc(amount)
  for d in points.mitems():
    d.power /= amount.float
  self.applyFields(points)

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
