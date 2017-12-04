from model.player import Player
from model.facility import Facility
from model.facility_type import FacilityType
from model.world import World
from model.game import Game
from enhanced import Group, FacilityId
from facilities import Facilities
from vehicles import Vehicles
from tables import Table
from gparams import GParams


type
  Players* {.pure.} = enum
    me
    enemy
  WorldState* = tuple
    players: array[Players, Player]
    vehicles: Vehicles
    facilities: Facilities
    game: Game
    world: World
    gparams: GParams

proc initWorldState*(w: World, g: Game, p: Player): WorldState
proc update*(self: var WorldState, w: World)

from vehicles import update, initVehicles
from facilities import update, initFacilities
from tables import `[]`, `[]=`, initTable, del, keys, contains, mgetOrPut
from math import nextPowerOfTwo
from macros import newStmtList, add, quote, `!`, newIntLitNode
from gparams import getParams

proc initWorldState(w: World, g: Game, p: Player): WorldState =
  result.players[Players.me] = p
  result.players[Players.enemy] = w.players[int(w.players[0].me)]
  result.game = g
  result.world = w
  result.vehicles = initVehicles(w, g, p)
  result.facilities = initFacilities(w, p)
  result.gparams = getParams(g)

proc update(self: var WorldState, w: World) =
  let me = self.players[Players.me].id
  self.vehicles.update(w, me)
  self.facilities.update(w, me)
  self.world = w
  self.players[Players.enemy] = w.players[int(w.players[0].me)]
  self.players[Players.me] = w.players[int(w.players[1].me)]
