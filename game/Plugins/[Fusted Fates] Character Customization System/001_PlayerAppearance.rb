#================================================================================================
# Pokémon Fused Fates Fusion System - 001_PlayerAppearance.rb
#================================================================================================

#==================================================================
# class PlayerAppearance
#==================================================================
class PlayerAppearance
  attr_reader :parts, :hues

  # @brief Creates a default appearance.
  def initialize
    @parts = {
      Bottom: :JEANS,
      Shoes: :SNEAKERS,
      Top: :TEE,
      Hair: :HAIR_SHORT
    }

    # part id => [hue per color region]
    @hues = {} 
  end

  # @brief Gets the part definition equipped in a slot.
  # @param slot [Symbol] The slot to look up.
  # @return [GameData::PlayerPart, nil] nil if the slot is empty.
  def part_for(slot)
    id = @parts[slot]
    return id ? GameData::PlayerPart.get(id) : nil
  end
end

#==================================================================
# class Player 
#==================================================================
class Player
  # @brief Creates appearance data.
  def appearance
    @appearance ||= PlayerAppearance.new
    return @appearance
  end
end