import macros
from model.game import Game

const typenames = [
  "arrv",
  "fighter",
  "helicopter",
  "ifv",
  "tank"
]
const flyers*  = {1, 2}

type GParams* = tuple
  effectiveness: array[5, array[5, float]]
  visionByType: array[5, float]
  speedByType: array[5, float]
  visionFactorsByEnv: array[2, array[3, float]]
  stealthFactorsByEnv: array[2, array[3, float]]
  speedFactorsByEnv: array[2, array[3, float]]

proc getParams*(g: Game): GParams
proc genGameField(game: NimNode, field: string, i, j: int): NimNode
  {.compileTime.}

from model.vehicle_type import VehicleType
from utils import debug

macro envFactor(g: Game, r: untyped, name: static[string]): untyped =
  const envTypeName = ["Terrain", "Weather"]
  const envNames = [
    ["plain", "swamp", "forest"],
    ["clear", "cloud", "rain"]
  ]
  var outer = newSeq[NimNode]()
  for i in 0..1:
    var inner = newSeq[NimNode]()
    for v in 0..2:
      let fieldname = !(envNames[i][v] & envTypeName[i] & name & "Factor")
      inner.add((quote do: `g`.`fieldname`))
    outer.add(newTree(nnkBracket, inner))
  let table = newTree(nnkBracket, outer)
  quote do:
    `r` = `table`

macro constructByType(g: Game, r: untyped, name: static[string]): untyped =
  var variants = newSeq[NimNode]()
  for v in VehicleType.ARRV..VehicleType.TANK:
    let fieldname = !(typenames[v.ord] & name)
    variants.add((quote do: `g`.`fieldname`))
  let thetable = newTree(nnkBracket, variants)
  quote do:
    `r` = `thetable`

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

proc getParams*(g: Game): GParams =
  genEffectiveness(g, result.effectiveness)
  constructByType(g, result.visionByType, "VisionRange")
  constructByType(g, result.speedByType, "Speed")
  envFactor(g, result.visionFactorsByEnv, "Vision")
  envFactor(g, result.stealthFactorsByEnv, "Stealth")
  envFactor(g, result.speedFactorsByEnv, "Speed")
  debug($result)
