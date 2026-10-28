#================================================================================================
# Pokémon Fused Fates Underground System - 000_Settings.rb
#================================================================================================

#==================================================================
# module UndergroundSettings
#==================================================================
# @brief Tunable values and map setup for the Fused Fates Underground.
module UndergroundSettings
  #-----------------------------------------------------------------------------
  # Maps
  #-----------------------------------------------------------------------------
  # @brief Tunnel maps that contain dig spots and Diglett events
  TUNNEL_MAPS = [1, 2, 3]

  # @brief Secret Base room maps, keyed by base size.
  BASE_MAPS = { small: 4, medium: 5, large: 6 }

  # Hideaway map IDs are the keys of HIDEAWAYS in 002_Data.rb.
  
  #-----------------------------------------------------------------------------
  # Placeholder event names (set these as event names in RMXP)
  # 
  # Every placeholder event needs two pages:
  #   Page 1 - the visible version (sparkle, Diglett, statue slot...)
  #   Page 2 - condition: Self Switch HIDE_SWITCH is ON, no graphic
  #-----------------------------------------------------------------------------
  EVENT_DIG_SPOT     = "DigSpot"
  EVENT_DIGLETT      = "Diglett"
  EVENT_HIDEAWAY_MON = "HideawayMon"
  EVENT_BASE_SLOT    = "BaseSlot"

  # @brief Self switch used to hide a placeholder event.
  HIDE_SWITCH = "A"

  #-----------------------------------------------------------------------------
  # Digging
  #-----------------------------------------------------------------------------
  # @brief Dig spots chosen per tunnel map each day.
  DIG_SPOTS_PER_MAP = 4

  # @brief Digletts the player must find to fill the bonus meter.
  DIGLETTS_PER_BONUS = 10

  # @brief Bonus digs granted each time the meter fills.
  BONUS_DIGS_PER_FILL = 3

  # @brief Weight multiplier applied to rare treasures during a bonus dig.
  BONUS_RARE_MULTIPLIER = 3

  #-----------------------------------------------------------------------------
  # Hideaways
  #-----------------------------------------------------------------------------
  # @brief Highest spawn-weight multiplier statues can give one species.
  STATUE_BONUS_CAP = 3.0

  # @brief Percent chance per matching fused statue that a spawn is fused.
  FUSED_SPAWN_CHANCE = 8

  # @brief Upper limit for the fused spawn chance, in percent.
  FUSED_SPAWN_CHANCE_CAP = 25

  # @brief Overworld sprite path for hideaway Pokémon
  # (relative to Graphics/Characters).
  OVERWORLD_SPRITE_PATH = "Followers/%s"

  #-----------------------------------------------------------------------------
  # Secret Base
  #-----------------------------------------------------------------------------
  # @brief Statue pedestals available for each base size.
  PEDESTALS_BY_SIZE = { small: 2, medium: 4, large: 6 }

  #-----------------------------------------------------------------------------
  # Spheres
  #-----------------------------------------------------------------------------
  # @brief Underground steps needed for a buried sphere to grow one size.
  SPHERE_GROWTH_STEPS = 250

  # @brief Largest size a buried sphere can reach.
  SPHERE_MAX_SIZE = 20

  #-----------------------------------------------------------------------------
  # Mission gates
  #-----------------------------------------------------------------------------
  # @brief Mission stage that must be reached before each
  # statue tier can be dug from walls. Fused statues are
  # never dug.
  STATUE_TIER_STAGE = { common: 1, rare: 6 }

  # @brief Mission stage from which traders can stock fused statues
  FUSED_TRADER_STAGE = 7
end