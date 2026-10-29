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
  # Mouse
  #----------------------------------------------------------------
  # Master switch for every mouse UI adapter; false makes the game keyboard-only again
  MOUSE_ENABLED = true

  # A left click anywhere in the game window advances dialogue (overworld and battle)
  MOUSE_DIALOGUE = true

  # Hovering an option in a list window (choices, pause menu, bag, mart...) highlights it
  # and a left click picks it
  MOUSE_MENUS = true

  # A right click acts as the Back button everywhere (on the map it opens the pause menu)
  MOUSE_RIGHT_CLICK_BACK = true
end
