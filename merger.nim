from behavior import Behavior

proc initMerger*(aerial: bool): Behavior

from analyze import WorldState, Players
from formation_info import FormationInfo
from enhanced import Group
from model.action_type import ActionType
from behavior import BehaviorStatus
from model.move import Move
from fastset import intersects, items
from tables import pairs, `[]`
from utils import debug, getSqDistance

proc initMerger(aerial: bool): Behavior =
  var targetgroup = 0.Group
  var merging = false
  result.reset = proc() =
    targetgroup = 0
    merging = false
  result.tick = proc(ws: WorldState, fi: FormationInfo): BehaviorStatus =
    if merging:
      return BehaviorStatus.actUnselected
    if fi.units.len > 20:
      return BehaviorStatus.inactive
    var mindist: float = 1024*1024*2
    var ming:Group
    for g, gset in ws.vehicles.byGroup.pairs:
      if g == fi.group or g < 2:
        # 1 and 0 are reserved
        continue
      let is_aerial = gset.intersects(ws.vehicles.aerials)
      if (is_aerial and aerial) or not (is_aerial or aerial):
        var distance: float = 1024*1024*2
        for us in gset:
          let u = ws.vehicles.byId[us]
          distance = fi.center.getSqDistance((x: u.x, y: u.y))
          break
        if distance < mindist:
          mindist = distance
          ming = g
    if mindist < 200*200*2:
      targetgroup = ming
      return BehaviorStatus.act
    return BehaviorStatus.inactive
  result.action = proc (ws: WorldState, fi: FormationInfo, m: var Move) =
    if merging:
      m.action = ActionType.DISBAND
      m.group = fi.group.int32
      debug("Disbanding " & $fi.group)
    else:
      debug("Merging " & $fi.group & " to " & $targetgroup)
      m.action = ActionType.ASSIGN
      m.group = targetgroup.int32
      merging = true


