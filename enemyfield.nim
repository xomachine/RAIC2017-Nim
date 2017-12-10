from fieldbehavior import FieldBehavior

proc initEnemyField*(): FieldBehavior

from analyze import WorldState, Players
from enhanced import VehicleId
from formation_info import FormationInfo
from fastset import FastSet, `*`, card, empty, `+=`
from gparams import GParams
from model.vehicle_type import VehicleType
from pf import FieldGrid, applyRepulsiveFormationField, applyAttackField
from tables import `[]`, values
from utils import debug, getSqDistance

proc calculate(ws: WorldState, mine, enemy: FastSet[VehicleId]): float =
  let v = ws.vehicles
  if mine.empty or enemy.empty:
    let my = card(mine)
    let en = card(enemy)
    debug("My: " & $my & ", enemy: " & $en)
    return my.float - en.float
  var enemyByType: array[5, float]
  var myByType: array[5, float]
  const bhlen = v.byHealth.len
  for t in VehicleType.ARRV..VehicleType.TANK:
    for i, hs in ws.vehicles.byHealth.pairs():
      let twithhs = v.byType[t] * hs
      let relativeFactor = 1+(i+1)/bhlen
      myByType[t.ord] += card(mine * twithhs).float * relativeFactor
      enemyByType[t.ord] += card(enemy * twithhs).float * relativeFactor
  #debug("MyArrvSupport: " & $myArrvSupport)
  #debug("enemyArrvSupport: " & $enemyArrvSupport)
  for t in VehicleType.FIGHTER..VehicleType.TANK:
    let my = myByType[t.ord]
    if my == 0:
      continue
    for et in VehicleType.ARRV..VehicleType.TANK:
      let en = enemyByType[et.ord]
      if en == 0:
        continue
      let myArrvSupport = (1+0.5*myByType[0]/my)
      let enemyArrvSupport = (1+0.5*enemyByType[0]/en)
      #let sum = en + my
      let adv = my * ws.gparams.effectiveness[t.ord][et.ord] *
                  myArrvSupport -
                en * ws.gparams.effectiveness[et.ord][t.ord] *
                  enemyArrvSupport
      debug("My " & $myByType[t.ord] & " of " & $t & " vs enemys " &
            $enemyByType[et.ord] & " of " & $et & " has advantage: " &
            $(adv))
      result += adv

proc initEnemyField(): FieldBehavior =
  const allySqRange = 150*150
  result.apply = proc (f: var FieldGrid, ws: WorldState, fi: FormationInfo) =
    let v = ws.vehicles
    let mine: FastSet[VehicleId] = v.byGroup[fi.group]
    #for c in fi.associatedClusters.values:
    #  mine += c.cluster
    debug($fi.group & ": Enemy has " & $v.byEnemyCluster.len() & " groups.")
    var effs = newSeq[float](v.byEnemyCluster.len)
    var maxeff = 0.0
    for i, enemy in v.byEnemyCluster.pairs():
      var mysupport = 0
      for mya in v.byMyAerialCluster:
        let distance = mya.center.getSqDistance(enemy.center)
        if distance < allySqRange:
          mysupport += mya.cluster.card()
      for mya in v.byMyGroundCluster:
        let distance = mya.center.getSqDistance(enemy.center)
        if distance < allySqRange:
          mysupport += mya.cluster.card()
      #var ensupport = 0
      #for ea in v.byEnemyCluster:
      #  let distance = ea.center.getSqDistance(enemy.center)
      #  if distance < allySqRange and distance > 0:
      #    ensupport += mya.cluster.card()
      let eff = ws.calculate(mine, enemy.cluster)+mysupport/20 + float(50 *
        int(ws.players[Players.me].remainingNuclearStrikeCooldownTicks == 0))
      debug($fi.group & ":   " & $enemy.center &
            ": Calculatied effectiveness: " & $eff)
      effs[i] = eff
      if abs(eff) > maxeff:
        maxeff = abs(eff)
    for i, enemy in v.byEnemyCluster.pairs():
      let eff = effs[i]
      if eff > 50:
        f.applyAttackField(enemy.center, enemy.vertices, 0.7)
      elif eff > 10:
        f.applyAttackField(enemy.center, enemy.vertices, 0.5)
      elif eff > 0:
        f.applyAttackField(enemy.center, enemy.vertices, 0.3)
      elif eff < -50:
        #f.applyRepulsiveFormationField(enemy.center, enemy.vertices)
        f.applyAttackField(enemy.center, enemy.vertices, -2.0)
      elif eff < -10:
        #f.applyRepulsiveFormationField(enemy.center, enemy.vertices)
        f.applyAttackField(enemy.center, enemy.vertices, -1.0)
      else:
        #f.applyRepulsiveFormationField(enemy.center, enemy.vertices)
        f.applyAttackField(enemy.center, enemy.vertices, -0.5)
