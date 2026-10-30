#================================================================================================
# Pokémon Fused Fates Utilities/Events - 007_Cutscene.rb
#================================================================================================

#==================================================================
# module EventUtils (cutscenes)
#==================================================================
module EventUtils
  @cutscene_depth = 0
  @player_locked  = false

  module_function

  # @brief Runs a block as a cutscene, then puts back what the cutscene changed.
  #
  #   cutscene do
  #     pbBGMPlay("Rival theme")
  #     EventUtils.walk_to_event("Rival")
  #     pbMessage(_INTL("Hey!"))
  #   end
  #
  # Saved before the block and restored after it (even if it raises):
  #   - the playing BGM (restored only if the block changed it),
  #   - whether the follower Pokémon (Following Pokemon EX) is out,
  #   - the player's move speed, walk animation, opacity, transparency and through.
  # Nested cutscenes only restore when the outermost one ends.
  # @param hide_follower [Boolean] Put the follower Pokémon away while the block runs.
  # @param lock_player [Boolean] Ignore the player's movement input while the block runs.
  # @param restore_bgm [Boolean] Put the BGM back afterwards.
  # @return [Object] The block's result.
  def cutscene(hide_follower: true, lock_player: true, restore_bgm: true)
    return yield if in_cutscene?   # Only the outermost cutscene saves and restores
    state = save_cutscene_state
    @cutscene_depth = 1
    @player_locked = lock_player
    follower_off if hide_follower && state[:follower]
    return yield
  ensure
    if state
      @cutscene_depth = 0
      @player_locked = false
      restore_cutscene_state(state, restore_bgm)
    end
  end

  # @brief Checks whether a cutscene block is running.
  # @return [Boolean]
  def in_cutscene?
    return @cutscene_depth > 0
  end

  # @brief Checks whether the running cutscene ignores the player's movement input.
  # @return [Boolean]
  def player_locked?
    return @player_locked && in_cutscene?
  end

  # @brief Records what a cutscene might change.
  # @return [Hash]
  def save_cutscene_state
    player = $game_player
    return {
      bgm:         $game_system.getPlayingBGM,
      follower:    follower_active?,
      move_speed:  player.move_speed,
      walk_anime:  player.walk_anime,
      opacity:     player.opacity,
      transparent: player.transparent,
      through:     player.through
    }
  end

  # @brief Puts back what save_cutscene_state recorded.
  # @param state [Hash]
  # @param restore_bgm [Boolean]
  def restore_cutscene_state(state, restore_bgm)
    DevLog.guard("EventUtils.cutscene: could not restore the player") do
      player = $game_player
      player.move_speed  = state[:move_speed]
      player.walk_anime  = state[:walk_anime]
      player.opacity     = state[:opacity]
      player.transparent = state[:transparent]
      player.through     = state[:through]
    end
    DevLog.guard("EventUtils.cutscene: could not restore the BGM") do
      restore_cutscene_bgm(state[:bgm]) if restore_bgm
    end
    DevLog.guard("EventUtils.cutscene: could not restore the follower") do
      follower_on if state[:follower] && !follower_active?
    end
  end

  # @brief Plays a BGM again if something else is now playing.
  # @param bgm [RPG::AudioFile, nil] nil means nothing was playing.
  def restore_cutscene_bgm(bgm)
    now = $game_system.playing_bgm
    same = (bgm.nil? && now.nil?) ||
           (bgm && now && bgm.name == now.name && bgm.volume == now.volume && bgm.pitch == now.pitch)
    return if same
    bgm ? pbBGMPlay(bgm) : pbBGMStop
  end

  #----------------------------------------------------------------
  # Following Pokemon EX (optional)
  #----------------------------------------------------------------
  # @brief Checks whether the follower Pokémon is out. Always false without Following Pokemon EX.
  # @return [Boolean]
  def follower_active?
    return false if !defined?(FollowingPkmn) || !FollowingPkmn.respond_to?(:active?)
    return DevLog.guard("FollowingPkmn.active?", false) { FollowingPkmn.active? } ? true : false
  end

  # @brief Puts the follower Pokémon away without its animation.
  def follower_off
    return if !defined?(FollowingPkmn) || !FollowingPkmn.respond_to?(:toggle_off)
    DevLog.guard("FollowingPkmn.toggle_off") { FollowingPkmn.toggle_off(false) }
  end

  # @brief Brings the follower Pokémon back out without its animation.
  def follower_on
    return if !defined?(FollowingPkmn) || !FollowingPkmn.respond_to?(:toggle_on)
    DevLog.guard("FollowingPkmn.toggle_on") { FollowingPkmn.toggle_on(false) }
  end
end

#==================================================================
# Kernel-level shortcut
#==================================================================
# @brief Shortcut for EventUtils.cutscene, so an event's Script command can use cutscene { ... }.
# @see EventUtils.cutscene
def cutscene(**options, &block)
  return EventUtils.cutscene(**options, &block)
end

#==================================================================
# class Game_Player
#==================================================================
class Game_Player < Game_Character
  alias __event_utils__update_command_new update_command_new unless method_defined?(:__event_utils__update_command_new)

  # @brief Ignores movement input while a cutscene locks the player.
  def update_command_new
    return if EventUtils.player_locked?
    __event_utils__update_command_new
  end
end
