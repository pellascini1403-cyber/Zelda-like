extends Node
## Platform abstraction (iOS / Android / desktop).
##
## Gameplay code only talks to this facade. Store SDKs (StoreKit, Google Play
## Billing, AdMob / AppLovin, Firebase Crashlytics, analytics) are wired in the
## backend classes under src/platform/ once their Godot plugins are added to
## the export. Until then the desktop/stub backend is used everywhere.
##
## Monetization policy (enforced here, not in callers):
##  * never pay-to-win: products are cosmetics, ad removal, expansions and
##    the three premium vehicles (comfort/style/traversal; all three are
##    also earnable in play; nothing story-, region- or boss-critical).
##  * ads are opt-in rewarded ads only, and never during combat, cutscenes,
##    boss fights or while the player is mid-air / climbing.

signal purchase_completed(product_id: String, success: bool)
signal rewarded_ad_finished(placement: String, rewarded: bool)

var backend: PlatformBackend


func _ready() -> void:
	match OS.get_name():
		"iOS":
			backend = IOSBackend.new()
		"Android":
			backend = AndroidBackend.new()
		_:
			backend = PlatformBackend.new()
	backend.init()
	backend.purchase_completed.connect(_on_purchase)
	backend.purchases_restored.connect(_on_restored)
	# Entitlements belong to the account, not to a save slot: re-apply them
	# to whichever game gets loaded or started.
	EventBus.game_loaded.connect(apply_entitlements)
	EventBus.player_spawned.connect(func(_p: Node) -> void: apply_entitlements())
	backend.rewarded_finished.connect(func(p: String, ok: bool) -> void: rewarded_ad_finished.emit(p, ok))
	EventBus.settings_changed.connect(func() -> void: backend.set_analytics_consent(Settings.get_value("analytics_consent")))
	backend.set_analytics_consent(Settings.get_value("analytics_consent"))


## -1 when the OS gives no thermal info; otherwise 0 nominal .. 3 critical.
func thermal_state() -> int:
	return backend.thermal_state()


func can_show_ad() -> bool:
	if Game.in_combat or Game.in_cutscene:
		return false
	if Game.player and Game.player.has_method("is_in_critical_state") and Game.player.is_in_critical_state():
		return false
	return backend.rewarded_ready()


func show_rewarded_ad(placement: String) -> bool:
	if not can_show_ad():
		return false
	backend.show_rewarded(placement)
	return true


func purchase(product_id: String) -> void:
	if not DB.products.has(StringName(product_id)):
		purchase_completed.emit(product_id, false)
		return
	log_event("purchase_start", {"product": product_id})
	backend.purchase(product_id)


func owns(product_id: String) -> bool:
	return backend.owns(product_id)


func restore_purchases() -> void:
	backend.restore()


func store_available() -> bool:
	return backend.store_available()


func price_label(product_id: String) -> String:
	return backend.price_label(product_id)


func product(product_id: String) -> Dictionary:
	return DB.products.get(StringName(product_id), {})


func _on_purchase(product_id: String, ok: bool) -> void:
	if ok:
		_apply(product_id)
		log_event("purchase_done", {"product": product_id})
	purchase_completed.emit(product_id, ok)


func _on_restored(ids: PackedStringArray) -> void:
	for id in ids:
		_apply(id)


## Gives what every owned product grants (idempotent).
func apply_entitlements() -> void:
	for id in backend.owned_products():
		_apply(id)


func _apply(product_id: String) -> void:
	var g: Dictionary = product(product_id).get("grants", {})
	if g.has("vehicle"):
		PlayerData.own_vehicle(StringName(g["vehicle"]), "store")


func log_event(event_name: String, params: Dictionary = {}) -> void:
	if Settings.get_value("analytics_consent"):
		backend.log_event(event_name, params)


func report_error(message: String) -> void:
	backend.report_error(message)
