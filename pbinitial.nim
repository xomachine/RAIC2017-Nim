from pbehavior import PlayerBehavior
from vehicles import Vehicles
from model.vehicle_type import VehicleType

proc initInitial*(types: seq[VehicleType], v: Vehicles): PlayerBehavior

from tables import `[]`
from fastset import `*`, card, `+`, `-`, clear, FastSet, empty, `+=`, intersects
from model.move import Move
from actions import newSelection, actmove, group, ungroup, addToSelection
from actionchain import initActionChain, ActionChain
from pbactions import addPBehavior, addFormation
from analyze import WorldState
from gparams import flyers
from condactions import atMoveEnd
from formation import newGroundFormation, newAerialFormation, Formation
from enhanced import VehicleId, Group
from groupcounter import GroupCounter, getFreeGroup
from pbehavior import PBResult, PBRType, Action
from vehicles import resolve, toType, toArea, inArea, `*`
from utils import Area, Point, areaFromUnits, debug
from production import initProduction

const hi = 18.0
const lo = 220.0
const spawnArea: Area = (left: hi, right: lo, top: hi, bottom: lo)
const linewidth = (lo - hi) / 3
const alines = [
  (left: hi, right: lo, top: hi, bottom: hi + linewidth),
  (left: hi, right: lo, top: hi + linewidth, bottom: lo - linewidth),
  (left: hi, right: lo, top: lo - linewidth, bottom: lo),
]
const acols = [
  (left: hi, right: hi + linewidth, top: hi, bottom: lo),
  (left: hi + linewidth, right: lo - linewidth, top: hi, bottom: lo),
  (left: lo - linewidth, right: lo, top: hi, bottom: lo),
]


proc pick[T](self: set[T]): T {.inline.} =
  for i in self:
    return i
proc pop[T](self: var set[T]): T {.inline.} =
  let picked: T = self.pick()
  self.excl(picked)
  return picked

proc devide(a: Area, parts: Natural, every: proc(i: int, pa: Area): seq[Action]): seq[Action] =
  result = newSeq[Action]()
  let aheight = a.bottom - a.top + 4
  let step = aheight / parts.float
  debug("Deviding " & $aheight & " for 10 parts with step " & $step)
  for i in 0..<parts:
    let top = a.top + step*i.float - 2
    let pa = (left: a.left, right: a.right, top: top, bottom: top+step)
    result &= every(i, pa)

proc oneByLine(ws: WorldState, types: seq[VehicleType],
               colstarts: array[3, float]): seq[ActionChain] =
  let v = ws.vehicles
  result = newSeq[ActionChain]()
  let nonmovables = v.byType[VehicleType.TANK] +
                    v.byType[VehicleType.HELICOPTER]
  var perline: array[3, FastSet[VehicleId]]
  var percol: array[3, FastSet[VehicleId]]
  var freeCols: set[uint8]
  var overquotted: uint8
  var overquottedLen = 0
  var toi: FastSet[VehicleId]
  #toi.init()
  for t in types:
    toi += v.byType[t]
  for l in 0'u8..2'u8:
    perline[l] = v.inArea(alines[l]) * toi
  for c in 0'u8..2'u8:
    percol[c] = v.inArea(acols[c]) * toi
    let size = card(percol[c])
    if size == 0:
      freeCols.incl(c)
    elif size > 100:
      overquotted = c
      overquottedLen = size
  var shifted: FastSet[VehicleId]
  #shifted.init()
  debug($freeCols)
  debug("Overquotted col: " & $overquotted & " has len " & $overquottedLen)
  while overquottedLen > 100:
    let targetcol = freeCols.pop()
    let toshift = percol[overquotted] - (nonmovables + shifted)
    let realtoshift =
      if card(toshift) > 100: toshift - v.byType[VehicleType.IFV]
      else: toshift
    shifted = shifted + realtoshift
    let tsarea = areaFromUnits(v.resolve(realtoshift))
    var shift = (x: colstarts[targetcol]-colstarts[overquotted], y: 0.0)
    if overquotted != 1 and targetcol != 1:
      var shiftline = -1
      for l in 0'u8..2:
        if perline[l].intersects(realtoshift):
          debug("Shifting squad on line " & $l)
          shiftline = l
          break
      debug("In first col detected: " & $percol[1].card)
      debug("In target line detected: " & $perline[shiftline].card)
      let obstacle = percol[1] * perline[shiftline]
      if not obstacle.empty:
        debug("Obstacle detected")
        let obstaclearea = areaFromUnits(v.resolve(obstacle))
        let oshift = (x: colstarts[targetcol]-colstarts[1], y: 0.0)
        result.add(@[
          newSelection(obstaclearea),
          actmove(oshift),
          atMoveEnd(obstacle),
        ])
        shift = (x: colstarts[1]-colstarts[overquotted], y: 0.0)
    result.add(@[
      newSelection(tsarea),
      actmove(shift),
      atMoveEnd(realtoshift),
    ])
    overquottedLen -= 100


