#================================================================================================
# Pokémon Fused Fates Mass Outbreaks System - 003_Manager.rb
#================================================================================================
# @brief Scheduling, lookups, counters and tier selection.
# Every public lookup calls refresh first, so new outbreaks are rolled
# the first time anything asks about them. No map or clock hooks are
# needed, and an expired outbreak stops working on the next encounter check.

#==================================================================
# module MassOutbreaks
#==================================================================
module MassOutbreaks
  #----------------------------------------------------------------
  # Time
  #----------------------------------------------------------------
  # @brief Whether outbreaks can happen right now.
  # @return [Boolean] False before a save is loaded or before the unlock switch.
  def self.enabled?
    return false if !$player || !$PokemonGlobal
    return true if UNLOCK_SWITCH <= 0
    return $game_switches[UNLOCK_SWITCH] ? true : false
  end

  # @brief Key identifying the current day.
  # @return [Integer] The day variable if configured, otherwise YYYYMMDD.
  def self.current_day_key
    return $game_variables[DAY_VARIABLE] if DAY_VARIABLE > 0
    t = pbGetTimeNow
    return (t.year * 10_000) + (t.month * 100) + t.day
  end

  # @brief Current hour, counted from a fixed point. Used by :rotating mode.
  # With DAY_VARIABLE set, the day comes from the variable and only the hour
  # comes from the clock, so changing the system clock can at most shuffle
  # outbreaks within the current in-game day.
  # @return [Integer] Hour tick.
  def self.current_tick
    return ($game_variables[DAY_VARIABLE] * 24) + pbGetTimeNow.hour if DAY_VARIABLE > 0
    return pbGetTimeNow.to_i / 3600
  end

  # @brief Saved state shortcut.
  # @return [Hash] $PokemonGlobal.mass_outbreaks
  def self.state
    return $PokemonGlobal.mass_outbreaks
  end

  #----------------------------------------------------------------
  # Scheduling
  #----------------------------------------------------------------
  # @brief Bring the active outbreaks up to date for the current time.
  # Clears everything first if the saved outbreaks were rolled under a
  # different MODE.
  def self.refresh
    return if !enabled?
    if state[:mode]  != MODE
      state[:mode]    = MODE
      state[:active]  = []
      state[:day]     = -1
      state[:tick]    = -1
    end
    (MODE == :rotating) ? refresh_rotating : refresh_daily
  end

  # @brief :daily mode. Roll a full new set when the day changes.
  def self.refresh_daily
    day = current_day_key
    return if state[:day] == day
    state[:day]    = day
    state[:active] = []
    rng = Random.new(day ^ $player.id)
    add_outbreaks(DAILY_COUNT, rng, nil)
  end

  # @brief :rotating_mode. Expire old outbreaks and top up to a target.
  # Runs at most once per hour tick. The RNG is seeded from the tick and
  # trainer ID, so reloading within the same hour gives the same result.
  def self.refresh_rotating
    now = current_tick
    return if state[:tick] == now
    state[:tick] = now
    # Records without :expires came from :daily mode or an older version.
    state[:active].reject! { |rec| !rec[:expires] || rec[:expires] <= now }
    rng = Random.new(now ^ $player.id)
    target = rng.rand(ACTIVE_RANGE)
    add_outbreaks(target - state[:active].length, rng, now)
  end

  # @brief Start new outbreaks alongside the ones already active.
  # @param amount [Integer] How many to try to add (may add fewer).
  # @param rng [Random] RNG to draw from.
  # @param now [Inetger, nil] Current hour tick, or nil for :daily outbreaks.
  # @return [Integer] How many were added.
  def self.add_outbreaks(amount, rng, now)
    added = 0
    amount.times do
      others = state[:active].filter_map { |rec| entry(rec[:id]) }
      canidates = pool.values.select { |e| eligible?(e) && fits_with?(e, others) }
      break if canidates.empty?
      e = weighted_pick(canidates, rng)
      expires = now ? now + roll_duration(e, rng) : nil
      state[:active].push({ id: e[:id], count: 0, expires: expires })
      added += 1
    end
    return added
  end

  # @brief Whether an entry can run alongside the given outbreaks.
  # Rejects a second outbreak on the same map and category (so the hooks
  # never have to choose), a second outbreak of the same species, and any
  # outbreak that would go over MAX_PER_ZONE.
  # @param e [Hash] Canidate entry.
  # @param others [Array<Hash>] Entries already active.
  # @return [Boolean]
  def self.fits_with?(e, others)
    others.each do |o|
      return false if o[:id] == e[:id] || o[:species] == e[:species]
      return false if o[:map] == e[:map] && o[:category] == e[:category]
    end
    if e[:zone] && MAX_PER_ZONE > 0
      return false if others.count { |o| o[:zone] == e[:zone] } >= MAX_PER_ZONE
    end
    return true
  end

  # @brief Roll how many hours an outbreak lasts.
  # @param e [Hash] Pool entry.
  # @param rng [Random] RNG to draw from.
  # @return [Integer] At least 1.
  def self.roll_duration(e, rng)
    hours = e[:hours] || DURATION_HOURS
    hours = rng.rand(hours) if hours.is_a?(Range)
    return [hours, 1].max
  end

  # @brief Throw away every active outbreak and roll a fresh set.
  # Used by the debug menu. Pass an unseeded RNG for a different result.
  # @param rng [Random] RNG to draw from.
  def self.reroll(rng = Random.new)
    refresh
    state[:active] = []
    if MODE == :rotating
      now = current_tick
      add_outbreaks(rng.rand(ACTIVE_RANGE), rng, now)
    else
      add_outbreaks(DAILY_COUNT, rng, nil)
    end
  end

  # @brief Whether an entry can be rolled with the player's current progress.
  # @param entry [Hash] Pool entry.
  # @return [Boolean]
  def self.eligible?(entry)
    return false if $player.badge_count < entry[:badges]
    return false if entry[:switch] && !$game_switches[entry[:switch]]
    return false if !GameData::Species.exists?(entry[:species])
    return true
  end
end