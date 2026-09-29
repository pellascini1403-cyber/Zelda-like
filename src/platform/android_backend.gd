class_name AndroidBackend
extends PlatformBackend
## Android backend. Uses Godot Android plugins when present in the export:
##  * "GodotGooglePlayBilling" (official billing plugin)
##  * a thermal plugin exposing PowerManager.getCurrentThermalStatus()
## Missing plugins degrade to the stub behaviour.

var _billing: Object
var _thermal: Object


func init() -> void:
	if Engine.has_singleton("GodotGooglePlayBilling"):
		_billing = Engine.get_singleton("GodotGooglePlayBilling")
	if Engine.has_singleton("VelaThermal"):
		_thermal = Engine.get_singleton("VelaThermal")


func thermal_state() -> int:
	if _thermal and _thermal.has_method("get_thermal_state"):
		# Android THERMAL_STATUS_* 0..6 -> 0..3
		return clampi(int(_thermal.get_thermal_state()) / 2, 0, 3)
	return -1


func purchase(product_id: String) -> void:
	if _billing == null:
		super.purchase(product_id)
		return
	_billing.purchase(product_id)
