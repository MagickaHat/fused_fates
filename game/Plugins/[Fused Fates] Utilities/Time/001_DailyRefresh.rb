#================================================================================================
# Pokémon Fused Fates Utilities/Time - 001_DailyRefresh.rb
#================================================================================================

#==================================================================
# module DailyRefresh
#==================================================================
# @brief Helpers for state that resets once a day, and for daily picks that stay
# the same however many times they are rolled that day.
module DailyRefresh
  module_function

  # @brief A number unique to today's date, e.g. 20261028.
  # @return [Integer]
  def today_key
    t = pbGetTimeNow
    return (t.year * 10_000) + (t.month * 100) + t.day
  end

  # @brief An RNG that gives the same results for the same inputs, even after
  # reloading. Pass the day key as one of the parts so daily picks don't
  # reshuffle when they are rolled again the same day.
  # @param parts [Array] Anything that identifies the roll (day, map, event...).
  # @return [Random]
  def seeded_rng(*parts)
    return Random.new(Hex.crc32(parts.join(",")))
  end

  # @brief Picks a key from a { key => weight } hash.
  # @param weights [Hash]
  # @param rng [Random]
  # @return [Object, nil] nil if every weight is zero.
  def weighted_pick(weights, rng = Random)
    total = weights.values.sum
    return nil if total <= 0
    roll = rng.rand * total
    weights.each do |key, weight|
      roll -= weight
      return key if roll < 0
    end
    return weights.keys.last
  end
end

#==================================================================
# module DailyRefreshable
#==================================================================
# @brief Mixin for objects (usually save data) holding state that resets each day.
#
# Include it, override #on_new_day to clear the daily state, and call
# #refresh_day! before reading that state. The date the state belongs to is
# kept in @day_key, so it is saved along with the object.
module DailyRefreshable
  # @brief Date key (see DailyRefresh.today_key) the daily state belongs to.
  # @return [Integer]
  def day_key
    return @day_key || 0
  end

  # @param value [Integer]
  def day_key=(value)
    @day_key = value
  end

  # @brief Runs #on_new_day if the date has changed since the state was last refreshed.
  # @return [Boolean] Whether a new day began.
  def refresh_day!
    key = DailyRefresh.today_key
    return false if key == day_key
    @day_key = key
    on_new_day
    return true
  end

  # @brief Starts a new day right away, even if the date hasn't changed.
  def force_new_day!
    @day_key = DailyRefresh.today_key
    on_new_day
  end

  # @brief Clears the daily state. Override this in the including class.
  def on_new_day; end
end
