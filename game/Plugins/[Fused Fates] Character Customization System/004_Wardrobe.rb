#================================================================================================
# Pokémon Fused Fates Character Customization System - 004_Wardrobe.rb
#================================================================================================

#==================================================================
# class SavedOutfit
#==================================================================
# @brief A named appearance the player saved to wear again later.
class SavedOutfit
  attr_accessor :name
  attr_reader :appearance

  # @brief Creates a saved outfit.
  # @param name [String]
  # @param appearance [PlayerAppearance] Copied, so later changes don't affect the outfit.
  def initialize(name, appearance)
    @name = name
    @appearance = appearance.snapshot
  end

  # @brief Replaces the outfit's appearance.
  # @param appearance [PlayerAppearance] Copied.
  def appearance=(appearance)
    @appearance = appearance.snapshot
  end
end

#==================================================================
# class Player
#==================================================================
class Player
  # @return [Array<SavedOutfit>] Outfits the player has saved, at most CustomizationSettings::MAX_OUTFITS.
  def outfits
    @outfits ||= []
    return @outfits
  end
end

#==================================================================
# module Wardrobe
#==================================================================
# @brief Saving, loading, renaming, deleting and sharing outfits.
module Wardrobe
  module_function

  # @return [Boolean] Whether another outfit can be saved.
  def room?
    return $player.outfits.length < CustomizationSettings::MAX_OUTFITS
  end

  # @brief Saves an appearance as a new outfit.
  # @param name [String]
  # @param appearance [PlayerAppearance]
  # @return [SavedOutfit, nil] nil if the wardrobe is full.
  def save(name, appearance)
    return nil if !room?
    outfit = SavedOutfit.new(name, appearance)
    $player.outfits.push(outfit)
    return outfit
  end

  # @brief Overwrites an existing outfit with an appearance.
  # @param index [Integer]
  # @param appearance [PlayerAppearance]
  def overwrite(index, appearance)
    outfit = $player.outfits[index]
    outfit.appearance = appearance if outfit
  end

  # @brief Applies an outfit to an appearance, skipping parts the player can't select.
  # @param index [Integer]
  # @param appearance [PlayerAppearance] Changed in place.
  # @return [Array<Symbol>, nil] Ids of the skipped parts, or nil if there is no such outfit.
  def load(index, appearance)
    outfit = $player.outfits[index]
    return nil if !outfit
    return apply(outfit.appearance, appearance)
  end

  # @brief Copies an appearance onto another, skipping parts the player can't select.
  # @param source [PlayerAppearance]
  # @param appearance [PlayerAppearance] Changed in place.
  # @return [Array<Symbol>] Ids of the skipped parts.
  def apply(source, appearance)
    copy = source.snapshot.sanitize!
    skipped = copy.strip_locked!($player, appearance)
    appearance.restore(copy)
    return skipped
  end

  # @brief Renames an outfit.
  # @param index [Integer]
  # @param name [String]
  def rename(index, name)
    outfit = $player.outfits[index]
    outfit.name = name if outfit
  end

  # @brief Removes an outfit.
  # @param index [Integer]
  def delete(index)
    $player.outfits.delete_at(index)
  end

  # @brief Names the outfits, for a command list.
  # @return [Array<String>]
  def names
    return $player.outfits.map { |outfit| outfit.name }
  end

  # @brief A name for a new outfit that isn't used yet.
  # @return [String]
  def default_name
    n = $player.outfits.length + 1
    n += 1 while names.include?(_INTL("Outfit {1}", n))
    return _INTL("Outfit {1}", n)
  end

  # @brief Copies text to the system clipboard where the engine supports it.
  # @param text [String]
  # @return [Boolean] Whether the text was copied.
  def copy_to_clipboard(text)
    return false if !Input.respond_to?(:clipboard=)
    return DevLog.guard("Could not copy to the clipboard", false) do
      Input.clipboard = text
      next true
    end
  end

  # @brief Reads text from the system clipboard where the engine supports it.
  # @return [String, nil]
  def read_clipboard
    return nil if !Input.respond_to?(:clipboard)
    return DevLog.guard("Could not read the clipboard") { Input.clipboard.to_s.strip }
  end
end
