type
  PointConcept = concept u
    u.x is float64
    u.y is float64
  Point* = tuple
    x: float64
    y: float64
  Area* = tuple
    left: float64
    right: float64
    top: float64
    bottom: float64

proc areaFromUnits*(units: seq[PointConcept]): Area
proc inArea*(unit: PointConcept, a: Area): bool
proc getSqDistance*(u1, u2: PointConcept): float

from strutils import split

template debug*(v: string) =
  when defined(stdebug):
    const stdebug {.strdefine.}: string = "all"
    const files = stdebug.split({','})
    const ii = instantiationInfo()
    when stdebug == "all" or ii.filename in files:
      echo v

proc getSqDistance(u1, u2: PointConcept): float =
  let dx = (u1.x - u2.x)
  let dy = (u1.y - u2.y)
  dx*dx + dy*dy
proc inArea(unit: PointConcept, a: Area): bool =
  unit.x in a.left..a.right and unit.y in a.top..a.bottom
proc areaFromUnits(units: seq[PointConcept]): Area =
  result.left = 1024
  result.top = 1024
  for u in units:
    if u.x < result.left:
      result.left = u.x
    if u.x > result.right:
      result.right = u.x
    if u.y < result.top:
      result.top = u.y
    if u.y > result.bottom:
      result.bottom = u.y
