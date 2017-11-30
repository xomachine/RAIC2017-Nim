from model.action_type import ActionType
from model.game import Game
from model.world import World
from model.move import Move
from deques import Deque
from lists import DoublyLinkedList
from analyze import WorldState
from formation import Formation, tick
from utils import Area, Point
from pbehavior import PlayerBehavior
from selection import Selection
from groupcounter import GroupCounter

const maxTicksWithoutCtxSwitch = 50

type
  Scheduler* = tuple
    ctxSwitchTimer: Natural
    pool: DoublyLinkedList[Formation]
    playerBehaviors: DoublyLinkedList[PlayerBehavior]
    groupCounter: GroupCounter

proc initScheduler*(game: Game): Scheduler
proc tick*(self: var Scheduler, ws: WorldState, m: var Move)

from analyze import Players
from groupcounter import initGroupCounter
from enhanced import Group
from pbehavior import PBRType
from production import initProduction
from pbinitial import initInitial
from formation import empty
from model.facility_type import FacilityType
from model.vehicle_type import VehicleType
from lists import initDoublyLinkedList, nodes, remove, prepend, append
from tables import `[]`
from utils import debug

proc initScheduler(game: Game): Scheduler =
  result.pool = initDoublyLinkedList[Formation]()
  result.playerBehaviors = initDoublyLinkedList[PlayerBehavior]()
  result.playerBehaviors.append(
    initInitial(@[VehicleType.ARRV, VehicleType.IFV, VehicleType.TANK]))
  result.playerBehaviors.append(
    initInitial(@[VehicleType.FIGHTER, VehicleType.HELICOPTER]))
  result.playerBehaviors.append(initProduction())
  result.groupCounter = initGroupCounter(game.maxUnitGroup.Group)

proc tick(self: var Scheduler, ws: WorldState, m: var Move) =
  if ws.players[Players.me].remainingActionCooldownTicks == 0:
    var index = 0
    for pbn in self.playerBehaviors.nodes():
      let status = pbn.value.tick(ws, self.groupCounter, m)
      case status.kind
      of PBRType.removeMe:
        self.playerBehaviors.remove(pbn)
      of PBRType.priority:
        if index != 0:
          self.playerBehaviors.remove(pbn)
          self.playerBehaviors.prepend(pbn)
      of PBRType.addPBehavior:
        self.playerBehaviors.append(status.behavior)
      of PBRType.addFormation:
        self.pool.append(status.formation)
      else: discard
      if m.action != ActionType.NONE:
        return
      inc(index)
    var position = 0
    for acn in self.pool.nodes:
      if acn.value.empty(ws.vehicles):
        self.pool.remove(acn)
        continue
      acn.value.tick(ws, m)
      if m.action != ActionType.NONE:
        if position == 0:
          self.ctxSwitchTimer += 1
          if self.ctxSwitchTimer > maxTicksWithoutCtxSwitch:
            self.ctxSwitchTimer = 0
            self.pool.remove(acn)
            self.pool.append(acn)
        else:
          self.ctxSwitchTimer = 0
          self.pool.remove(acn)
          self.pool.prepend(acn)
        break
      position += 1
