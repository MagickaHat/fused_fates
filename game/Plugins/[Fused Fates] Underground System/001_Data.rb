#================================================================================================
# Pokémon Fused Fates Underground System - 001_Data.rb
#================================================================================================

#==================================================================
# module Underground
#==================================================================
module Underground
  #-----------------------------------------------------------------------------
  # Spheres
  #
  #   :name  - shown in menus and messages
  #   :small - [x, y] of the 2x2 sphere cell on Graphics/UI/Mining/items
  #   :large - [x, y] of the 3x3 sphere cell on Graphics/UI/Mining/items
  #-----------------------------------------------------------------------------
  # @brief Sphere colors, in the order they are listed in menus.
  SPHERES = {
    red:   { name: "Red Sphere",   small: [2, 0], large: [13, 0] },
    blue:  { name: "Blue Sphere",  small: [4, 0], large: [16, 0] },
    green: { name: "Green Sphere", small: [0, 0], large: [10, 0] },
    pale:  { name: "Pale Sphere",  small: [8, 0], large: [22, 0] },
    prism: { name: "Prism Sphere", small: [6, 0], large: [19, 0] }
  }

  #-----------------------------------------------------------------------------
  # Mining treasures
  #
  # Spheres buried in walls. Items buried in walls are the base game's
  # MiningGameScene::ITEMS, filtered to items that exist in items.txt.
  #   :color  - sphere color (key of SPHERES)
  #   :large  - whether the 3x3 cell is used
  #   :weight - relative chance to be picked
  #   :units  - range of sphere units the find is worth
  #-----------------------------------------------------------------------------
  # @brief Spheres that can be buried in a wall.
  SPHERE_TREASURES = [
    { color: :red,   large: false, weight: 120, units: 1..4 },
    { color: :blue,  large: false, weight: 120, units: 1..4 },
    { color: :green, large: false, weight: 120, units: 1..4 },
    { color: :pale,  large: false, weight: 50,  units: 1..3 },
    { color: :prism, large: false, weight: 30,  units: 1..3 },
    { color: :red,   large: true,  weight: 40,  units: 5..10 },
    { color: :blue,  large: true,  weight: 40,  units: 5..10 },
    { color: :green, large: true,  weight: 40,  units: 5..10 },
    { color: :pale,  large: true,  weight: 15,  units: 4..8 },
    { color: :prism, large: true,  weight: 8,   units: 4..8 }
  ]

  #-----------------------------------------------------------------------------
  # Statues
  #
  #   :species - the Pokémon shown, and the one whose hideaway spawns it boosts
  #   :body    - for fused statues, the body species (the head is :species)
  #   :tier    - :common and :rare can be dug from walls (see
  #              STATUE_TIER_STAGE). :fused are only given by missions
  #              and traders.
  # Names are built from the species: "Pikachu Statue", "Shinxible Statue"...
  #-----------------------------------------------------------------------------
  # @brief Every statue that can be owned or placed on a pedestal.
  STATUES = {
    # Common
    STATUEPIKACHU:   { species: :PIKACHU,   tier: :common },
    STATUEGEODUDE:   { species: :GEODUDE,   tier: :common },
    STATUEZUBAT:     { species: :ZUBAT,     tier: :common },
    STATUEMACHOP:    { species: :MACHOP,    tier: :common },
    STATUEBRONZOR:   { species: :BRONZOR,   tier: :common },
    STATUEDIGLETT:   { species: :DIGLETT,   tier: :common },
    STATUESHINX:     { species: :SHINX,     tier: :common },
    STATUEBUNEARY:   { species: :BUNEARY,   tier: :common },
    STATUENOSEPASS:  { species: :NOSEPASS,  tier: :common },
    STATUESTUNKY:    { species: :STUNKY,    tier: :common },
    # Rare
    STATUEONIX:      { species: :ONIX,      tier: :rare },
    STATUEGIBLE:     { species: :GIBLE,     tier: :rare },
    STATUERIOLU:     { species: :RIOLU,     tier: :rare },
    STATUELARVITAR:  { species: :LARVITAR,  tier: :rare },
    STATUEBAGON:     { species: :BAGON,     tier: :rare },
    STATUEBELDUM:    { species: :BELDUM,    tier: :rare },
    STATUECRANIDOS:  { species: :CRANIDOS,  tier: :rare },
    STATUESHIELDON:  { species: :SHIELDON,  tier: :rare },
    STATUESABLEYE:   { species: :SABLEYE,   tier: :rare },
    STATUECARBINK:   { species: :CARBINK,   tier: :rare },
    # Fused
    STATUEFUSEDSHINXGIBLE:   { species: :SHINX,   body: :GIBLE,    tier: :fused },
    STATUEFUSEDBUNEARYRIOLU: { species: :BUNEARY, body: :RIOLU,    tier: :fused },
    STATUEFUSEDGEODUDEZUBAT: { species: :GEODUDE, body: :ZUBAT,    tier: :fused },
    STATUEFUSEDONIXDIGLETT:  { species: :ONIX,    body: :DIGLETT,  tier: :fused },
    STATUEFUSEDBAGONBELDUM:  { species: :BAGON,   body: :BELDUM,   tier: :fused },
    STATUEFUSEDSABLEYECARBINK: { species: :SABLEYE, body: :CARBINK, tier: :fused }
  }

  #-----------------------------------------------------------------------------
  # Goods
  #
  #   :name        - shown in menus
  #   :description - shown when the good is chosen
  #   :charset     - character graphic shown on the slot (relative to
  #                  Graphics/Characters), or nil to keep the slot event's own
  #                  graphic. Add charsets here once the art exists.
  #   :use         - what interacting with the placed good does:
  #                  :planter (grow spheres), :pc (Pokémon storage) or nil
  #-----------------------------------------------------------------------------
  # @brief Every good that can be owned or placed in a goods slot.
  GOODS = {
    GOODDESK:      { name: "Desk",       description: "A sturdy wooden desk.", charset: nil },
    GOODCHAIR:     { name: "Chair",      description: "A plain wooden chair.", charset: nil },
    GOODBOOKSHELF: { name: "Bookshelf",  description: "Full of digging guides.", charset: nil },
    GOODCUSHION:   { name: "Cushion",    description: "A soft floor cushion.", charset: nil },
    GOODPLANT:     { name: "Potted Plant", description: "A leafy plant in a clay pot.", charset: nil },
    GOODLAMP:      { name: "Cave Lamp",  description: "Lights up a dim corner.", charset: nil },
    GOODRUG:       { name: "Rug",        description: "A woven rug for the floor.", charset: nil },
    GOODPLANTER:   { name: "Planter",    description: "Bury spheres here and they grow as you walk.",
                     charset: nil, use: :planter },
    GOODPC:        { name: "Base PC",    description: "Reaches your Pokémon storage from your base.",
                     charset: nil, use: :pc }
  }

  #-----------------------------------------------------------------------------
  # Hideaways
  #
  # Keyed by map ID. Each HideawayMon event on that map gets one Pokémon a day.
  #   :name       - shown in the Underground menu
  #   :encounters - [species, weight, min level, max level]
  # The example map IDs below don't exist yet: replace them with your own.
  #-----------------------------------------------------------------------------
  # @brief Hideaway maps and the Pokémon that live in them.
  HIDEAWAYS = {
    101 => {
      name: "Grassland Cave",
      encounters: [
        [:SHINX, 30, 14, 20], [:BUNEARY, 30, 14, 20], [:PIKACHU, 20, 14, 20],
        [:STUNKY, 20, 14, 20], [:RIOLU, 5, 16, 22]
      ]
    },
    102 => {
      name: "Rocky Cave",
      encounters: [
        [:GEODUDE, 30, 18, 24], [:MACHOP, 25, 18, 24], [:NOSEPASS, 20, 18, 24],
        [:ONIX, 15, 20, 26], [:CRANIDOS, 5, 20, 26], [:SHIELDON, 5, 20, 26]
      ]
    },
    103 => {
      name: "Dark Cave",
      encounters: [
        [:ZUBAT, 30, 22, 28], [:BRONZOR, 25, 22, 28], [:SABLEYE, 20, 22, 28],
        [:DIGLETT, 20, 22, 28], [:CARBINK, 5, 24, 30]
      ]
    },
    104 => {
      name: "Deep Cave",
      encounters: [
        [:GIBLE, 25, 30, 36], [:LARVITAR, 25, 30, 36], [:BAGON, 25, 30, 36],
        [:BELDUM, 25, 30, 36]
      ]
    }
  }

  #-----------------------------------------------------------------------------
  # Traders
  #
  #   :name   - shown when talking to them
  #   :wares  - goods and statues they can stock; TRADER_STOCK_SIZE of these
  #             are picked each day
  #   :prices - optional price overrides, by ware ID
  # Statues that aren't priced here use STATUE_PRICES by tier, goods use
  # GOOD_PRICE.
  #-----------------------------------------------------------------------------
  # @brief Underground traders.
  TRADERS = {
    furniture: {
      name: "Furniture Trader",
      wares: [:GOODDESK, :GOODCHAIR, :GOODBOOKSHELF, :GOODCUSHION, :GOODPLANT,
              :GOODLAMP, :GOODRUG, :GOODPLANTER, :GOODPC],
      prices: { GOODPLANTER: { green: 20, pale: 4 }, GOODPC: { blue: 30, prism: 5 } }
    },
    statues: {
      name: "Statue Trader",
      wares: [:STATUEPIKACHU, :STATUEGEODUDE, :STATUEZUBAT, :STATUEMACHOP, :STATUEBRONZOR,
              :STATUEDIGLETT, :STATUESHINX, :STATUEBUNEARY, :STATUEONIX, :STATUEGIBLE,
              :STATUERIOLU, :STATUELARVITAR, :STATUEFUSEDGEODUDEZUBAT,
              :STATUEFUSEDONIXDIGLETT, :STATUEFUSEDBAGONBELDUM, :STATUEFUSEDSABLEYECARBINK]
    }
  }

  # @brief Default statue prices by tier, as { sphere color => units }.
  STATUE_PRICES = {
    common: { red: 15, blue: 5 },
    rare:   { blue: 25, pale: 8 },
    fused:  { prism: 20, pale: 15 }
  }

  # @brief Default goods price, as { sphere color => units }.
  GOOD_PRICE = { red: 10, green: 10 }

  #-----------------------------------------------------------------------------
  # Rival diggers
  #
  #   :name    - shown in messages
  #   :trainer - [trainer type, name, version] from trainers.txt
  #   :leader  - true for the digger leader (mission 6). The leader has no flag.
  #-----------------------------------------------------------------------------
  # @brief Rival diggers who keep bases (and flags) of their own.
  RIVALS = {
    digger_ford:  { name: "Digger Ford",  trainer: [:HIKER, "Digger Ford", 0] },
    digger_ruth:  { name: "Digger Ruth",  trainer: [:RUINMANIAC, "Digger Ruth", 0] },
    digger_boss:  { name: "Digger Boss",  trainer: [:HIKER, "Digger Boss", 0], leader: true }
  }
end
