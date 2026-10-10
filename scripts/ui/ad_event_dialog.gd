class_name AdEventDialog
extends RefCounted
## Opt-in prompt for a shared rewarded-ad event. Joining is voluntary; the
## reward is granted only by this device's own rewarded-ad callback. Players
## who decline lose nothing.


static func open(event_id: String, coins: int, from_name: String) -> Control:
	var pv := Dialogs.titled_panel(TranslationServer.translate("ADEVENT_TITLE"), 620)
	var v: VBoxContainer = pv[1]
	var body := UiKit.label(Loc.t("ADEVENT_BODY", [from_name, coins]), 19, Palette.TEXT_DIM, 650)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size.x = 560
	v.add_child(body)
	var row := UiKit.hbox(14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row)
	var host := App.modal(pv[0])
	var no := UiKit.button(TranslationServer.translate("ADEVENT_NO"), UiKit.Variant.SECONDARY, Vector2(200, 58))
	no.pressed.connect(func():
		host.close()
		Net.report_ad_result(event_id, "declined"))
	row.add_child(no)
	var yes := UiKit.button(TranslationServer.translate("ADEVENT_YES"), UiKit.Variant.SUCCESS, Vector2(240, 58))
	yes.pressed.connect(func():
		host.close()
		if not Ads.can_offer_rewarded():
			Net.report_ad_result(event_id, "unavailable")
			App.toast(TranslationServer.translate("ADEVENT_UNAVAILABLE"), Palette.TEXT_DIM, 3.5)
			return
		Net.report_ad_result(event_id, "watching")
		Ads.show_rewarded("shared_ad_event", coins, func(granted: bool):
			Net.report_ad_result(event_id, "completed" if granted else "not_completed")
			if granted:
				Audio.play("reward")
				App.toast(Loc.t("STORE_COINS_GRANTED", [coins]), Palette.SUCCESS)))
	row.add_child(yes)
	return host
