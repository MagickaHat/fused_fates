#================================================================================================
# Pokémon Fused Fates Super Contests System/Pokemon - 001_Conditions.rb
#================================================================================================
# Essentials already stores the five conditions and sheen on every Pokémon
# (cool, beauty, cute, smart, tough, sheen). This file adds the rules around
# them: caps, nature flavor preferences and eating poffins.

#==================================================================
# class Pokemon
#==================================================================
class Pokemon
  #-----------------------------------------------------------------------------
  # Conditions
  #-----------------------------------------------------------------------------
  # @brief One condition's value.
  # @param condition [Symbol, GameData::ContestCondition] :COOL, :BEAUTY...
  # @return [Integer]
  def condition(condition)
    return GameData::ContestCondition.get(condition).value_of(self)
  end

  # @brief Sets one condition, clamped to 0..ContestSettings::MAX_CONDITION.
  # @param condition [Symbol, GameData::ContestCondition]
  # @param value [Integer]
  def set_condition(condition, value)
    attribute = GameData::ContestCondition.get(condition).attribute
    send("#{attribute}=", value.to_i.clamp(0, ContestSettings::MAX_CONDITION))
  end

  # @brief Every condition's value.
  # @return [Hash{Symbol => Integer}] Keyed by condition ID, in display order.
  def conditions
    ret = {}
    GameData::ContestCondition.each { |c| ret[c.id] = c.value_of(self) }
    return ret
  end

  # @brief The Pokémon's sheen, treating an unset value as 0.
  # @return [Integer]
  def contest_sheen
    return @sheen || 0
  end

  # @brief Sets sheen, clamped to 0..ContestSettings::MAX_SHEEN.
  # @param value [Integer]
  def contest_sheen=(value)
    @sheen = value.to_i.clamp(0, ContestSettings::MAX_SHEEN)
  end

  # @brief Whether sheen is maxed, so the Pokémon won't eat any more poffins.
  # @return [Boolean]
  def sheen_maxed?
    return contest_sheen >= ContestSettings::MAX_SHEEN
  end

  # @brief Sets every condition and sheen back to 0.
  def reset_conditions
    GameData::ContestCondition.each { |c| set_condition(c.id, 0) }
    self.contest_sheen = 0
  end

  #-----------------------------------------------------------------------------
  # Flavors
  #-----------------------------------------------------------------------------
  # @brief The flavor the Pokémon's nature likes.
  # @return [GameData::Flavor, nil] nil for neutral natures.
  def liked_flavor
    return GameData::Flavor.liked_by(nature)
  end

  # @brief The flavor the Pokémon's nature dislikes.
  # @return [GameData::Flavor, nil] nil for neutral natures.
  def disliked_flavor
    return GameData::Flavor.disliked_by(nature)
  end

  #-----------------------------------------------------------------------------
  # Poffins
  #-----------------------------------------------------------------------------
  # @brief Whether the Pokémon can eat a poffin right now.
  # @param _poffin [Poffin] Unused for now; kept so special poffins can add
  #   their own rules later.
  # @return [Boolean]
  def can_eat_poffin?(_poffin = nil)
    return !egg? && !sheen_maxed?
  end

  # @brief How much a poffin would raise each condition and sheen, without
  # changing anything. Liked flavors give NATURE_MULTIPLIER more, disliked
  # ones that much less.
  # @param poffin [Poffin]
  # @return [Hash] { conditions: { :COOL => gain, ... }, sheen: gain }
  def poffin_gains(poffin)
    liked    = liked_flavor&.id
    disliked = disliked_flavor&.id
    gains = {}
    GameData::Flavor.each do |flavor|
      value = poffin.flavor(flavor.id).to_f
      value *= 1 + ContestSettings::NATURE_MULTIPLIER if flavor.id == liked
      value *= 1 - ContestSettings::NATURE_MULTIPLIER if flavor.id == disliked
      current = condition(flavor.condition)
      gains[flavor.condition] = [value.floor, ContestSettings::MAX_CONDITION - current].min
    end
    sheen_gain = [poffin.smoothness, ContestSettings::MAX_SHEEN - contest_sheen].min
    return { conditions: gains, sheen: sheen_gain }
  end

  # @brief Feeds the Pokémon a poffin, raising its conditions and sheen.
  # @param poffin [Poffin]
  # @return [Hash, nil] The gains, as #poffin_gains, or nil if it won't eat.
  def feed_poffin(poffin)
    return nil if !can_eat_poffin?(poffin)
    gains = poffin_gains(poffin)
    gains[:conditions].each { |condition, gain| set_condition(condition, condition(condition) + gain) }
    self.contest_sheen = contest_sheen + gains[:sheen]
    return gains
  end
end

#==================================================================
# class Pokemon::Move
#==================================================================
class Pokemon
  class Move
    # @brief The condition this move appeals to in contests.
    # @return [Symbol]
    def contest_condition
      return GameData::ContestMove.condition_for(@id)
    end

    # @brief This move's contest data.
    # @return [GameData::ContestMove, nil] nil if it isn't in contest_moves.txt.
    def contest_data
      return GameData::ContestMove.try_get(@id)
    end
  end
end

#==================================================================
# module GameData / class Move
#==================================================================
module GameData
  class Move
    # @brief The condition this move appeals to in contests.
    # @return [Symbol]
    def contest_condition
      return GameData::ContestMove.condition_for(@id)
    end
  end
end

#==================================================================
# module ContestConditions
#==================================================================
# @brief Condition rules for fusions. A fusion starts with the best of each
# condition from its two halves, and when it splits, each half keeps the
# best of its own values and the fusion's, so nothing earned is lost.
module ContestConditions
  module_function

  # @brief Gives a Pokémon the higher of its own and another's conditions and sheen.
  # @param target [Pokemon]
  # @param source [Pokemon]
  def merge_into(target, source)
    return if !target || !source
    GameData::ContestCondition.each do |c|
      target.set_condition(c.id, [target.condition(c.id), source.condition(c.id)].max)
    end
    target.contest_sheen = [target.contest_sheen, source.contest_sheen].max
  end
end

if defined?(FusionHandlers)
  module FusionHandlers
    class << self
      alias __contests_fuse_party_pokemon fuse_party_pokemon unless method_defined?(:__contests_fuse_party_pokemon)
      alias __contests_unfuse_party_pokemon unfuse_party_pokemon unless method_defined?(:__contests_unfuse_party_pokemon)
    end

    # @brief Fuses two party Pokémon, then gives the fusion the best of both
    # halves' conditions.
    # @param index1 [Integer] Head's party index; the fusion ends up here.
    # @param index2 [Integer] Body's party index.
    # @return [Boolean]
    def self.fuse_party_pokemon(index1, index2)
      head = $player.party[index1]
      body = $player.party[index2]
      ret = __contests_fuse_party_pokemon(index1, index2)
      if ret
        fusion = $player.party[(index2 < index1) ? index1 - 1 : index1]
        ContestConditions.merge_into(fusion, head)
        ContestConditions.merge_into(fusion, body)
      end
      return ret
    end

    # @brief Unfuses a party Pokémon, then gives both halves anything the
    # fusion gained while fused.
    # @param index [Integer]
    # @return [Boolean]
    def self.unfuse_party_pokemon(index)
      fusion = $player.party[index]
      ret = __contests_unfuse_party_pokemon(index)
      if ret
        ContestConditions.merge_into($player.party[index], fusion)
        ContestConditions.merge_into($player.party.last, fusion)
      end
      return ret
    end
  end
end
