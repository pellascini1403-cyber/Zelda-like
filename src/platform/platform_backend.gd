class_name PlatformBackend
extends RefCounted
## Default (desktop / editor) backend. Also the interface every platform
## backend implements. All calls are safe no-ops.

signal purchase_completed(product_id: String, success: bool)
signal rewarded_finished(placement: String, rewarded: bool)

## Product catalogue (store ids are mapped per platform in the backends).
const PRODUCTS := {
	"remove_ads": {"type": "non_consumable"},
	"supporter_pack": {"type": "non_consumable", "cosmetic": true},
	"expansion_1": {"type": "non_consumable"},
}

var _owned: Dictionary = {}
var _consent := false


func init() -> void:
	pass


func thermal_state() -> int:
	return -1


func rewarded_ready() -> bool:
	return false


func show_rewarded(placement: String) -> void:
	rewarded_finished.emit(placement, false)


func purchase(product_id: String) -> void:
	push_warning("Purchases unavailable on this platform: " + product_id)
	purchase_completed.emit(product_id, false)


func owns(product_id: String) -> bool:
	return _owned.has(product_id)


func set_analytics_consent(consent: bool) -> void:
	_consent = consent


func log_event(event_name: String, params: Dictionary) -> void:
	if OS.is_debug_build():
		print("[analytics] ", event_name, " ", params)


func report_error(message: String) -> void:
	push_error(message)
