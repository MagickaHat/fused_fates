#================================================================================================
# Pokémon Fused Fates Mass Outbreaks System - 005_Perks.rb
#================================================================================================
# @brief Bonuses given to outbreak Pokémon, depending on the outbreak's tier.
# Each key in a tier hash (other than :count) names a perk registered here.
# The value in the tier is passed to the perk, so a tier like
#   { count: 30, shiny_rolls: 1, hidden_ability: 5 }
# gives one extra shiny roll and a 5% Hidden Ability chance.

#==================================================================
# module MassOutbreaks::Perks
#==================================================================
module MassOutbreaks
  module Perks
    @@perks = {}

    # @brief Register a perk, or replace one with the same name.
    # @param name [Symbol] Key used in tier hashes.
    # @yieldparam pkmn [Pokemon] The wild outbreak Pokémon.
    # @yieldparam value [Object] The tier's value for this perk.
    def self.register(name, &block)
      @@perks[name] = block
    end

    # @brief Whether a perk exists.
    # @param name [Symbol] Perk name.
    # @return [Boolean]
    def self.exists?(name)
      return @@perks.key?(name)
    end

    # @brief Apply every perk in a tier to a Pokémon.
    # Perks with a value of 0, false or nil are skipped.
    # @param pkmn [Pokemon] The wild outbreak Pokémon.
    # @param tier [Hash] Tier hash from MassOutbreaks.tier_for.
    def self.apply(pkmn, tier)
      tier.each do |name, value|
        next if name == :count || !value || value == 0
        perk = @@perks[name]
        if !perk
          DevLog.once([:mass_outbreak_perk, name], "Mass outbreak perk :#{name} isn't registered")
          next
        end
        perk.call(pkmn, value)
      end
    end

    # @brief Roll a percent chance.
    # @param percent [Integer] 0-100.
    # @return [Boolean]
    def self.chance?(percent)
      return rand(100) < percent
    end
  end

  #----------------------------------------------------------------
  # Built-in perks
  #----------------------------------------------------------------
  # @brief Extra shiny rolls on top of the normal one, the same way the Shiny
  # Charm works in pbGenerateWildPokemon.
  Perks.register(:shiny_rolls) do |pkmn, rolls|
    rolls.to_i.times do
      break if pkmn.shiny?
      pkmn.shiny = nil   # Make it recalculate shininess
      pkmn.personalID = rand(2**16) | (rand(2**16) << 16)
    end
  end

  # @brief Percent chance of one of the species' Hidden Abilities.
  Perks.register(:hidden_ability) do |pkmn, percent|
    next if pkmn.hasHiddenAbility? || !Perks.chance?(percent)
    hidden = pkmn.getAbilityList.select { |_ability, index| index >= 2 }
    next if hidden.empty?
    pkmn.ability_index = hidden.sample[1]
  end

  # @brief Percent chance of knowing one egg move the Pokémon doesn't already know.
  Perks.register(:egg_move) do |pkmn, percent|
    next if !Perks.chance?(percent)
    moves = pkmn.species_data.get_egg_moves.reject { |m| pkmn.hasMove?(m) }
    next if moves.empty?
    pkmn.learn_move(moves.sample)
  end
end
