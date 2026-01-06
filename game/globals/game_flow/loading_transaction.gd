class_name LoadingTransaction
extends Object

## Encapsulates a loading process with fade transitions and state management.


static func run(
	scene_tree: SceneTree, action: Callable, preserve_dialogue_state: bool = false
) -> bool:
	# Hide overlays that could sit above the loading screen.
	if is_instance_valid(UIManager) and UIManager.has_method("hide"):
		UIManager.hide(UIManager.ScreenName.PAUSE_MENU)
		UIManager.hide(UIManager.ScreenName.LOAD_GAME_MENU)
		UIManager.hide(UIManager.ScreenName.PLAYER_MENU)
		UIManager.hide(UIManager.ScreenName.HUD)

	# Acquire and fade out.
	var loading: Node = null
	if is_instance_valid(UIManager) and UIManager.has_method("acquire_loading_screen"):
		loading = UIManager.acquire_loading_screen()

	if loading != null and loading.has_method("fade_out"):
		await loading.call("fade_out")

	# Now that we're black, remove menu screens.
	if is_instance_valid(UIManager) and UIManager.has_method("hide_all_menus"):
		UIManager.hide_all_menus()

	if is_instance_valid(DialogueManager) and DialogueManager.has_method("stop_dialogue"):
		DialogueManager.stop_dialogue(preserve_dialogue_state)

	# Lock inputs.
	GameplayUtils.set_player_input_enabled(scene_tree, false)
	GameplayUtils.set_npc_controllers_enabled(scene_tree, false)

	# Execute action.
	var ok := false
	if action != null:
		ok = bool(await action.call())

	# Fade in and release.
	if loading != null and loading.has_method("fade_in"):
		await loading.call("fade_in")

	if is_instance_valid(UIManager) and UIManager.has_method("release_loading_screen"):
		UIManager.release_loading_screen()

	return ok
