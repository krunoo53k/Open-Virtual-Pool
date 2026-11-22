class_name FoulBanner
extends PanelContainer

## Shows one stable foul reason word and nothing else. The rules node owns the
## reason; this view just displays the string its parent hands it.

func show_reason(reason: String) -> void:
	$Row/ReasonLabel.text = reason
	visible = reason != ""


func reason_text() -> String:
	return $Row/ReasonLabel.text if visible else ""
