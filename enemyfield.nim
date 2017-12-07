from fieldbehavior import FieldBehavior

proc initEnemyField*(): FieldBehavior

from analyze import WorldState, Players
from enhanced import VehicleId
from formation_info import FormationInfo
from fastset import FastSet, `*`, card, empty
from gparams import GParams
from model.vehicle_type import VehicleType
from pf import FieldGrid, applyRepulsiveFormationField, applyAttackField
from tables import `[]`
from utils import debug

proc calculate(ws: WorldState, mine, enemy: FastSet[VehicleId]): float =
  let v = ws.vehicles
  if mine.empty or enemy.empty:
    return card(mine).float - card(enemy).float
  var enemyByType: array[5, float]
  var myByType: array[5, float]
  const bhlen = v.byHealth.len
  for t in VehicleType.ARRV..VehicleType.TANK:
    for i, hs in ws.vehicles.byHealth.pairs():
      let twithhs = v.byType[t] * hs
      let relativeFactor = (i+1)/bhlen
      myByType[t.ord] += card(mine * twithhs).float * relativeFactor
      enemyByType[t.ord] += card(enemy * twithhs).float * relativeFactor
  let myArrvSupport = (1+0.02*myByType[0])
  let enemyArrvSupport = (1+0.02*enemyByType[0])
  debug("MyArrvSupport: " & $myArrvSupport)
  debug("enemyArrvSupport: " & $enemyArrvSupport)
  for t in VehicleType.ARRV..VehicleType.TANK:
    let my = myByType[t.ord]
    if my == 0:
      continue
    for et in VehicleType.ARRV..VehicleType.TANK:
      let en = enemyByType[et.ord]
      if en == 0:
        continue
      let sum = en + my
      let adv = my * ws.gparams.effectiveness[t.ord][et.ord] *
                  myArrvSupport -
                en * ws.gparams.effectiveness[et.ord][t.ord] *
                  enemyArrvSupport
      debug("My " & $myByType[t.ord] & " of " & $t & " vs enemys " &
            $enemyByType[et.ord] & " of " & $et & " has advantage: " &
            $(adv/sum))
      result += adv/sum

proc initEnemyField(): FieldBehavior =
  result.apply = proc (f: var FieldGrid, ws: WorldState, fi: FormationInfo) =
    let v = ws.vehicles
    let mine = v.byGroup[fi.group]
    debug($fi.group & ": Enemy has " & $v.byEnemyCluster.len() & " groups.")
    var effs = newSeq[float](v.byEnemyCluster.len)
    var maxeff = 0.0
    for i, enemy in v.byEnemyCluster.pairs():
      let eff = ws.calculate(mine, enemy.cluster) + float(100 *
        int(ws.players[Players.me].remainingNuclearStrikeCooldownTicks == 0))
      debug($fi.group & ":   " & $enemy.center &
            ": Calculatied effectiveness: " & $eff)
      effs[i] = eff
      if abs(eff) > maxeff:
        maxeff = abs(eff)
    for i, enemy in v.byEnemyCluster.pairs():
      let eff = effs[i]
#      if eff > 0:
      f.applyAttackField(enemy.center, enemy.vertices, eff/maxeff)
#      else:
#        f.applyRepulsiveFormationField(enemy.center, enemy.vertices)
