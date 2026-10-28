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

  module_function

  # @brief Finds which overworld context a stock charset belongs to.
  # @param charset [String] Charset name from the player's metadata.
  # @param trainer [Player]
  # @return [Symbol, nil]
  def charset_context(charset, trainer)
    meta = GameData::PlayerMetadata.get(trainer.character_ID)
    return nil if !meta
    pair = CHARSET_CONTEXTS.find { |_context, method| meta.send(method) == charset }
    return pair ? pair[0] : nil
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

  # @brief The composited trainer sprite to use instead of a stock one.
  # @param context [Symbol] :front or :back.
  # @param tr_type [Symbol] Trainer type being drawn.
  # @return [String, nil] A file path, or nil to use the stock sprite.
  def trainer_sprite_for(context, tr_type)
    return nil if !$player || GameData::TrainerType.try_get(tr_type)&.id != $player.trainer_type
    return DevLog.guard("Could not pick the player's custom #{context} sprite") do
      name = PlayerCompositor.virtual_name(context, $player.appearance)
      next name ? "Graphics/Trainers/" + name : nil
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

#==================================================================
# module GameData class TrainerType
#==================================================================
module GameData
  class TrainerType
    class << self
      alias_method :__custom_player_front_sprite_filename, :player_front_sprite_filename unless method_defined?(:__custom_player_front_sprite_filename)
      alias_method :__custom_player_back_sprite_filename, :player_back_sprite_filename unless method_defined?(:__custom_player_back_sprite_filename)

      # Used by the trainer card, Hall of Fame and other screens showing the player
      def player_front_sprite_filename(tr_type)
        return CharacterCustomization.trainer_sprite_for(:front, tr_type) || __custom_player_front_sprite_filename(tr_type)
      end

      # Used by the player's sprite at the start of battle
      def player_back_sprite_filename(tr_type)
        return CharacterCustomization.trainer_sprite_for(:back, tr_type) || __custom_player_back_sprite_filename(tr_type)
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
