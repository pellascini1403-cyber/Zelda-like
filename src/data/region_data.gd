class_name RegionData
extends Resource
## Biome / region definition: identity, climate, what spawns there.

@export var id: StringName
@export var name_key: String
## Base temperature in °C at sea level during the day.
@export var base_temperature: float = 18.0
## weather id -> relative weight
@export var weather_weights: Dictionary = {}
## Array of { "entity": id, "weight": float, "group": [min,max], "period": any|day|night }
@export var enemy_spawns: Array = []
@export var animal_spawns: Array = []
## Array of { "node": resource node id, "density": per 64m chunk }
@export var resources: Array = []
@export var enemy_density: float = 0.5
@export var animal_density: float = 0.5
@export var music: StringName = &"explore"


static func from_dict(d: Dictionary) -> RegionData:
	var r := RegionData.new()
	r.id = StringName(d.get("id", ""))
	r.name_key = d.get("name_key", "")
	r.base_temperature = d.get("base_temperature", 18.0)
	r.weather_weights = d.get("weather_weights", {"clear": 1.0})
	r.enemy_spawns = d.get("enemy_spawns", [])
	r.animal_spawns = d.get("animal_spawns", [])
	r.resources = d.get("resources", [])
	r.enemy_density = d.get("enemy_density", 0.5)
	r.animal_density = d.get("animal_density", 0.5)
	r.music = StringName(d.get("music", "explore"))
	return r
