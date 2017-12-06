from fieldbehavior import FieldBehavior

proc initCollider*(aerial:bool): FieldBehavior

from analyze import WorldState
from formation_info import FormationInfo
from pf import FieldGrid, applyRepulsiveFormationField
from tables import contains, `[]`

proc initCollider(aerial: bool): FieldBehavior =
  result.apply = proc(f: var FieldGrid, ws: WorldState, fi: FormationInfo) =
    let coi =
      if aerial:ws.vehicles.byMyAerialCluster
      else:ws.vehicles.byMyGroundCluster
    for i, c in coi.pairs():
      if i in fi.associatedClusters:
        #debug($i & "'th cluster is skipped due to intersection with formation")
        #continue
        let remaining = fi.associatedClusters[i]
        if remaining.units.len() > 0:
          f.applyRepulsiveFormationField(remaining.center,
                                             remaining.vertices)
      else:
        f.applyRepulsiveFormationField(c.center, c.vertices)
      #var dummy: FieldGrid
      #dummy.applyRepulsiveFormationField(c.center,c.vertices)
      #echo "d", i, "=", $dummy.grid
