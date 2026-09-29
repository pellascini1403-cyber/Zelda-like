extends Node
## Platform abstraction (iOS / Android / desktop).
##
## Gameplay code only talks to this facade. Store SDKs (StoreKit, Google Play
## Billing, AdMob / AppLovin, Firebase Crashlytics, analytics) are wired in the
## backend classes under src/platform/ once their Godot plugins are added to
## the export. Until then the desktop/stub backend is used everywhere.
##
## Monetization policy (enforced here, not in callers):
##  * never pay-to-win: products are cosmetics, ad removal, expansions.
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
	backend.purchase_completed.connect(func(id: String, ok: bool) -> void: purchase_completed.emit(id, ok))
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
	backend.purchase(product_id)


func owns(product_id: String) -> bool:
	return backend.owns(product_id)


func log_event(event_name: String, params: Dictionary = {}) -> void:
	if Settings.get_value("analytics_consent"):
		backend.log_event(event_name, params)


func report_error(message: String) -> void:
	backend.report_error(message)
