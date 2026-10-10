class_name AdConfig
extends RefCounted
## Ad unit IDs and pacing. Production IDs are the publisher's AdMob units
## (provided by the owner; App IDs/unit IDs are public identifiers, not
## secrets). Debug builds ALWAYS use Google's official test units unless
## card_rush/ads/use_production_in_debug is enabled deliberately. Never click
## real ads while testing.

# AdMob app (Android). Also set in project.godot [admob] for the manifest.
const APP_ID_ANDROID := "ca-app-pub-8602764456287198~3978960722"
const PROD := {
	"banner": "ca-app-pub-8602764456287198/1754278757",
	"interstitial": "ca-app-pub-8602764456287198/6357712051",
	"rewarded": "ca-app-pub-8602764456287198/9441197085",
}
# iOS needs its own AdMob app + units (AdMob console). Until they exist iOS
# uses Google's test units even in release builds — see docs/ADS_AND_IAP.md.
const PROD_IOS := {}

# Google's documented test units (safe to click, never generate revenue).
const TEST_ANDROID := {
	"banner": "ca-app-pub-3940256099942544/9214589741",
	"interstitial": "ca-app-pub-3940256099942544/1033173712",
	"rewarded": "ca-app-pub-3940256099942544/5224354917",
}
const TEST_IOS := {
	"banner": "ca-app-pub-3940256099942544/2435281174",
	"interstitial": "ca-app-pub-3940256099942544/4411468910",
	"rewarded": "ca-app-pub-3940256099942544/1712485313",
}

# Pacing (stricter than AdMob's own minimums): never mid-turn, only after a
# finished match, not after the first matches of a session.
const MIN_MATCHES_BEFORE_FIRST := 2
const MIN_MATCHES_BETWEEN := 2
const MIN_SECONDS_BETWEEN := 150
const REWARDED_DAILY_CAP := 10
const REWARDED_COINS := 30
const RETRY_BASE_SECONDS := 20.0
const RETRY_MAX_SECONDS := 300.0


static func use_test_ads() -> bool:
	if OS.get_name() == "iOS" and PROD_IOS.is_empty():
		return true
	if OS.is_debug_build():
		return not bool(ProjectSettings.get_setting("card_rush/ads/use_production_in_debug", false))
	return bool(ProjectSettings.get_setting("card_rush/ads/force_test_ads", false))


static func unit(kind: String) -> String:
	var ios := OS.get_name() == "iOS"
	if use_test_ads():
		return (TEST_IOS if ios else TEST_ANDROID).get(kind, "")
	return (PROD_IOS if ios else PROD).get(kind, "")
