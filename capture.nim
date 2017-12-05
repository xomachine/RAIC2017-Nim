from fieldbehavior import FieldBehavior

proc initCapture*(): FieldBehavior

from analyze import WorldState
from formation_info import FormationInfo
from pf import FieldGrid

proc initCapture(): FieldBehavior =
  result.apply = proc(f: var FieldGrid, ws: WorldState, fi: FormationInfo) =
    f = ws.facilities.field
