#================================================================================================
# Pokémon Fused Fates Wonder Link System - 005_Safari.rb
#================================================================================================

#==================================================================
# module WonderLink::Safari
#==================================================================
# @brief The Wonder Link side of the Safari Zone.
#
# Every save is given SAFARI_SIGNATURE_SIZE species from SAFARI_POOL. Profile codes carry the
# sharer's species, and redeeming one (once per code per day) boosts those species for the rest
# of the day. This module only keeps track of the boosts; the Safari Zone plugin decides how
# they affect its encounters, by passing its own weights through WonderLink::Safari.weights
# and listening for :on_wonder_link_safari_redeemed to re-roll when a code comes in.
module WonderLink
  module Safari
    module_function

    # @brief This save's Safari species. Rolled the first time they're needed, from the
    # player's trainer ID, so they never change for a save.
    # @return [Array<Symbol>]
    def signature
      data = WonderLink.data
      data.safari_signature ||= roll_signature($player ? $player.id : 0)
      return data.safari_signature
    end

    # @brief Picks Safari species without repeats, using SAFARI_POOL's weights.
    # @param seed [Integer] Gives the same species every time for the same seed.
    # @return [Array<Symbol>]
    def roll_signature(seed)
      rng  = DailyRefresh.seeded_rng("wonder_link_safari", seed)
      pool = WonderLinkSettings::SAFARI_POOL.select { |species, _w| GameData::Species.exists?(species) }
      ret  = []
      WonderLinkSettings::SAFARI_SIGNATURE_SIZE.times do
        pick = DailyRefresh.weighted_pick(pool, rng)
        break if !pick
        ret.push(pick)
        pool = pool.reject { |species, _w| species == pick }
      end
      return ret
    end

    # @brief Throws away this save's Safari species and rolls new random ones. Debug use.
    # @return [Array<Symbol>]
    def reroll_signature
      WonderLink.data.safari_signature = roll_signature(rand(2**32))
      return signature
    end

    # @brief Species boosted by codes today.
    # @return [Hash{Symbol => Integer}] Species => how many codes boosted it.
    def boosts_today
      return WonderLink.data.safari_boosts
    end

    # @brief Applies today's boosts to a set of encounter weights.
    # Boosted species that aren't in base_weights are added, so a friend's species can appear
    # even where it doesn't normally live. Pass only_existing to stop that.
    # @param base_weights [Hash{Symbol => Numeric}] Species => normal weight.
    # @param only_existing [Boolean] Only boost species already in base_weights.
    # @return [Hash{Symbol => Numeric}] A new hash; base_weights is not changed.
    def weights(base_weights, only_existing = false)
      ret = base_weights.dup
      boosts_today.each do |species, count|
        next if only_existing && !ret.key?(species)
        ret[species] = (ret[species] || 0) + (count * WonderLinkSettings::SAFARI_CODE_WEIGHT_BONUS)
      end
      return ret
    end

    # @brief Applies a decoded profile code's Safari species to today's boosts.
    # Checks the daily cooldown and SAFARI_MAX_CODES_PER_DAY, showing messages for either.
    # @param decoded [Hash] A decoded :party code.
    # @return [Boolean] Whether the boost was applied.
    def apply_code(decoded)
      species = decoded[:signature] || []
      if species.empty?
        pbMessage(_INTL("That code doesn't have any Safari Zone Pokémon linked to it."))
        return false
      end
      limit = WonderLinkSettings::SAFARI_MAX_CODES_PER_DAY
      if limit > 0 && WonderLink.data.uses_today(:safari) >= limit
        pbMessage(_INTL("The Safari Zone can't take any more Wonder Link codes today. Come back tomorrow!"))
        return false
      end
      return false if !WonderLink.use_daily(decoded, :safari)
      species.each { |s| boosts_today[s] = (boosts_today[s] || 0) + 1 }
      EventHandlers.trigger(:on_wonder_link_safari_redeemed, species, decoded)
      return true
    end

    # @brief Asks for a profile code and boosts its Safari species for today.
    # @return [Boolean] Whether the boost was applied.
    def redeem_from_input
      decoded = WonderLink.ask_for_code(_INTL("Enter a friend's Wonder Link code to link with their Safari Zone."), [:party])
      return false if !decoded || !apply_code(decoded)
      WonderLink.on_profile_redeemed(decoded)
      names = decoded[:signature].map { |s| GameData::Species.get(s).name }
      pbMessage(_INTL("Linked with {1}'s Safari Zone! {2} should be easier to find today.",
                      WonderLink.owner_name(decoded), names.join(", ")))
      return true
    end
  end
end
