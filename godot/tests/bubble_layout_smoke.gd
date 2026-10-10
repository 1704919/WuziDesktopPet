extends SceneTree

const WINDOW_WIDTH := 760.0
const WINDOW_HEIGHT := 420.0
const EXPECTED_CARD_BOTTOM_RIGHT := Vector2(468.0, 158.0)

func _init() -> void:
	call_deferred("_run")


func _assert_case(
	bubble: Control,
	text: String,
	label: String,
	expect_multiple_pages: bool = false
) -> Array[String]:
	var failures: Array[String] = []
	bubble.say(text, 0.0)
	await process_frame
	await process_frame

	var page_count := int(bubble.call("get_page_count"))
	var card: Control = bubble.get_node("Card")
	var message: Label = bubble.get_node("Card/Margin/Content/Message")
	var lines := message.text.split("\n", true)

	if not bubble.visible:
		failures.append(label + ":not_visible")
	if bubble.position.x + bubble.size.x > WINDOW_WIDTH - 8.0:
		failures.append(label + ":right_overflow")
	if bubble.position.x < 8.0:
		failures.append(label + ":left_shadow_risk")
	if bubble.position.y < 7.5:
		failures.append(label + ":top_shadow_risk")
	if bubble.position.y + bubble.size.y > WINDOW_HEIGHT - 8.0:
		failures.append(label + ":bottom_overflow")
	var target := bubble.get("target_position") as Vector2
	var anchored_card_corner := target + card.size
	if absf(anchored_card_corner.x - EXPECTED_CARD_BOTTOM_RIGHT.x) > 1.0:
		failures.append(label + ":bubble_card_anchor_x")
	# Tall pages may hit the top window margin, but no tail or second shape may
	# extend the Control beyond the card itself.
	if anchored_card_corner.y < EXPECTED_CARD_BOTTOM_RIGHT.y - 1.0 or anchored_card_corner.y > EXPECTED_CARD_BOTTOM_RIGHT.y + 3.0:
		failures.append(label + ":bubble_card_anchor_y")
	if bubble.size.distance_to(card.size) > 0.1:
		failures.append(label + ":bubble_has_extra_shape")
	if lines.size() > 4:
		failures.append(label + ":too_many_lines")
	if message.size.y + 0.5 < message.custom_minimum_size.y:
		failures.append(label + ":message_height_clipped")
	if expect_multiple_pages and page_count < 2:
		failures.append(label + ":pagination_missing")
	if not expect_multiple_pages and page_count != 1:
		failures.append(label + ":unexpected_pagination")

	print(label, " pages=", page_count, " pos=", bubble.position, " size=", bubble.size, " card=", card.size)
	return failures


func _run() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var bubble: Control = scene.get_node("Bubble")
	var failures: Array[String] = []

	failures.append_array(await _assert_case(bubble, "你好呀。", "short"))
	bubble.dismiss(false)
	failures.append_array(await _assert_case(
		bubble,
		"今天海口市有雷暴，气温 26～34°C。\n现在 34°C，体感 40°C。\n今天最高降雨概率 86%，未来 6 小时 86%。",
		"weather"
	))
	bubble.dismiss(false)
	failures.append_array(await _assert_case(
		bubble,
		"今天的 weather status 已更新，temperature 约 31°C，feels like 35°C；如果下午出门，建议留意 precipitation probability 和 wind speed 的变化。",
		"mixed"
	))
	bubble.dismiss(false)

	var long_text := ""
	for i in range(18):
		long_text += "这是一段用于验证超长回复不会被裁切的连续中文文本，第%d段会自动换行并在超过四行时进入下一页气泡。" % (i + 1)

	failures.append_array(await _assert_case(bubble, long_text, "long", true))

	if failures.is_empty():
		print("BUBBLE_LAYOUT_SMOKE_OK")
		quit(0)
	else:
		push_error("BUBBLE_LAYOUT_SMOKE_FAILED: %s" % ", ".join(failures))
		quit(2)
