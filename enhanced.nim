from model.vehicle import Vehicle
from model.vehicle_type import VehicleType

const gridsize* = 16

type
  Group* = uint8
  VehicleId* = uint16
  FacilityId* = uint16
  EVehicle* = tuple
    id: int64
    sid: VehicleId
    player_id: int64
    groups: set[Group]
    thetype: VehicleType
    durability: int32
    maxDurability: int32
    x: float64
    y: float64
    gridx: int
    gridy: int

proc fromVehicle*(v: Vehicle): EVehicle =
  result.id = v.id
  result.sid = v.id.VehicleId
  result.player_id = v.player_id
  result.thetype = v.thetype
  result.x = v.x
  result.y = v.y
  result.gridx = v.x.int div gridsize
  result.gridy = v.y.int div gridsize
  result.durability = v.durability
  result.maxDurability = v.maxDurability
  for g in v.groups:
    result.groups.incl(g.Group)

