extends AdsBackend
## Real Google Mobile Ads integration through the Poing Studios AdMob plugin
## (addons/admob, MIT, v5.1.0). Only instantiated on Android/iOS when the native
## plugin singleton exists. Never used on desktop.

var _banner: AdView
var _banner_visible := false
var _interstitial: InterstitialAd
var _rewarded: RewardedAd
var _i_loader := InterstitialAdLoader.new()
var _r_loader := RewardedAdLoader.new()
var _i_loading := false
var _r_loading := false


static func available() -> bool:
	return Engine.has_singleton("PoingGodotAdMob")


func kind() -> String:
	return "admob"


func is_real_sdk() -> bool:
	return true


# --- Consent (Google UMP) -----------------------------------------------------------

func request_consent(on_done: Callable) -> void:
	var params := ConsentRequestParameters.new()
	var info := UserMessagingPlatform.consent_information
	var finished := [false]
	var done := func():
		if not finished[0]:
			finished[0] = true
			on_done.call()
	info.update(params, func():
		if info.get_is_consent_form_available() and info.get_consent_status() == ConsentInformation.ConsentStatus.REQUIRED:
			UserMessagingPlatform.load_consent_form(func(form: ConsentForm):
				form.show(func(_err: FormError): done.call()),
				func(_err: FormError): done.call())
		else:
			done.call(),
		func(_err: FormError): done.call())


func privacy_options_required() -> bool:
	var st := UserMessagingPlatform.consent_information.get_privacy_options_requirement_status()
	return st == ConsentInformation.PrivacyOptionsRequirementStatus.REQUIRED


func show_privacy_options(on_done: Callable) -> void:
	UserMessagingPlatform.show_privacy_options_form(func(_e): on_done.call())


func initialize(on_done: Callable) -> void:
	var cfg := RequestConfiguration.new()
	# General-audience card game: request family-safe ad content.
	cfg.max_ad_content_rating = RequestConfiguration.MAX_AD_CONTENT_RATING_PG
	MobileAds.set_request_configuration(cfg)
	var listener := OnInitializationCompleteListener.new()
	listener.on_initialization_complete = func(_status: InitializationStatus): on_done.call()
	MobileAds.initialize(listener)


# --- Banner ---------------------------------------------------------------------------

func banner_load() -> void:
	if _banner != null:
		return
	var size := AdSize.get_current_orientation_anchored_adaptive_banner_ad_size(AdSize.FULL_WIDTH)
	_banner = AdView.new(AdConfig.unit("banner"), size, AdPosition.BOTTOM)
	var l := AdListener.new()
	l.on_ad_loaded = func():
		if _banner and not _banner_visible:
			_banner.hide()
		banner_loaded.emit()
	l.on_ad_failed_to_load = func(err: LoadAdError):
		var msg := err.message if err else "unknown"
		if _banner:
			_banner.destroy()
		_banner = null
		banner_failed.emit(msg)
	_banner.ad_listener = l
	_banner.load_ad(AdRequest.new())


func banner_set_visible(on: bool) -> void:
	_banner_visible = on
	if _banner == null:
		return
	if on:
		_banner.show()
	else:
		_banner.hide()


func banner_destroy() -> void:
	if _banner:
		_banner.destroy()
	_banner = null
	_banner_visible = false


# --- Interstitial --------------------------------------------------------------------------

func interstitial_load() -> void:
	if _interstitial != null or _i_loading:
		return
	_i_loading = true
	var cb := InterstitialAdLoadCallback.new()
	cb.on_ad_loaded = func(ad: InterstitialAd):
		_i_loading = false
		_interstitial = ad
		interstitial_loaded.emit()
	cb.on_ad_failed_to_load = func(err: LoadAdError):
		_i_loading = false
		interstitial_failed.emit(err.message if err else "unknown")
	_i_loader.load(AdConfig.unit("interstitial"), AdRequest.new(), cb)


func interstitial_ready() -> bool:
	return _interstitial != null


func interstitial_show(on_closed: Callable) -> void:
	if _interstitial == null:
		on_closed.call(false)
		return
	var ad := _interstitial
	_interstitial = null
	var once := [false]
	var finish := func(shown: bool):
		if once[0]:
			return
		once[0] = true
		ad.destroy()
		on_closed.call(shown)
	var fs := FullScreenContentCallback.new()
	fs.on_ad_dismissed_full_screen_content = func(): finish.call(true)
	fs.on_ad_failed_to_show_full_screen_content = func(_e: AdError): finish.call(false)
	ad.full_screen_content_callback = fs
	ad.show()


# --- Rewarded --------------------------------------------------------------------------------

func rewarded_load() -> void:
	if _rewarded != null or _r_loading:
		return
	_r_loading = true
	var cb := RewardedAdLoadCallback.new()
	cb.on_ad_loaded = func(ad: RewardedAd):
		_r_loading = false
		_rewarded = ad
		rewarded_loaded.emit()
	cb.on_ad_failed_to_load = func(err: LoadAdError):
		_r_loading = false
		rewarded_failed.emit(err.message if err else "unknown")
	_r_loader.load(AdConfig.unit("rewarded"), AdRequest.new(), cb)


func rewarded_ready() -> bool:
	return _rewarded != null


func rewarded_show(on_earned: Callable, on_closed: Callable) -> void:
	if _rewarded == null:
		on_closed.call(false)
		return
	var ad := _rewarded
	_rewarded = null
	var earned_once := [false]
	var closed_once := [false]
	var finish := func(shown: bool):
		if closed_once[0]:
			return
		closed_once[0] = true
		ad.destroy()
		on_closed.call(shown)
	var fs := FullScreenContentCallback.new()
	fs.on_ad_dismissed_full_screen_content = func(): finish.call(true)
	fs.on_ad_failed_to_show_full_screen_content = func(_e: AdError): finish.call(false)
	ad.full_screen_content_callback = fs
	var rl := OnUserEarnedRewardListener.new()
	rl.on_user_earned_reward = func(_item: RewardedItem):
		if not earned_once[0]:
			earned_once[0] = true
			on_earned.call()
	ad.show(rl)


func destroy_all() -> void:
	banner_destroy()
	if _interstitial:
		_interstitial.destroy()
	_interstitial = null
	if _rewarded:
		_rewarded.destroy()
	_rewarded = null
