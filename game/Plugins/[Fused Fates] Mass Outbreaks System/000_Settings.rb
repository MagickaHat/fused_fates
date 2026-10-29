#================================================================================================
# Pokémon Fused Fates Mass Outbreaks System - 000_Settings.rb
#================================================================================================

#==================================================================
# module MassOutbreaksSettings
#==================================================================
# @brief Tunable values for the Mass Outbreaks system.
module MassOutbreaksSettings
  # @brief How outbreaks are scheduled.
  #   - :daily    DPPt style. DAILY_COUNT outbreaks are rolled together when
  #               the day changes and all last until the next day.
  #   - :rotating SV style. Several outbreaks run across the region at once.
  #               Each has its own duration, and as they expire, new ones
  #               appear, so the set changes gradually through the day.
  MODE = :rotating

  # @brief Number of outbreaks rolled each day in :daily mode.
  # 1 matches DPPt. Each outbreak needs its own map/category pair, so fewer
  # may be active if the eligible pool is small.
  DAILY_COUNT = 1

  # @brief Range for how many outbreaks :rotating mode keeps active.
  # Each hour a target within this range is rolled, and new outbreaks
  # are added until the target is reached. Outbreaks are never removed
  # early to meet a lower target; they just aren't replaced when they expire.
  ACTIVE_RANGE = 2..5

  # @brief How long each outbreak lasts in :rotating mode, in hours.
  # A pool entry's :hours option overrides this.
  DURATION_HOURS = 3..8

  # @brief Most outbreaks allowed at once in the same zone (0 = no limit).
  # Zones are set per pool entry with :zone, and keep outbreaks spread
  # across the region instead of clustering on neighboring routes. Entries
  # without a zone are never limited.
  MAX_PER_ZONE = 1

  # @brief Percent chance an eligible encounter becomes the outbreak species.
  ENCOUNTER_RATE = 40

  # @brief Game switch that must be ON before outbreaks happen.
  # 0 means outbreaks are always enabled.
  UNLOCK_SWITCH = 0

  # @brief Game variable holding an in-game day counter.
  # 0 uses the real-time clock (pbGetTimeNow). A variable stops players from
  # rerolling outbreaks by changing their system clock.
  DAY_VARIABLE = 0

  # @brief Battle decisions that add to an outbreak's counter.
  # 1 = won (KO), 4 = caught. 3 also counts fleeing.
  COUNTED_DECISIONS = [1, 4]

  # @brief Mark an outbreak species as seen in the Pokédex when announced.
  MARK_SEEN_ON_ANNOUNCE = true

  # @brief Show a message after battle when the counter reaches a new tier.
  ANNOUNCE_TIER_UP = true

  # @brief Default perk tiers, ordered from highest count to lowest.
  # The first tier whose :count the counter has reached is used. Every other
  # key is a perk name registered in 005_Perks.rb; its value is passed to that
  # perk. Pool entries can override this list with :perks. Built-in perks:
  #   - :shiny_rolls    extra shiny rolls on top of the normal one
  #   - :hidden_ability percent chance of a Hidden Ability
  #   - :egg_move       percent chance of knowing one egg move
  TIERS = [
    { count: 60, shiny_rolls: 2, hidden_ability: 10, egg_move: 25 },
    { count: 30, shiny_rolls: 1, hidden_ability: 5,  egg_move: 15 },
    { count: 10, shiny_rolls: 0, hidden_ability: 2,  egg_move: 5  },
    { count: 0,  shiny_rolls: 0, hidden_ability: 0,  egg_move: 0  }
  ]
end