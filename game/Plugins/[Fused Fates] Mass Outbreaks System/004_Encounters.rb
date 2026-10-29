#================================================================================================
# Pokémon Fused Fates Mass Outbreaks System - 004_Encounters.rb
#================================================================================================
# @brief Hooks that turn wild encounters into outbreak Pokémon, give them
# their tier perks and count them afterwards.
#
# Flow of one encounter:
#   1. pbBattleOnStepTaken / pbEncounter reset the per-encounter flags.
#   2. :on_wild_species_chosen may swap the species and level for the
#      outbreak's, and remembers which outbreak did it.
#   3. :on_wild_pokemon_created sets the form and applies the current tier.
#   4. :on_wild_battle_end adds to the counter and announces new tiers.
# Outbreak encounters are forced to be single battles, the same as roaming
# Pokémon and Poké Radar chains, because Essentials only reports the result
# of single wild battles through :on_wild_battle_end.

#==================================================================
# module MassOutbreaks
#==================================================================
module MassOutbreaks
  # @brief Reset the per-encounter flags. Called before every encounter.
  def self.reset_encounter
    return if !$game_temp
    $game_temp.mass_outbreak_id     = nil
    $game_temp.mass_outbreak_rolled = false
  end

  # @brief Whether an encounter is allowed to become an outbreak Pokémon.
  # Leaves roaming Pokémon, Poké Radar chains and the Bug-Catching Contest
  # alone, and only rolls once per encounter.
  # @param encounter [Array, nil] [species, level] as chosen by Essentials.
  # @return [Boolean]
  def self.can_replace?(encounter)
    return false if !encounter || !enabled?
    return false if $game_temp.mass_outbreak_rolled
    return false if !$game_temp.encounter_type
    return false if !$game_temp.roamer_index_for_encounter.nil?
    return false if $game_temp.poke_radar_data
    return false if pbInBugContest?
    return true
  end

  # @brief Replace an encounter with the outbreak Pokémon for the current
  # map and encounter category, if there is one and the rate roll passes.
  # @param encounter [Array] [species, level], changed in place.
  # @return [Boolean] Whether the encounter was replaced.
  def self.try_replace(encounter)
    return false if !can_replace?(encounter)
    $game_temp.mass_outbreak_rolled = true
    category = GameData::EncounterType.try_get($game_temp.encounter_type)&.type
    return false if !category
    e, _rec = find($game_map.map_id, category)
    return false if !e
    return false if rand(100) >= ENCOUNTER_RATE
    encounter[0] = e[:species]
    encounter[1] = rand(e[:levels])
    $game_temp.mass_outbreak_id    = e[:id]
    $game_temp.force_single_battle = true
    return true
  end

  # @brief Give a freshly generated wild Pokémon its outbreak form and perks.
  # @param pkmn [Pokemon] The wild Pokémon.
  def self.prepare_pokemon(pkmn)
    id = $game_temp.mass_outbreak_id
    return if !id
    e = entry(id)
    return if !e || !matches?(pkmn, e)
    pkmn.form = e[:form] if e[:form] > 0
    Perks.apply(pkmn, tier_for(id))
  end

  # @brief Count a finished outbreak battle and announce a new tier.
  # @param species [Symbol] Species battled.
  # @param decision [Integer] Battle outcome (see COUNTED_DECISIONS).
  def self.finish_battle(species, decision)
    id = $game_temp.mass_outbreak_id
    reset_encounter
    return if !id
    e = entry(id)
    return if !e || e[:species] != species
    return if !COUNTED_DECISIONS.include?(decision)
    tiered = add_to_counter(id)
    announce_tier_up(e) if tiered && ANNOUNCE_TIER_UP
  end
end

#==================================================================
# Encounter entry points
#==================================================================
alias __outbreaks_pbBattleOnStepTaken pbBattleOnStepTaken unless defined?(__outbreaks_pbBattleOnStepTaken)

# @brief Step encounters. Resets the outbreak flags before rolling.
# @param repel_active [Boolean] Whether a Repel is active.
def pbBattleOnStepTaken(repel_active)
  MassOutbreaks.reset_encounter
  __outbreaks_pbBattleOnStepTaken(repel_active)
end

alias __outbreaks_pbEncounter pbEncounter unless defined?(__outbreaks_pbEncounter)

# @brief Fishing, Headbutt, Rock Smash and Sweet Scent encounters. Resets the
# outbreak flags before rolling.
# @param enc_type [Symbol] Encounter type.
# @param only_single [Boolean] Whether a double battle is not allowed.
# @return [Boolean] Whether an encounter happened.
def pbEncounter(enc_type, only_single = true)
  MassOutbreaks.reset_encounter
  return __outbreaks_pbEncounter(enc_type, only_single)
end

#==================================================================
# Event handlers
#==================================================================
EventHandlers.add(:on_wild_species_chosen, :mass_outbreak,
  proc { |encounter|
    MassOutbreaks.try_replace(encounter)
  }
)

EventHandlers.add(:on_wild_pokemon_created, :mass_outbreak,
  proc { |pkmn|
    MassOutbreaks.prepare_pokemon(pkmn)
  }
)

EventHandlers.add(:on_wild_battle_end, :mass_outbreak,
  proc { |species, _level, decision|
    MassOutbreaks.finish_battle(species, decision)
  }
)

EventHandlers.add(:on_enter_map, :mass_outbreak,
  proc { |_old_map_id|
    MassOutbreaks.reset_encounter
  }
)