proc spread(v: Vehicles, types: seq[VehicleType]): seq[ActionChain] =
  result = newSeq[ActionChain]()
  for t in types:
    debug("Processing " & $t)
    let vehs = v.byType[t] * v.mine
    let varea = areaFromUnits(v.resolve(vehs))
    let factor = if t.ord in flyers: 2'f64 else: 3'f64
    proc every(i: int, pa: Area): ActionChain =
      let step = pa.bottom - pa.top
      let typeshift =
        if t.ord in [0, 1]: step
        elif t == VehicleType.IFV: -step
        else: 0
      let y = hi + typeshift + i.float * factor * step - pa.top
      debug("Partshift for " & $pa.top & ": " & $y)
      let shift = (x: 0.0,
                   y: y)
      result = @[
        newSelection(pa, t),
        actmove(shift)
      ]
    result.add(devide(varea, 10, every) & @[atMoveEnd(vehs)])

proc merge(v: Vehicles, types: seq[VehicleType],
           colstarts: array[3, float]): seq[ActionChain] =
  result = newSeq[ActionChain]()
  for t in types:
    let vehs = v.byType[t] * v.mine
    let varea = areaFromUnits(v.resolve(vehs))
    let shift = (x: colstarts[1] - varea.left, y: 0.0)
    result.add(@[
      newSelection(varea, t),
      actmove(shift),
      atMoveEnd(vehs),
    ])

proc makeFormations(ws: WorldState, types: seq[VehicleType],
                   gc: var GroupCounter): seq[ActionChain] =
  let v = ws.vehicles
  result = newSeq[ActionChain]()
  let aerial = types[0].ord in flyers
  let uset =
    if not aerial: v.mine - v.aerials
    else: v.aerials * v.mine
  let units = v.resolve(uset)
  debug($types.len & ":Units to get area: " & $units.len())
  let aarea = areaFromUnits(units)
  debug($types.len & ":Full area: " & $aarea)
  var groups = newSeq[Group](types.len)
  # to avoid illegal capture of gc
  for i in 0..<types.len:
    groups[i] = gc.getFreeGroup()
  proc every(i: int, pa: Area): ActionChain =
    let ngroup = groups[i]
    result = newSeq[Action]()
    var act = true
    for t in types:
      if act == true:
        result.add(newSelection(pa, t))
        act = false
      else:
        result.add(addToSelection(pa, t))
    debug("NewFormation for group: " & $ngroup)
    debug("NewFormation for area: " & $pa)
    result.add(group(ngroup))
    result.add(addFormation(ngroup, aerial))
  var chain = devide(aarea, types.len, every)
  if not aerial:
    chain.add(addPBehavior(initProduction(ws.game)))
  result &= chain


proc initInitial(types: seq[VehicleType], v: Vehicles): PlayerBehavior =
  var actionChains = newSeq[ActionChain]()
  var stages: array[10, tuple[expected: int, done: int]]
  var stagecounter = 0
  let squad = areaFromUnits(v.resolve(spawnArea * VehicleType.IFV))
  let squadWidth = squad.right - squad.left
  let colstarts = [hi, (hi + lo - squadWidth)/2, lo - squadWidth]
  proc stagedone(stage: int): bool =
    if stage != stagecounter: false
    else:
      let st = stages[stage]
      if st.expected == st.done:
        stagecounter += 1
        true
      else: false
  proc done(stage: int): Action =
    stages[stage].expected += 1
    proc inn(ws: WorldState, gc: var GroupCounter, m: var Move): PBResult =
      stages[stage].done += 1
      PBResult(kind: PBRType.priority)
    return inn
  result.tick = proc(ws: WorldState, gc: var GroupCounter, m: var Move): PBResult=
    let v = ws.vehicles
    if ws.world.tickIndex == 0:
      # Placing squads one per column
      let actions = oneByLine(ws, types, colstarts)
      for a in actions:
        actionChains.add(a & done(0))
    elif stagedone(0):
      # Spreading each squad vertically
      debug("Stage 0 done!")
      let actions = spread(v, types)
      for a in actions:
        actionChains.add(a & done(1))
    elif stagedone(1):
      # Moving each squad to central column
      debug("Stage 1 done!")
      let actions = merge(v, types, colstarts)
      for a in actions:
        actionChains.add(a & done(2))
    elif stagedone(2):
      # Dividing resulting squad by 2 and making formation for each part
      let actions = makeFormations(ws, types, gc)
      for a in actions:
        actionChains.add(a & done(3))
      debug("Stage 2 done!")
    elif actionChains.len() == 0 and stagedone(3):
      debug("Stages done!")
      return PBResult(kind: PBRType.removeMe)
    debug($types.len() & ": ActionChains: " & $actionChains.len)
    for i in actionChains:
      debug("  Chainlen:" & $i.len())
    if actionChains.len() > 0:
      return PBResult(kind: PBRType.addPBehavior,
                      behavior: initActionChain(actionChains.pop()))
