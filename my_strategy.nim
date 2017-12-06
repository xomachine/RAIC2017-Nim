when not defined(stdebug):
  {.optimization: speed, checks:off.}
from model.action_type import ActionType
from model.player import Player
from model.world import World
from model.move import Move
from model.game import Game

from analyze import WorldState, initWorldState, update
from scheduler import Scheduler, tick, initScheduler

type MyStrategy* = object
  worldState: WorldState
  scheduler: Scheduler
  # put your custom fields here

proc initMyStrategy*(): MyStrategy =
  # put your initialization code here
  GC_disableMarkAndSweep()
  #GC_disable()
  discard

proc move*(self: var MyStrategy, player: Player, world: World, game: Game,
           move: var Move) =
  if world.tick_index == 0:
    self.worldState = initWorldState(world, game, player)
    self.scheduler = initScheduler(game, self.worldState)
  self.worldState.update(world)
  self.scheduler.tick(self.worldState, move)
#  when defined(stdebug):
#    if move.action != ActionType.NONE:
#      echo "Tick: ", world.tickIndex
#      echo move.action
#      echo move.x, " ", move.y
#      echo move.top, " ",  move.bottom
