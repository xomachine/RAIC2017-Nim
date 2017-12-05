from behavior import Behavior
from enhanced import Group

proc initCapture*(): Behavior

from analyze import WorldState
from behavior import BehaviorStatus
from formation_info import FormationInfo
from model.move import Move
from pf import formationVector, applyRepulsiveFormationField, applyVector,
               FieldGrid
from fastset import `==`, contains
from utils import debug
from tables import contains, `[]`

var taken = false
proc initCapture(): Behavior =
  var following = false
  var take = false
  result.reset = proc() =
    following = false
  result.tick = proc(ws: WorldState, fi: FormationInfo): BehaviorStatus =
    if not taken:
      take = true
      taken = true
    if following and ws.world.tickIndex mod 5 != 0:
      return BehaviorStatus.hold
    if ws.facilities.mine == ws.facilities.all:
      return BehaviorStatus.inactive
    return BehaviorStatus.act
  result.action = proc(ws: WorldState, fi: FormationInfo, m: var Move) =
    var field = ws.facilities.field
    #echo "ba =", $field.grid
    for i, c in ws.vehicles.byMyGroundCluster.pairs():
      if i in fi.associatedClusters:
        #debug($i & "'th cluster is skipped due to intersection with formation")
        #continue
        let remaining = fi.associatedClusters[i]
        if remaining.units.len() > 0:
          field.applyRepulsiveFormationField(remaining.center,
                                             remaining.vertices)
      else:
        field.applyRepulsiveFormationField(c.center, c.vertices)
      #var dummy: FieldGrid
      #dummy.applyRepulsiveFormationField(c.center,c.vertices)
      #echo "d", i, "=", $dummy.grid
    let vector = field.formationVector(fi.center, fi.vertices)
    when defined(drawPFGrid):
      if taken and ws.world.tickIndex mod 50 == 0:
        echo "!", $field.grid
    m.applyVector(vector)
    m.maxSpeed = fi.maxspeed
    following = true
