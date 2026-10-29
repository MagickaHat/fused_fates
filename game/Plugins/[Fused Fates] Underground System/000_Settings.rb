#================================================================================================
# Pokémon Fused Fates Underground System - 000_Settings.rb
#================================================================================================

#==================================================================
# module UndergroundSettings
#==================================================================
# @brief Tunable values and map setup for the Fused Fates Underground.
#
# A map is "inside the Underground" (pause menu entry, sphere growth, cave-in
# refresh...) only if it has the MAP_FLAG flag in PBS/map_metadata.txt.
# The map IDs below only say what role a map plays, and are examples: point
# them at your own Underground maps before playtesting.
module UndergroundSettings
  #-----------------------------------------------------------------------------
  # Maps
  #-----------------------------------------------------------------------------
  # @brief Map metadata flag that marks a map as part of the Underground. Add
  # "Flags = Underground" to every tunnel, base room, rival base, station and
  # hideaway map in PBS/map_metadata.txt (or in the debug map metadata editor).
  MAP_FLAG = "Underground"

  # @brief Tunnel maps that contain dig spots and Diglett events
  TUNNEL_MAPS = [1, 2, 3]

  # @brief Secret Base room maps, keyed by base size.
  BASE_MAPS = { small: 4, medium: 5, large: 6 }

  # @brief Where the player appears in each Secret Base room, as
  # [x, y, direction] (2 = down, 4 = left, 6 = right, 8 = up).
  BASE_ENTRY = { small: [7, 10, 8], medium: [9, 12, 8], large: [11, 14, 8] }

  # Hideaway map IDs are the section names in PBS/underground_hideaways.txt.

  #-----------------------------------------------------------------------------
  # Placeholder event names (set these as event names in RMXP)
  #
  # Every placeholder event needs two pages:
  #   Page 1 - the visible version (sparkle, Diglett, statue slot...)
  #   Page 2 - condition: Self Switch HIDE_SWITCH is ON, no graphic
  #
  # Slot events take a number after a colon, e.g. "BaseSlot:1", "GoodSlot:3".
  # Rival flags take the rival ID, e.g. "RivalFlag:digger_a".
  #-----------------------------------------------------------------------------
  EVENT_DIG_SPOT     = "DigSpot"
  EVENT_DIGLETT      = "Diglett"
  EVENT_HIDEAWAY_MON = "HideawayMon"
  EVENT_BASE_SLOT    = "BaseSlot"
  EVENT_GOOD_SLOT    = "GoodSlot"
  EVENT_RIVAL_FLAG   = "RivalFlag"

  # Walls where the player can dig their Secret Base. Each needs two pages:
  #   Page 1 - a plain wall, Action Button, script: pbUndergroundSecretBase
  #   Page 2 - condition: Self Switch BASE_ENTRANCE_SWITCH is ON, the open
  #            entrance graphic, same script
  EVENT_BASE_WALL    = "BaseWall"

  # @brief Self switch used to hide a placeholder event.
  HIDE_SWITCH = "A"

  # @brief Self switch that turns a BaseWall into the open base entrance.
  BASE_ENTRANCE_SWITCH = "B"

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

  # @brief Treasure weight at or below which a treasure counts as rare.
  RARE_TREASURE_WEIGHT = 20

  # @brief How many treasures can be buried in one wall.
  MINING_ITEMS_RANGE = (2..4)

  # @brief Extra treasures buried in the wall during a bonus dig.
  BONUS_DIG_EXTRA_ITEMS = 1

  # @brief Percent chance that a fully cleared wall gives up a statue.
  STATUE_FIND_CHANCE = 15

  # @brief Percent chance during a bonus dig.
  BONUS_STATUE_FIND_CHANCE = 30

  # @brief Percent of statue finds that roll the rare tier, once it is unlocked.
  RARE_STATUE_SHARE = 25

  #-----------------------------------------------------------------------------
  # Hideaways
  #-----------------------------------------------------------------------------
  # @brief Highest spawn-weight multiplier statues can give one species.
  STATUE_BONUS_CAP = 3.0

  # @brief Spawn-weight bonus each matching statue adds (0.5 = +50%).
  STATUE_BONUS_PER_STATUE = 0.5

  # @brief Percent chance per matching fused statue that a spawn is fused.
  FUSED_SPAWN_CHANCE = 8

  # @brief Upper limit for the fused spawn chance, in percent.
  FUSED_SPAWN_CHANCE_CAP = 25

  # @brief Overworld sprite path for hideaway Pokémon and statues
  # (relative to Graphics/Characters).
  OVERWORLD_SPRITE_PATH = "Followers/%s"

  #-----------------------------------------------------------------------------
  # Secret Base
  #-----------------------------------------------------------------------------
  # @brief Statue pedestals available for each base size.
  PEDESTALS_BY_SIZE = { small: 2, medium: 4, large: 6 }

  # @brief Goods slots available for each base size.
  GOOD_SLOTS_BY_SIZE = { small: 3, medium: 6, large: 10 }

  #-----------------------------------------------------------------------------
  # Spheres
  #-----------------------------------------------------------------------------
  # @brief Underground steps needed for a buried sphere to grow one size.
  SPHERE_GROWTH_STEPS = 250

  # @brief Largest size a buried sphere can reach.
  SPHERE_MAX_SIZE = 20

  # @brief How many sphere batches each planter can hold at once.
  PLANTER_CAPACITY = 3

  #-----------------------------------------------------------------------------
  # Traders
  #-----------------------------------------------------------------------------
  # @brief How many different wares a trader offers each day.
  TRADER_STOCK_SIZE = 4

  # @brief Percent of a ware's price a trader pays to buy it back. Each
  # sphere color is rounded down, but never below 1.
  SELL_BACK_RATE = 50

  # @brief Statue prices by tier, as { sphere color => units }, for statues
  # without a Price in PBS/underground_traders.txt.
  STATUE_PRICES = {
    common: { red: 15, blue: 5 },
    rare:   { blue: 25, pale: 8 },
    fused:  { prism: 20, pale: 15 }
  }

  # @brief Goods price, as { sphere color => units }, for goods without a
  # Price in PBS/underground_traders.txt.
  GOOD_PRICE = { red: 10, green: 10 }

  #-----------------------------------------------------------------------------
  # Mission gates
  #-----------------------------------------------------------------------------
  # @brief Mission stage that must be reached before each
  # statue tier can be dug from walls. Fused statues are
  # never dug.
  STATUE_TIER_STAGE = { common: 1, rare: 6 }

  # @brief Mission stage from which traders can stock fused statues
  FUSED_TRADER_STAGE = 7

  # @brief Mission stage from which the digger leader will battle.
  LEADER_STAGE = 6
end
