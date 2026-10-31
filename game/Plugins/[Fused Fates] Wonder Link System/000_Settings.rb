#================================================================================================
# Pokémon Fused Fates Wonder Link System - 000_Settings.rb
#================================================================================================

#==================================================================
# module WonderLinkSettings
#==================================================================
# @brief Central place for every tunable value used by the Wonder Link system.
#
# Wonder Link codes are text strings players copy out of their game and paste into someone
# else's. There are three kinds:
#   - Profile codes: the sharer's party, name and Safari species. Used to battle the sharer,
#     to boost their species in the Safari Zone, for the Underground's Wonder Link rival and
#     to start Mass Outbreaks. Each player's code works once per day for each of these.
#   - Trade codes: one of the sharer's Pokémon, received by trading one of your own.
#   - Gift codes: one of the sharer's Pokémon, received for free.
#   Trade and gift codes can only be redeemed once per save file.
module WonderLinkSettings
  #----------------------------------------------------------------
  # Codes
  #----------------------------------------------------------------
  # Text every code starts with, so pasted text is easy to recognize
  CODE_PREFIX = "WL-"

  # Data format version. Raise it whenever the layout written by WonderLink::Encoder changes;
  # codes from other versions are then rejected with a clear message instead of misread.
  CODE_VERSION = 1

  # Mixed into each code's signature. Codes only work between games with the same salt, and
  # hand-edited codes are rejected. Changing it invalidates every code already shared.
  CODE_SALT = "FusedFates-WonderLink"

  # Longest code (in characters) the decoder will look at. A full party of fusions is ~1500.
  MAX_CODE_LENGTH = 6000

  # Whether players may redeem codes they made themselves (useful for testing)
  ALLOW_OWN_CODES = false

  # Show the code on screen after copying it, so it can be written down where the engine
  # has no clipboard support
  SHOW_CODE_AFTER_EXPORT = false

  #----------------------------------------------------------------
  # Trainer battles
  #----------------------------------------------------------------
  # Trainer type used when the sharer's own trainer type doesn't exist in this game,
  # by the sharer's gender (0 = male, 1 = female, 2 = other). Its BaseMoney sets the prize money.
  FALLBACK_TRAINER_TYPES = {
    0 => :POKEMONTRAINER_Red,
    1 => :POKEMONTRAINER_Leaf,
    2 => :POKEMONTRAINER_Red
  }.freeze

  # Name used when a code has no owner name
  FALLBACK_TRAINER_NAME = "Wonder Trainer"

  # Whether losing a Wonder Link battle is allowed without blacking out
  BATTLE_CAN_LOSE = true

  # Extra prize money, multiplied by the level of the trainer's last Pokémon, on top of the
  # money the trainer type normally pays. 0 for none.
  BONUS_PRIZE_PER_LEVEL = 0

  # Message the generated trainer says when they lose
  TRAINER_LOSE_TEXT = "That was a great Wonder Link battle!"

  #----------------------------------------------------------------
  # Safari Zone
  #----------------------------------------------------------------
  # Species a new save can be given as its Safari species, with relative weights. Rarer species
  # have lower weights, so they are both less likely to be given out and less likely to be
  # boosted. The Safari Zone plugin reads these through WonderLink::Safari.
  SAFARI_POOL = {
    :EXEGGCUTE  => 20, :RHYHORN   => 20, :AIPOM     => 15, :GIRAFARIG  => 15,
    :VENONAT    => 15, :PSYDUCK   => 15, :MARILL    => 15, :BUIZEL     => 12,
    :SLOWPOKE   => 12, :YANMA     => 10, :WOOPER    => 10, :CROAGUNK   => 10,
    :SKORUPI    => 10, :CARNIVINE => 8,  :HERACROSS => 6,  :TAUROS     => 6,
    :PINSIR     => 4,  :SCYTHER   => 4,  :TANGELA   => 4,  :KANGASKHAN => 2,
    :CHANSEY    => 2
  }.freeze

  # How many Safari species each save is given
  SAFARI_SIGNATURE_SIZE = 3

  # Extra weight added to a species for each different code that boosted it today.
  # The Safari Zone plugin passes its base weights through WonderLink::Safari.weights.
  SAFARI_CODE_WEIGHT_BONUS = 30

  # Most codes whose boosts count on the same day (0 = no limit)
  SAFARI_MAX_CODES_PER_DAY = 5

  #----------------------------------------------------------------
  # Underground (optional, needs the Underground System)
  #----------------------------------------------------------------
  # Rival ID recorded in the Underground's daily rival/flag lists for the Wonder Link rival
  UNDERGROUND_RIVAL_ID = :wonder_link

  #----------------------------------------------------------------
  # Mass Outbreaks (optional, needs the Mass Outbreaks System)
  #----------------------------------------------------------------
  # Percent chance that redeeming a profile code starts an outbreak of one of its species
  OUTBREAK_CHANCE = 25

  # Wonder Link outbreaks only happen on maps where the species already appears in the wild.
  # Encounter categories that count (GameData::EncounterType#type).
  OUTBREAK_CATEGORIES = [:land, :cave, :water, :fishing].freeze

  # Wonder Link outbreak entries kept in the save (the oldest inactive ones are dropped)
  OUTBREAK_MAX_ENTRIES = 10
end
