from analyze import WorldState
from behavior import Behavior
from formation_info import FormationInfo
from pf import FieldGrid

type
  FieldBehavior* = tuple
    apply: proc(f: var FieldGrid, ws: WorldState, fi: FormationInfo)

proc initFieldBehaviors*(fbs: seq[FieldBehavior]): Behavior
proc resetField*(): FieldBehavior

from behavior import BehaviorStatus
from model.move import Move
from pf import EdgeField, applyVector, formationVector
from utils import debug

proc resetField(): FieldBehavior =
  result.apply = proc(f: var FieldGrid, ws: WorldState, fi: FormationInfo) =
    f = EdgeField

proc initFieldBehaviors(fbs: seq[FieldBehavior]): Behavior =
  var field: FieldGrid = EdgeField
  var following = false
  var lastupdated = -20000
  when defined(drawGrid):
    var lastupdatedgrid = -20000
  const interval = 15
  result.reset = proc() =
    following = false
  result.tick = proc(ws: WorldState, fi: FormationInfo): BehaviorStatus =
    if ws.world.tickIndex > lastupdated + interval:
      lastupdated = ws.world.tickIndex
      BehaviorStatus.act
    else:
      BehaviorStatus.inactive
  result.action = proc(ws: WorldState, fi: FormationInfo, m: var Move) =
    for fb in fbs:
      fb.apply(field, ws, fi)
    let direction = field.formationVector(fi.center, fi.vertices)
    m.applyVector(direction)
    debug($fi.group & ": vector = " & $m.x & ":" & $m.y)
    m.maxSpeed = fi.maxspeed
    following = true
    when defined(drawGrid):
      const drawGrid {.intdefine.}: int = 0
      when drawGrid == 0:
        echo "!", $field.grid
      else:
        if drawGrid == fi.group.int and
           ws.world.tickIndex > lastupdatedgrid + 100 + interval:
          lastupdatedgrid = ws.world.tickIndex
          echo "!", $field.grid
  
