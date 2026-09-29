class_name PlatformBackend
extends RefCounted
## Default (desktop / editor) backend. Also the interface every platform
## backend implements. All calls are safe no-ops, except in the purchase
## sandbox (debug builds only), which simulates a store so the whole flow
## (buy -> entitlement -> restore) can be tested without a device.
##
## The product catalogue is data: data/products.json (DB.products). Store
## ids per platform live there too ("store_ids": {"android", "ios"}).

signal purchase_completed(product_id: String, success: bool)
signal rewarded_finished(placement: String, rewarded: bool)
signal purchases_restored(product_ids: PackedStringArray)

const ENTITLEMENTS := "user://entitlements.json"

## Debug-only simulated store (Debug console "sandbox_store", tests).
var sandbox := false
var _owned: Dictionary = {}
var _consent := false


func init() -> void:
	_load_owned()


func thermal_state() -> int:
	return -1


func rewarded_ready() -> bool:
	return false


func show_rewarded(placement: String) -> void:
	rewarded_finished.emit(placement, false)


func store_id(product_id: String, platform: String) -> String:
	var p: Dictionary = DB.products.get(StringName(product_id), {})
	return String(p.get("store_ids", {}).get(platform, product_id))


## Localized price from the store, "" while unknown (the UI then shows a
## generic "Store" label instead of inventing a price).
func price_label(_product_id: String) -> String:
	return "—" if sandbox else ""


func store_available() -> bool:
	return sandbox


func purchase(product_id: String) -> void:
	if sandbox and OS.is_debug_build() and DB.products.has(StringName(product_id)):
		_grant(product_id)
		purchase_completed.emit(product_id, true)
		return
	push_warning("Purchases unavailable on this platform: " + product_id)
	purchase_completed.emit(product_id, false)


## Re-delivers every non-consumable the account owns (new device, reinstall,
## other save slot). Platform backends query the store; the stub replays
## its local cache.
func restore() -> void:
	purchases_restored.emit(PackedStringArray(_owned.keys()))


func owns(product_id: String) -> bool:
	return _owned.has(product_id)


func owned_products() -> PackedStringArray:
	return PackedStringArray(_owned.keys())


## Called by platform backends when the store confirms a purchase/restore.
func _grant(product_id: String) -> void:
	_owned[product_id] = true
	_save_owned()


func _load_owned() -> void:
	if not FileAccess.file_exists(ENTITLEMENTS):
		return
	var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(ENTITLEMENTS))
	if v is Dictionary:
		_owned = v


func _save_owned() -> void:
	var f := FileAccess.open(ENTITLEMENTS, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(_owned))


## Test hook: forget the local entitlement cache.
func clear_owned() -> void:
	_owned.clear()
	_save_owned()


func set_analytics_consent(consent: bool) -> void:
	_consent = consent


func log_event(event_name: String, params: Dictionary) -> void:
	if OS.is_debug_build():
		print("[analytics] ", event_name, " ", params)


func report_error(message: String) -> void:
	push_error(message)
