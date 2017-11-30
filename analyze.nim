from model.player import Player
from model.facility import Facility
from model.facility_type import FacilityType
from model.world import World
from model.game import Game
from enhanced import Group, FacilityId
from facilities import Facilities
from vehicles import Vehicles
from tables import Table

const flyers* = {1,2}
const typenames = [
  "arrv",
  "fighter",
  "helicopter",
  "ifv",
  "tank"
]

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
    effectiveness: array[5, array[5, float]]

proc initWorldState*(w: World, g: Game, p: Player): WorldState
proc update*(self: var WorldState, w: World)
proc genGameField(game: NimNode, field: string, i, j: int): NimNode
  {.compileTime.}

from vehicles import update, initVehicles
from facilities import update, initFacilities
from tables import `[]`, `[]=`, initTable, del, keys, contains, mgetOrPut
from math import nextPowerOfTwo
from macros import newStmtList, add, quote, `!`, newIntLitNode

proc genGameField(game: NimNode, field: string, i, j: int): NimNode =
  let kindname = 
    if field == "Durability": ""
    elif j in flyers: "Aerial"
    else: "Ground"
  let fieldname = !(typenames[i] & kindname & field)
  quote do:
    `game`.`fieldname`

macro genEffectiveness(g: Game, r: array[5, array[5, float]]): untyped =
  result = newStmtList()
  for i in 1..<typenames.len():
    for j in 0..<typenames.len():
      let il = newIntLitNode(i)
      let jl = newIntLitNode(j)
      let durfield = g.genGameField("Durability", j, j)
      let damfield = g.genGameField("Damage", i, j)
      let deffield = g.genGameField("Defence", j, j)
      let assignment = quote do:
        `r`[`il`][`jl`] = max(`damfield` - `deffield`, 0) / `durfield`
      result.add(assignment)

proc initWorldState(w: World, g: Game, p: Player): WorldState =
  result.players[Players.me] = p
  result.players[Players.enemy] = w.players[int(w.players[0].me)]
  result.game = g
  result.world = w
  result.vehicles = initVehicles(w, g, p)
  result.facilities = initFacilities(w, p)
  genEffectiveness(g, result.effectiveness)

proc update(self: var WorldState, w: World) =
  let me = self.players[Players.me].id
  self.vehicles.update(w, me)
  self.facilities.update(w, me)
  self.world = w
