#================================================================================================
# Pokémon Fused Fates Utilities - 000_Settings.rb
#================================================================================================

#==================================================================
# module UtilitySettings
#==================================================================
# @brief Central place for every tunable value used by the utilities plugin.
module UtilitySettings
  #----------------------------------------------------------------
  # Logging
  #----------------------------------------------------------------
  # Lowest level DevLog prints: :debug, :info, :warn, :error or :none
  LOG_LEVEL = :info

  # Also append log messages to LOG_FILE (works outside debug mode too)
  LOG_TO_FILE = false
  LOG_FILE    = "Debug/utilities.log"

  # Folder DevLog/SpriteUtils.dump writes PNG dumps of bitmaps to
  DUMP_FOLDER = "Debug/Bitmaps/"

  #----------------------------------------------------------------
  # Recoloring
  #----------------------------------------------------------------
  # Number of recolored bitmaps kept in memory after nothing displays them
  RECOLOR_CACHE_SIZE = 40

  # Degrees Ramp.generate rotates the darkest/lightest step toward cool shadows/warm highlights
  RAMP_HUE_SHIFT = 20

  # Default largest RGB distance PaletteSwap.apply_nearest will snap a color across
  PALETTE_MATCH_TOLERANCE = 48

  #----------------------------------------------------------------
  # Events
  #----------------------------------------------------------------
  # Most tiles EventPathfinder looks at before deciding a target can't be reached
  PATHFIND_MAX_NODES = 2000

  # Times EventUtils.walk_to works out a new path when something blocks the way
  PATHFIND_RETRIES = 3

  # Seconds EventUtils.walk_to waits for a blocker to move before working out a new path
  PATHFIND_RETRY_WAIT = 0.25
end
