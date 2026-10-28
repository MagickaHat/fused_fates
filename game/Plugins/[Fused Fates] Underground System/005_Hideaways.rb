#================================================================================================
# Pokémon Fused Fates Underground System - 005_Hideaways.rb
#================================================================================================

#==================================================================
# module Underground
#==================================================================
module Underground
  #==================================================================
  # module Hideaways
  #==================================================================
  # @brief Pokémon Hideaways: each HideawayMon event holds one Pokémon a day,
  # shown in the overworld and battled by talking to it.
  #
  # Statues on the Secret Base pedestals shape what spawns:
  # - every statue showing a species (as itself or as either half of a
  #   fusion) raises that species' spawn weight, up to STATUE_BONUS_CAP;
  # - every fused statue whose head is a species gives that species a
  #   FUSED_SPAWN_CHANCE% chance (capped) to spawn fused with the statue's body.
  module Hideaways
    module_function

    # @brief Spawn weight multiplier statues give a species.
    # @param species [Symbol]
    # @param placed [Array<Symbol>] Placed statue IDs.
    # @return [Float]
    def statue_multiplier(species, placed)
      matches = placed.count { |id| GameData::UndergroundStatue.try_get(id)&.shows?(species) }
      mult = 1.0 + (matches * UndergroundSettings::STATUE_BONUS_PER_STATUE)
      return [mult, UndergroundSettings::STATUE_BONUS_CAP].min
    end

    # @brief Fused statues on pedestals whose head is a species.
    # @param species [Symbol]
    # @param placed [Array<Symbol>] Placed statue IDs.
    # @return [Array<Symbol>] Body species of those statues.
    def fused_partners(species, placed)
      return placed.filter_map do |id|
        s = GameData::UndergroundStatue.try_get(id)
        next nil unless s && s.tier == :fused && s.species == species
        s.body
      end
    end

    # @brief Percent chance that a species spawns fused.
    # @param partners [Array<Symbol>] From #fused_partners.
    # @return [Integer]
    def fused_chance(partners)
      chance = partners.length * UndergroundSettings::FUSED_SPAWN_CHANCE
      return [chance, UndergroundSettings::FUSED_SPAWN_CHANCE_CAP].min
    end

    # @brief Rolls today's Pokémon for one hideaway event.
    # @param map_id [Integer]
    # @param event_id [Integer]
    # @return [Hash, nil] { species:, level:, partner: }, or nil if the map
    # has no hideaway data.
    def roll_spawn(map_id, event_id)
      table = GameData::UndergroundHideaway.try_get(map_id)&.encounters
      return nil if table.nil? || table.empty?
      d = Underground.data
      rng = DailyRefresh.seeded_rng(d.day_key, map_id, event_id, "hideaway")
      placed = d.placed_statues
      weights = {}
      table.each_with_index do |(species, weight, _min, _max), i|
        next unless GameData::Species.exists?(species)
        weights[i] = weight * statue_multiplier(species, placed)
      end
      index = DailyRefresh.weighted_pick(weights, rng)
      return nil if index.nil?
      species, _weight, min, max = table[index]
      spawn = { species: species, level: min + rng.rand(max - min + 1), partner: nil }
      partners = fused_partners(species, placed).select { |p| GameData::Species.exists?(p) }
      if !partners.empty? && rng.rand(100) < fused_chance(partners)
        spawn[:partner] = partners[rng.rand(partners.length)]
      end
      return spawn
    end

    # @brief Today's Pokémon for a hideaway event, rolled the first time it's asked for.
    # @param map_id [Integer]
    # @param event_id [Integer]
    # @return [Hash, nil]
    def spawn_for(map_id, event_id)
      d = Underground.data
      key = [map_id, event_id]
      d.hideaway_spawns[key] ||= roll_spawn(map_id, event_id)
      return d.hideaway_spawns[key]
    end

    # @brief Whether today's Pokémon at an event was caught or defeated.
    # @param map_id [Integer]
    # @param event_id [Integer]
    # @return [Boolean]
    def cleared?(map_id, event_id)
      return Underground.data.cleared_mons.include?([map_id, event_id])
    end

    # @brief Builds the Pokémon for a spawn.
    # @param spawn [Hash] { species:, level:, partner: }
    # @return [Pokemon]
    def build_pokemon(spawn)
      species = spawn[:species]
      body = spawn[:partner]
      return Pokemon.new(species, spawn[:level]) unless body && defined?(FusedPokemon)
      pkmn = FusedPokemon.new(species, spawn[:level], species, body)
      pkmn.original_head_data = GameData::Species.get(species)
      pkmn.original_body_data = GameData::Species.get(body)
      pkmn.invalidate_fusion_caches
      pkmn.calc_stats
      pkmn.hp = pkmn.totalhp
      return pkmn
    end

    # @brief The overworld graphic for a HideawayMon event.
    # @param event [Game_Event]
    # @return [String, nil]
    def graphic(event)
      return nil unless GameData::UndergroundHideaway.exists?(event.map_id)
      spawn = spawn_for(event.map_id, event.id)
      return nil unless spawn
      return Underground.pokemon_charset(spawn[:species], spawn[:partner])
    end

    # @brief Hides the HideawayMon events whose Pokémon is gone for today.
    def refresh
      map_id = $game_map.map_id
      return unless GameData::UndergroundHideaway.exists?(map_id)
      Underground.events_named(UndergroundSettings::EVENT_HIDEAWAY_MON).each do |ev|
        gone = cleared?(map_id, ev.id) || spawn_for(map_id, ev.id).nil?
        Underground.set_hidden(ev, gone)
      end
      Underground.refresh_graphics
    end
  end
end

# @brief Hideaway Pokémon event: battles today's Pokémon.
# Call it from a HideawayMon event's page 1.
# @return [Integer] The battle outcome (1 = won, 4 = caught, 0 = no battle).
def pbUndergroundHideawayMon
  ev = Underground.calling_event
  return 0 unless ev
  hw = Underground::Hideaways
  return 0 if hw.cleared?(ev.map_id, ev.id)
  spawn = hw.spawn_for(ev.map_id, ev.id)
  return 0 unless spawn
  pkmn = hw.build_pokemon(spawn)
  pkmn.play_cry if pkmn.respond_to?(:play_cry)
  pbMessage(_INTL("The wild {1} is staring at you!", pkmn.name))
  outcome = WildBattle.start_core(pkmn)
  if [1, 4].include?(outcome)
    d = Underground.data
    d.cleared_mons.push([ev.map_id, ev.id])
    d.stats[:hideaway_catches] += 1 if outcome == 4
    d.stats[:hideaway_battles] += 1
    Underground.set_hidden(ev, true)
  end
  return outcome
end

EventHandlers.add(:on_enter_map, :underground_hideaways,
  proc { |_old_map_id|
    Underground::Hideaways.refresh if Underground.in_underground?
  }
)
