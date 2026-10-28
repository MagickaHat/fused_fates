#================================================================================================
# Pokémon Fused Fates Fusion System - 000_Settings.rb
#================================================================================================

#==================================================================
# module FusionSettings
#==================================================================
# Central place for every tunable value used by the fusion system.
module FusionSettings
  #----------------------------------------------------------------
  # Fusing / Unfusing
  #----------------------------------------------------------------
  # Multiplier applied to the combined EXP of both components when fusing
  FUSION_EXP_BONUS = 1.05

  # Share of the EXP earned while fused that each component receives when unfused
  UNFUSE_EXP_SHARE = 0.5

  # Species that should NOT be allowed to fuse while in an alternate form (form > 0)
  # Permanent forms (like Wormadam, Regional variants, Gastrodon) are omitted so they can still fuse
  RESTRICTED_ALT_FORMS = [
    :ROTOM, :DIALGA, :PALKIA, :GIRATINA, :SHAYMIN, :TORNADUS, :THUNDURUS, :LANDORUS,
    :KYUREM, :KELDEO, :MELOETTA, :HOOPA, :DEOXYS, :NECROZMA, :CALYREX,
    :ZACIAN, :ZAMAZENTA, :CASTFORM, :CHERRIM, :WISHIWASHI, :MINIOR,
    :MIMIKYU, :CRAMORANT, :MORPEKO, :EISCUE, :PALAFIN, :TERAPAGOS
  ].freeze

  # Items that have no effect on fused Pokémon (their normal handlers are wrapped)
  BLOCKED_ITEMS = [
    :ABILITYCAPSULE, :ABILITYPATCH, :ROTOMCATALOG,
    :LONELYMINT, :ADAMANTMINT, :NAUGHTYMINT, :BRAVEMINT, :BOLDMINT, :IMPISHMINT,
    :LAXMINT, :RELAXEDMINT, :MODESTMINT, :MILDMINT, :RASHMINT, :QUIETMINT,
    :CALMMINT, :GENTLEMINT, :CAREFULMINT, :SASSYMINT, :TIMIDMINT, :HASTYMINT,
    :JOLLYMINT, :NAIVEMINT, :SERIOUSMINT
  ].freeze

  #----------------------------------------------------------------
  # Abilities
  #----------------------------------------------------------------
  # Abilities which are too volatile to fuse at all
  BLACKLISTED_ABILITIES = [:WONDERGUARD, :SHADOWTAG, :ARENATRAP].freeze

  # Specific pairs that create broken synergies
  BLACKLISTED_ABILITY_PAIRS = [
    [:HUGEPOWER, :PUREPOWER],
    [:PROTEAN, :LIBERO],
    [:MAGICGUARD, :UNAWARE],
    [:MAGICGUARD, :REGENERATOR]
  ].freeze

  # Abilities with overworld effects (only one component's effect applies on the map)
  OVERWORLD_ABILITIES = [
    :ARENATRAP, :COMPOUNDEYES, :CUTECHARM, :FLASHFIRE, :HARVEST, :HUSTLE,
    :ILLUMINATE, :INTIMIDATE, :KEENEYE, :LIGHTNINGROD, :MAGNETPULL, :NOGUARD,
    :PRESSURE, :QUICKFEET, :SANDVEIL, :SNOWCLOAK, :STATIC, :STENCH,
    :STICKYHOLD, :SUCTIONCUPS, :SUPERLUCK, :SWARM, :SYNCHRONIZE,
    :VITALSPIRIT, :WHITESMOKE, :FLAMEBODY, :MAGMAARMOR, :STEAMENGINE,
    :HONEYGATHER, :PICKUP
  ].freeze

  # When both components boost the same numeric value, the secondary boost is scaled by this
  SECONDARY_BOOST_SCALE = 0.5

  #----------------------------------------------------------------
  # Cries
  #----------------------------------------------------------------
  HEAD_CRY_VOLUME_RATIO = 2 / 3.0
  BODY_CRY_VOLUME_RATIO = 1 / 3.0

  #----------------------------------------------------------------
  # Sprites
  #----------------------------------------------------------------
  # Custom battle sprites: HEAD[_form]_BODY[_form][_back][_shiny].png
  SPRITE_FOLDER = "Graphics/Pokemon/Fusions/"
  # Custom party icons: HEAD[_form]_BODY[_form][_shiny].png
  ICON_FOLDER   = "Graphics/Pokemon/Fusion Icons/"

  # Number of generated fusion graphics kept in memory after nothing displays them
  SPRITE_CACHE_SIZE = 40

  #----------------------------------------------------------------
  # Following Pokémon
  #----------------------------------------------------------------
  # :auto   - Use a custom follower sprite if one exists, otherwise splice the head and body
  # :splice - Always splice the head and body follower sprites
  # :custom - Use a custom follower sprite if one exists, otherwise the head's normal follower sprite
  FOLLOWER_SPRITE_MODE = :auto

  # Fraction of each follower frame (from the top) taken from the head sprite
  FOLLOWER_HEAD_RATIO = 0.5

  # Shift the head's colours towards the body's when splicing follower sprites
  FOLLOWER_HUE_HARMONIZE = true

  # Folders (relative to Graphics/Characters/) holding the species follower sprites
  FOLLOWER_BASE_FOLDER = "Followers"
  # Folders (relative to Graphics/Characters/) holding custom fusion follower sprites
  FOLLOWER_FOLDER       = "Followers/Fusions/"
  FOLLOWER_SHINY_FOLDER = "Followers shiny/Fusions/"
end
