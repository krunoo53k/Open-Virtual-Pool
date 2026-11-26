class_name OnlineSettings
extends RefCounted

## The two lobby fields persisted in the same ConfigFile the options panel
## uses. We always load before set_value + save so the existing `[display]` and
## `[input]` sections (and any future ones) survive untouched.

const CONFIG_PATH := "user://open_virtual_pool.cfg"
const SECTION := "online"
const DEFAULT_SERVER_URL := "ws://127.0.0.1:8765"
const DEFAULT_PLAYER_NAME := "Player"


static func load_settings() -> Dictionary:
	var config := ConfigFile.new()
	var url := DEFAULT_SERVER_URL
	var name := DEFAULT_PLAYER_NAME
	if config.load(CONFIG_PATH) == OK:
		url = str(config.get_value(SECTION, "server_url", DEFAULT_SERVER_URL))
		name = str(config.get_value(SECTION, "player_name", DEFAULT_PLAYER_NAME))
	if url.is_empty():
		url = DEFAULT_SERVER_URL
	if name.is_empty():
		name = DEFAULT_PLAYER_NAME
	return {"server_url": url, "player_name": name}


static func save_settings(server_url: String, player_name: String) -> void:
	var config := ConfigFile.new()
	config.load(CONFIG_PATH)  # keep display/input sections written by OptionsPanel.
	config.set_value(SECTION, "server_url", server_url)
	config.set_value(SECTION, "player_name", player_name)
	var err := config.save(CONFIG_PATH)
	if err != OK:
		push_warning("Could not save online settings: %s (%d)" % [CONFIG_PATH, err])
