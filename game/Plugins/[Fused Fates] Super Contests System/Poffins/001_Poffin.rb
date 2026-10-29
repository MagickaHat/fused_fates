#================================================================================================
# Pokémon Fused Fates Super Contests System/Poffin - 001_Poffin.rb
#================================================================================================

#==================================================================
# class Poffin
#==================================================================
# @brief A cooked poffin. Poffins aren't items: they are kept in the Poffin
# Case, and each one keeps its own flavors and smoothness, so editing
# PBS/berry_flavors.txt never changes poffins the player already has.
# Only the name, description and icon are looked up from PBS/poffins.txt.
class Poffin
  # @brief Flavor values keyed by flavor ID (:SPICY, :DRY...).
  attr_reader :flavors
  # @brief How much sheen the poffin adds when eaten.
  attr_reader :smoothness
  # @brief ID of the GameData::PoffinType this poffin is.
  attr_reader :type_id

  # @brief Creates a poffin.
  # @param flavors [Hash{Symbol => Integer}] Missing flavors count as 0.
  # @param smoothness [Integer]
  # @param type_id [Symbol, nil] Worked out from the flavors when nil.
  def initialize(flavors, smoothness, type_id = nil)
    @flavors = {}
    GameData::Flavor.each { |f| @flavors[f.id] = (flavors[f.id] || 0).to_i.clamp(0, ContestSettings::MAX_POFFIN_FLAVOR) }
    @smoothness = smoothness.to_i
    @type_id    = type_id || GameData::PoffinType.resolve(level, main_flavors)&.id
  end

  # @brief One flavor's value.
  # @param flavor [Symbol]
  # @return [Integer]
  def flavor(flavor)
    return @flavors[flavor] || 0
  end

  # @brief The poffin's level: its strongest flavor's value.
  # @return [Integer]
  def level
    return @flavors.values.max || 0
  end

  # @brief Flavors above 0, strongest first. Ties keep flavor order
  # (Spicy, Dry, Sweet, Bitter, Sour), as in DPPt.
  # @return [Array<Symbol>]
  def main_flavors
    order = GameData::Flavor.keys
    ret = @flavors.keys.select { |f| @flavors[f] > 0 }
    return ret.sort_by { |f| [-@flavors[f], order.index(f)] }
  end

  # @brief The poffin's type data.
  # @return [GameData::PoffinType, nil] nil if its type was removed from
  #   poffins.txt and there is no Foul type to fall back on.
  def type
    return GameData::PoffinType.try_get(@type_id) || GameData::PoffinType.foul_type
  end

  # @brief The poffin's name as shown to the player.
  # @return [String]
  def name
    return type ? type.name : _INTL("Poffin")
  end

  # @brief The poffin's description as shown to the player.
  # @return [String]
  def description
    return type ? type.description : ""
  end

  # @brief Whether this is a failed (Foul) poffin.
  # @return [Boolean]
  def foul?
    return type.nil? || type.foul?
  end

  # @brief One line summing up the poffin, for lists.
  # @return [String]
  def summary
    return _INTL("{1}  Lv. {2}  Smooth. {3}", name, level, @smoothness)
  end

  # @brief Lines listing each flavor above 0.
  # @return [Array<String>]
  def flavor_lines
    ret = []
    GameData::Flavor.each do |f|
      next if @flavors[f.id] <= 0
      ret.push(_INTL("{1}: {2}", f.name, @flavors[f.id]))
    end
    return ret
  end
end
