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
    Body:   :BODY,
    Eyes:   :EYES,
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

  # Graphics cut out of another context's composite, so they need no art of their own.
  #   :name   - shown in the editor (translated when drawn)
  #   :source - context whose composite is cropped
  DERIVED_CONTEXTS = {
    mugshot:  { name: "Mugshot",  source: :front },
    map_icon: { name: "Map icon", source: :walk }
  }.freeze

  # Largest size (in pixels) of the square mugshot cropped from the top of the front sprite
  MUGSHOT_SIZE = 64

  # Size (in pixels) of the square town map icon cropped from the walking sprite's head;
  # matches the stock Graphics/UI/Town Map/player_*.png icons
  MAP_ICON_SIZE = 32

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

  # Swatch palettes: a slot listed here only offers swatches carrying that flag in
  # player_colors.txt (e.g. skin tones for the body). Slots not listed offer every swatch that
  # carries none of these flags, so skin tones never show up as shirt colors.
  SWATCH_PALETTES = {
    Body: "Skin"
  }.freeze

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

  # Zoom applied to the editor's preview sprite, by context kind (:derived is the mugshot and map icon)
  PREVIEW_ZOOM = {
    charset: 2,
    trainer: 1,
    derived: 2
  }.freeze

  # Frames each walking frame is shown for in the editor's preview
  PREVIEW_FRAME_TIME = 10

  #----------------------------------------------------------------
  # Editor layout and art
  #----------------------------------------------------------------
  # Sizes (in pixels) of the editor's panels. The command list runs down the left side; the
  # header (title and money), the preview and the info panel share the rest, top to bottom.
  # The header is only shown when the session has a title or prices.
  EDITOR_LAYOUT = {
    list_width:    224,
    header_height: 32,
    info_height:   112
  }.freeze

  # Optional art for the editor, looked up in UI_FOLDER. Any file that doesn't exist is replaced
  # by flat colors, so the editor works without art; drop a PNG in to restyle a panel.
  #   :background - whole screen, drawn behind everything
  #   :header     - stretched to the header panel
  #   :preview    - stretched to the preview panel
  #   :info       - stretched to the info panel
  UI_FOLDER = "Graphics/UI/Customization/"
  UI_GRAPHICS = {
    background: "bg",
    header:     "header",
    preview:    "preview",
    info:       "info"
  }.freeze

  #----------------------------------------------------------------
  # Editor presets (see CustomizationConfig)
  #----------------------------------------------------------------
  # Slots offered when the player creates their look in the intro
  INTRO_SLOTS = [:Body, :Eyes, :Hair].freeze

  # Commands offered in the intro
  INTRO_COMMANDS = [:undo, :redo, :revert, :done].freeze

  # Commands offered by boutiques and stylists
  SERVICE_COMMANDS = [:undo, :redo, :revert, :done].freeze

  # Preview context shown first by the intro and boutiques (the full-body trainer sprite)
  SHOWCASE_CONTEXT = :front

  # Sound effect played when the player pays a boutique or stylist
  PAY_SE = "Mart buy item"
end
