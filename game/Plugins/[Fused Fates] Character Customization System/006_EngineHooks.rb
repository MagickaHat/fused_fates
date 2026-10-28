#================================================================================================
# Pokémon Fused Fates Character Customization System - 006_EngineHooks.rb
#================================================================================================

#==================================================================
# module CharacterCustomization
#==================================================================
# @brief Connects the player's appearance to the engine's overworld and trainer sprites.
# Whenever there is no art for a sprite, the stock graphic is used exactly as before.
module CharacterCustomization
  # Overworld contexts, paired with the PlayerMetadata charset each one replaces.
  # Earlier entries win when the metadata uses one charset for several of them.
  CHARSET_CONTEXTS = [
    [:walk,      :walk_charset],
    [:run,       :run_charset],
    [:cycle,     :cycle_charset],
    [:surf,      :surf_charset],
    [:dive,      :dive_charset],
    [:fish,      :fish_charset],
    [:surf_fish, :surf_fish_charset]
  ].freeze

  # Game_Player#set_movement_type types => overworld context (anything else is :walk)
  MOVEMENT_CONTEXTS = {
    fishing:              :fish,
    surf_fishing:         :surf_fish,
    diving:               :dive,
    diving_fast:          :dive,
    diving_jumping:       :dive,
    diving_stopped:       :dive,
    surfing:              :surf,
    surfing_fast:         :surf,
    surfing_jumping:      :surf,
    surfing_stopped:      :surf,
    descending_waterfall: :surf,
    ascending_waterfall:  :surf,
    cycling:              :cycle,
    cycling_fast:         :cycle,
    cycling_jumping:      :cycle,
    cycling_stopped:      :cycle,
    running:              :run
  }.freeze

  module_function

  # @brief Finds which overworld context a stock charset belongs to.
  # The player's movement state decides when the metadata uses one charset for several
  # contexts (e.g. the same graphic for surfing and diving).
  # @param charset [String] Charset name from the player's metadata.
  # @param trainer [Player]
  # @return [Symbol, nil]
  def charset_context(charset, trainer)
    meta = GameData::PlayerMetadata.get(trainer.character_ID)
    return nil if !meta
    current = (trainer.equal?($player) && $game_player) ? $game_player.custom_context : nil
    pair = CHARSET_CONTEXTS.assoc(current) if current
    return current if pair && meta.send(pair[1]) == charset
    pair = CHARSET_CONTEXTS.find { |_context, method| meta.send(method) == charset }
    return pair ? pair[0] : nil
  end

  # @brief The player's walking charset (current look facing down), without disturbing the map.
  # @param trainer [Player]
  # @return [String, nil] A charset name relative to Graphics/Characters/, or nil if there is none.
  def walk_charset_for(trainer = $player)
    return nil if !trainer
    custom = DevLog.guard("Could not pick the player's custom charset") do
      next PlayerCompositor.virtual_name(:walk, trainer.appearance)
    end
    return custom if custom
    meta = GameData::PlayerMetadata.get(trainer.character_ID)
    return nil if !meta
    # Forcing pbGetPlayerCharset overwrites the map's charset cache, so put it back afterwards
    cached = $game_player&.charsetData
    ret = __custom_pbGetPlayerCharset(meta.walk_charset, trainer, true)
    $game_player.charsetData = cached if $game_player
    return ret
  end

  # @brief The player's mugshot: a square cropped from the top of their trainer card sprite.
  # @param trainer [Player]
  # @return [String, nil] A graphic path, or nil if there is no trainer card art for the current look.
  def mugshot_filename(trainer = $player)
    return nil if !trainer
    name = DevLog.guard("Could not make the player's mugshot") do
      next PlayerCompositor.virtual_name(:mugshot, trainer.appearance)
    end
    return name ? "Graphics/Pictures/" + name : nil
  end

  # @brief The composited charset to use instead of a stock one.
  # @param charset [String] Charset name from the player's metadata.
  # @param trainer [Player]
  # @return [String, nil] A charset name relative to Graphics/Characters/, or nil to use the stock one.
  def charset_for(charset, trainer)
    return nil if !charset || !trainer.is_a?(Player)
    return DevLog.guard("Could not pick the player's custom charset") do
      context = charset_context(charset, trainer)
      next context ? PlayerCompositor.virtual_name(context, trainer.appearance) : nil
    end
  end

  # @brief The composited graphic to use instead of one of the player's stock trainer graphics.
  # @param context [Symbol] :front, :back or :map_icon.
  # @param tr_type [Symbol] Trainer type being drawn.
  # @param folder [String] Folder the stock graphic lives in.
  # @return [String, nil] A file path, or nil to use the stock graphic.
  def trainer_sprite_for(context, tr_type, folder = "Graphics/Trainers/")
    return nil if !$player || GameData::TrainerType.try_get(tr_type)&.id != $player.trainer_type
    return DevLog.guard("Could not pick the player's custom #{context} sprite") do
      name = PlayerCompositor.virtual_name(context, $player.appearance)
      next name ? folder + name : nil
    end
  end

  # @brief Makes the player's sprite pick up appearance changes. Call after changing $player.appearance.
  def refresh
    return if !$game_player
    $game_player.charsetData = nil
    $game_player.refresh_charset
  end
end

#==================================================================
# pbGetPlayerCharset
#==================================================================
alias __custom_pbGetPlayerCharset pbGetPlayerCharset unless defined?(__custom_pbGetPlayerCharset)

