#================================================================================================
# Pokémon Fused Fates Character Customization System - 000_Settings.rb
#================================================================================================

#==================================================================
# module CustomizationSettings
#==================================================================
# @brief Central place for every tunable value used by the character customization system.
module CustomizationSettings
  #----------------------------------------------------------------
  # Graphics
  #----------------------------------------------------------------
  # Folder holding part graphics: ROOT/<context>/<graphic>_<region>[_back].png
  # Regions are numbered from 1 and should be drawn in grayscale; swatches color them.
  ROOT = "Graphics/Characters/Custom/"

  # Draw order, bottom first. "_back" layers of every part are drawn before any front layer.
  SLOT_ORDER = [:Body, :Eyes, :Bottom, :Shoes, :Top, :Hair, :Hat, :Accessory].freeze

  # Slots that can never be left empty
  REQUIRED_SLOTS = [:Body].freeze

  # Parts a new player starts with (slot => part id); missing ids are skipped
  DEFAULT_PARTS = {
    Bottom: :JEANS,
    Shoes:  :SNEAKERS,
    Top:    :TEE,
    Hair:   :HAIR_SHORT
  }.freeze

  # Every sprite the player can be drawn as, in the order the editor's preview cycles through.
  #   :name     - shown in the editor (translated when drawn)
  #   :kind     - :charset (4x4 overworld sheet) or :trainer (trainer card / battle sprite)
  #   :fallback - context to borrow art from when this one has none (nil for the stock sprite)
  CONTEXTS = {
    walk:      { name: "Walking",        kind: :charset, fallback: nil },
    run:       { name: "Running",        kind: :charset, fallback: :walk },
    cycle:     { name: "Cycling",        kind: :charset, fallback: nil },
    surf:      { name: "Surfing",        kind: :charset, fallback: nil },
    dive:      { name: "Diving",         kind: :charset, fallback: :surf },
    fish:      { name: "Fishing",        kind: :charset, fallback: nil },
    surf_fish: { name: "Surf fishing",   kind: :charset, fallback: :fish },
    front:     { name: "Trainer card",   kind: :trainer, fallback: nil },
    back:      { name: "Battle",         kind: :trainer, fallback: nil }
  }.freeze

  # Number of composited player graphics kept in memory after nothing displays them
  CACHE_SIZE = 12

  #----------------------------------------------------------------
  # Colors
  #----------------------------------------------------------------
  # Number of shades in the ramp built from a swatch color
  RAMP_STEPS = 5

  # Pixels darker than this (0-255 brightness) are treated as outlines and never recolored
  OUTLINE_LUMINANCE = 24

  # Allow fine-tuning a swatch with hue/saturation/value offsets
  ALLOW_CUSTOM_COLOR = true

  # Step used by the fine-tune number entry
  CUSTOM_COLOR_STEP = 5

  #----------------------------------------------------------------
  # Editor
  #----------------------------------------------------------------
  # Number of outfits the wardrobe can hold
  MAX_OUTFITS = 8

  # Longest outfit name
  OUTFIT_NAME_LENGTH = 16

  # Number of changes the editor can undo
  HISTORY_LIMIT = 50

  # Only list parts the player has unlocked (debug mode always lists every part)
  ONLY_UNLOCKED = true

  # Zoom applied to the editor's preview sprite
  PREVIEW_ZOOM = 2

  # Frames each walking frame is shown for in the editor's preview
  PREVIEW_FRAME_TIME = 10
end
