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
template debug*(v: string) =
  when defined(stdebug):
    echo v

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
