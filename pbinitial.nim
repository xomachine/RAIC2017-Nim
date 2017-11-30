from pbehavior import PlayerBehavior
from model.vehicle_type import VehicleType

proc initInitial*(types: seq[VehicleType]): PlayerBehavior

from tables import `[]`
from model.move import Move
from actions import Action, newSelection, actmove, group, ungroup, ActionStatus
from actionchain import initActionChain, ActionChain
from analyze import WorldState, flyers
from condactions import atMoveEnd
from formation import newGroundFormation, newAerialFormation
from enhanced import VehicleId
from groupcounter import GroupCounter, getFreeGroup
from pbehavior import PBResult, PBRType
from selection import initSelection
from vehicles import resolve, toType, toArea, inArea, `*`
from utils import Area, Point, areaFromUnits, debug

const hi = 18.0
const lo = 220.0
const spawnArea: Area = (left: hi, right: lo, top: hi, bottom: lo)
const areaCenter: Point = (x: (spawnArea.left + spawnArea.right)/2,
                       y: (spawnArea.top + spawnArea.bottom)/2)
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

proc initInitial(types: seq[VehicleType]): PlayerBehavior =
  var actionChains = newSeq[ActionChain]()
  var stages: array[10, tuple[expected: int, done: int]]
  var stagecounter = 0
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
    proc inn(ws: WorldState, gc: var GroupCounter, m: var Move): ActionStatus =
      stages[stage].done += 1
      ActionStatus.next
    return inn
  var freeCols = {0'u8, 1'u8, 2'u8}
  var squadWidth = -1.0
  var colstarts = [0.0, 0.0, 0.0]
  result.tick = proc(ws: WorldState, gc: var GroupCounter, m: var Move): PBResult=
    let v = ws.vehicles
    if unlikely(squadWidth == -1.0):
      let squad = areaFromUnits(v.resolve(spawnArea * VehicleType.IFV))
      squadWidth = squad.right - squad.left
      colstarts = [hi, (hi + lo - squadWidth)/2, lo - squadWidth]
    if ws.world.tickIndex == 0:
      let nonmovables = v.byType[VehicleType.TANK] +
                        v.byType[VehicleType.HELICOPTER]
      var additionals = [0, 0, 0]
      for c in 0'u8..2'u8:
        let sumincol = v.inArea(acols[c])
        var intypes: set[VehicleId]
        for t in types:
          intypes = intypes + v.byType[t]
        var incol = sumincol * intypes
        var iclen = additionals[c] + (card(incol) div 100)
        debug("Iclen for col " & $c & " = " & $iclen)
        if iclen > 0:
          freeCols.excl(c)
        while iclen > 1:
          let targetcol = freeCols.pop()
          let shift = (x: colstarts[targetcol] - colstarts[c], y: 0.0)
          inc(additionals[targetcol])
          let prshifttarget = incol - nonmovables
          let prstlen = card(prshifttarget)
          let shifttarget =
            if prstlen > 100: prshifttarget - v.byType[VehicleType.IFV]
            elif prstlen == 0: incol
            else: prshifttarget
          let starea = areaFromUnits(v.resolve(shifttarget))
          debug("Moving " & $starea & " to " & $targetcol & " via shift = " & $shift)
          actionChains.add(@[
            newSelection(starea),
            actmove(shift),
            atMoveEnd(shifttarget),
            done(0)
          ])
          dec(iclen)
    elif stagedone(0):
      debug("Stage 0 done!")
      for t in types:
        debug("Processing " & $t)
        let vehs = v.byType[t] * v.mine
        let varea = areaFromUnits(v.resolve(vehs))
        let factor = if t.ord in flyers: 2'f64 else: 3'f64
        proc every(i: int, pa: Area): ActionChain =
          let step = pa.bottom - pa.top
          let typeshift =
            if t.ord in {0, 1}: step
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
        actionChains.add(devide(varea, 10, every) &
                         @[
                           atMoveEnd(vehs),
                           done(1)
                         ])
    elif stagedone(1):
      debug("Stage 1 done!")
      for t in types:
        let vehs = v.byType[t] * v.mine
        let varea = areaFromUnits(v.resolve(vehs))
        let shift = (x: colstarts[1] - varea.left, y: 0.0)
        actionChains.add(@[
          newSelection(varea, t),
          actmove(shift),
          atMoveEnd(vehs),
          done(2)
        ])
    elif stagedone(2):
      debug("Stage 2 done!")
      let aarea = areaFromUnits(v.resolve(v.mine))
      let ngroup = gc.getFreeGroup()
      let selection = initSelection(ngroup, @[
        newSelection(aarea)
      ])
      let theformation =
        if types[0].ord in flyers: newAerialFormation(selection)
        else: newGroundFormation(selection)
      return PBResult(kind: PBRType.addFormation, formation: theformation)
    elif stagedone(3):
      debug("Stage 3 done!")
      return PBResult(kind: PBRType.removeMe)
    if actionChains.len() > 0:
      return PBResult(kind: PBRType.addPBehavior,
                      behavior: initActionChain(actionChains.pop()))