# @brief Returns the composited charset when there is art for it, otherwise the stock one.
# @param charset [String] Charset name from the player's metadata.
# @param trainer [Player, nil] Defaults to $player.
# @param force [Boolean] Return a name even if it hasn't changed since the last call.
# @return [String, nil] nil if the charset hasn't changed since the last call.
def pbGetPlayerCharset(charset, trainer = nil, force = false)
  ret = __custom_pbGetPlayerCharset(charset, trainer, force)
  return ret if !ret
  return CharacterCustomization.charset_for(charset, trainer || $player) || ret
end

# @brief The player's mugshot (for use in events and UI), cropped from their trainer card sprite.
# @return [String, nil] A graphic path for IconSprite#setBitmap and similar, or nil if there is
#   no trainer card art for the current look.
def pbPlayerMugshotFilename
  return CharacterCustomization.mugshot_filename
end

#==================================================================
# pbResolveBitmap
#==================================================================
alias __custom_pbResolveBitmap pbResolveBitmap unless defined?(__custom_pbResolveBitmap)

# @brief Treats composited player graphics as existing files, so screens that check a path
# before loading it (e.g. the load screen's walking sprite) accept them.
# @param x [String]
# @return [String, nil]
def pbResolveBitmap(x)
  return x if PlayerCompositor.virtual?(x)
  return __custom_pbResolveBitmap(x)
end

#==================================================================
# class Game_Player
#==================================================================
# @brief Tracks which overworld context the player is in, so contexts that share a stock
# charset (e.g. surfing and diving) can still use different art.
class Game_Player < Game_Character
  # @return [Symbol, nil] The overworld context the player was last drawn in.
  attr_reader :custom_context

  alias __custom_set_movement_type set_movement_type unless method_defined?(:__custom_set_movement_type)
  alias __custom_refresh_charset refresh_charset unless method_defined?(:__custom_refresh_charset)

  def set_movement_type(type)
    use_custom_context(CharacterCustomization::MOVEMENT_CONTEXTS[type] || :walk)
    __custom_set_movement_type(type)
  end

  def refresh_charset
    context = if $PokemonGlobal&.diving       then :dive
              elsif $PokemonGlobal&.surfing   then :surf
              elsif $PokemonGlobal&.bicycle   then :cycle
              else                                 :walk
              end
    use_custom_context(context)
    __custom_refresh_charset
  end

  # @brief Remembers the current context, forgetting the cached charset when it changes.
  # @param context [Symbol]
  def use_custom_context(context)
    return if @custom_context == context
    @custom_context = context
    self.charsetData = nil
  end
end

#==================================================================
# module GameData class TrainerType
#==================================================================
module GameData
  class TrainerType
    class << self
      alias_method :__custom_player_front_sprite_filename, :player_front_sprite_filename unless method_defined?(:__custom_player_front_sprite_filename)
      alias_method :__custom_player_back_sprite_filename, :player_back_sprite_filename unless method_defined?(:__custom_player_back_sprite_filename)
      alias_method :__custom_player_map_icon_filename, :player_map_icon_filename unless method_defined?(:__custom_player_map_icon_filename)

      # Used by the trainer card, Hall of Fame and other screens showing the player
      def player_front_sprite_filename(tr_type)
        return CharacterCustomization.trainer_sprite_for(:front, tr_type) || __custom_player_front_sprite_filename(tr_type)
      end

      # Used by the player's sprite at the start of battle
      def player_back_sprite_filename(tr_type)
        return CharacterCustomization.trainer_sprite_for(:back, tr_type) || __custom_player_back_sprite_filename(tr_type)
      end

      # Used by the player's icon on the town map
      def player_map_icon_filename(tr_type)
        return CharacterCustomization.trainer_sprite_for(:map_icon, tr_type, "Graphics/UI/Town Map/") ||
               __custom_player_map_icon_filename(tr_type)
      end
    end
  end
end

#==================================================================
# module RPG::Cache
#==================================================================
module RPG
  module Cache
    class << self
      alias_method :__custom_load_bitmap, :load_bitmap unless method_defined?(:__custom_load_bitmap)

      # Serves composited player graphics for virtual paths; everything else loads normally
      def load_bitmap(folder_name, filename, hue = 0)
        path = "#{folder_name}#{filename}"
        if PlayerCompositor.virtual?(path)
          bmp = PlayerCompositor.load_virtual(path)
          return bmp if bmp
          return __custom_load_bitmap("", "")   # Blank bitmap if the graphic can't be made
        end
        return __custom_load_bitmap(folder_name, filename, hue)
      end
    end
  end
end

#==================================================================
# class PokemonSave_Scene
#==================================================================
# @brief Shows the player's walking sprite (current look, facing down) next to the save details.
class PokemonSave_Scene
  alias __custom_pbStartScreen pbStartScreen unless method_defined?(:__custom_pbStartScreen)

  def pbStartScreen
    __custom_pbStartScreen
    charset = CharacterCustomization.walk_charset_for($player)
    return if !charset
    sprite = TrainerWalkingCharSprite.new(charset, @viewport)
    if !sprite.bitmap
      sprite.dispose
      return
    end
    window = @sprites["locwindow"]
    sprite.x = window.x + window.width + 16
    sprite.y = window.y + ((window.height - sprite.src_rect.height) / 2)
    @sprites["player"] = sprite
  end
end
