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

  # Sprite-drawn screens (party, summary, PC boxes, battle menus, Pokédex...) react to the mouse
  MOUSE_SCREENS = true

  # Smallest number of seconds between two mouse wheel steps in lists. Extra wheel or trackpad
  # movement in between is dropped rather than queued, so lists never run away.
  MOUSE_WHEEL_DELAY = 0.1

  # Smallest number of seconds between wheel steps that change a whole page or Pokémon
  MOUSE_WHEEL_PAGE_DELAY = 0.25

  # Reverses the wheel direction (for players used to "natural" scrolling)
  MOUSE_WHEEL_INVERT = false

  # Holding the left button on a scroll arrow or step button repeats it: first after
  # MOUSE_HOLD_DELAY seconds, then every MOUSE_HOLD_RATE seconds. This is how players without
  # a wheel (e.g. trackpads) scroll; the keyboard always keeps working as well.
  MOUSE_HOLD_DELAY = 0.4
  MOUSE_HOLD_RATE  = 0.15

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
