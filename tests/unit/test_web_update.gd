extends GutTest
## WebUpdate: the bar shown when a new web version is waiting.


func test_offer_shows_bar_once_and_later_hides_it() -> void:
	watch_signals(WebUpdate)
	assert_false(WebUpdate.is_bar_shown())
	WebUpdate.offer_update()
	assert_true(WebUpdate.is_ready)
	assert_true(WebUpdate.is_bar_shown())
	WebUpdate.offer_update()
	assert_signal_emit_count(WebUpdate, "update_ready", 1)
	WebUpdate._on_later()
	assert_false(WebUpdate.is_bar_shown())
