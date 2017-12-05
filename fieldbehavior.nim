from analyze import WorldState
from behavior import Behavior
from formation_info import FormationInfo
from pf import FieldGrid

type
  FieldBehavior* = tuple
    apply: proc(f: var FieldGrid, ws: WorldState, fi: FormationInfo)

proc initFieldBehaviors*(fbs: seq[FieldBehavior]): Behavior

from behavior import BehaviorStatus
from model.move import Move
from pf import EdgeField, applyVector, formationVector

proc initFieldBehaviors(fbs: seq[FieldBehavior]): Behavior =
  var field: FieldGrid = EdgeField
  var following = false
  const interval = 10
  result.reset = proc() =
    following = false
  result.tick = proc(ws: WorldState, fi: FormationInfo): BehaviorStatus =
    if ws.world.tickIndex mod interval == 0 or not following:
      BehaviorStatus.act
    else:
      BehaviorStatus.inactive
  result.action = proc(ws: WorldState, fi: FormationInfo, m: var Move) =
    for fb in fbs:
      fb.apply(field, ws, fi)
    let direction = field.formationVector(fi.center, fi.vertices)
    m.applyVector(direction)
    m.maxSpeed = fi.maxspeed
    following = true
    when defined(drawPFGrid):
      if ws.world.tickIndex mod 50 == 0:
        echo "!", $field.grid
  
