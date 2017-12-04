from behavior import Behavior
from enhanced import Group

proc initCapture*(): Behavior

from analyze import WorldState
from behavior import BehaviorStatus
from formation_info import FormationInfo
from model.move import Move
from pf import formationVector, applyRepulsiveFormationField, applyVector, FieldGrid
from fastset import `==`

proc initCapture(): Behavior =
  var following = false
  result.reset = proc() =
    following = false
  result.tick = proc(ws: WorldState, fi: FormationInfo): BehaviorStatus =
    if following and ws.world.tickIndex mod 50 != 0:
      return BehaviorStatus.hold
    if ws.facilities.mine == ws.facilities.all:
      return BehaviorStatus.inactive
    return BehaviorStatus.act
  result.action = proc(ws: WorldState, fi: FormationInfo, m: var Move) =
    var field = ws.facilities.field
    for i, c in ws.vehicles.byMyGroundCluster.pairs():
      if i == fi.associatedClusterIdx:
        continue
      field.applyRepulsiveFormationField(c.center, c.vertices)
      var dummy: FieldGrid
      dummy.applyRepulsiveFormationField(c.center,c.vertices)
      echo "d", i, "=", $dummy.grid
    echo "ra =", $field.grid
    let vector = field.formationVector(fi.center, fi.vertices)
    m.applyVector(vector)
    following = true
