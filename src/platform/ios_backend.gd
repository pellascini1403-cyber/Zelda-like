class_name IOSBackend
extends PlatformBackend
## iOS backend. Uses Godot iOS plugins when present in the export:
##  * "InAppStore" (official godot-ios-plugins, StoreKit)
##  * a thermal-state plugin exposing ProcessInfo.thermalState
## Missing plugins degrade to the stub behaviour.

var _store: Object
var _thermal: Object


func init() -> void:
	super.init()
	if Engine.has_singleton("InAppStore"):
		_store = Engine.get_singleton("InAppStore")
	if Engine.has_singleton("VelaThermal"):
		_thermal = Engine.get_singleton("VelaThermal")


func thermal_state() -> int:
	if _thermal and _thermal.has_method("get_thermal_state"):
		return int(_thermal.get_thermal_state())
	return -1


func purchase(product_id: String) -> void:
	if _store == null:
		super.purchase(product_id)
		return
	_store.purchase({"product_id": store_id(product_id, "ios")})


func store_available() -> bool:
	return _store != null or super.store_available()


func restore() -> void:
	if _store and _store.has_method("restore_purchases"):
		_store.restore_purchases()   # results arrive through the plugin event queue
	super.restore()
