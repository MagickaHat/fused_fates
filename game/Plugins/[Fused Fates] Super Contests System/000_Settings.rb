#================================================================================================
# Pokémon Fused Fates Super Contests System - 000_Settings.rb
#================================================================================================

#==================================================================
# module ContestSettings
#==================================================================
# @brief Tunable values for conditions, poffins and the contest parts of the
# summary screen.
#
# Data that changes per move, berry or poffin lives in PBS files instead:
#   PBS/contest_moves.txt - each move's contest condition
#   PBS/berry_flavors.txt - each berry's flavors and smoothness
#   PBS/poffins.txt       - the poffin kinds cooking can produce
module ContestSettings
  #-----------------------------------------------------------------------------
  # Conditions
  #-----------------------------------------------------------------------------
  # @brief Highest value a condition (Cool, Beauty, Cute, Smart, Tough) can reach.
  MAX_CONDITION = 255

  # @brief Highest sheen a Pokémon can reach. A Pokémon at this sheen won't
  # eat any more poffins.
  MAX_SHEEN = 255

  # @brief Condition used for moves that aren't listed in PBS/contest_moves.txt.
  DEFAULT_CONDITION = :COOL

  # @brief How much a nature changes the conditions a poffin raises: liked
  # flavors give this much more, disliked flavors this much less.
  NATURE_MULTIPLIER = 0.1

  #-----------------------------------------------------------------------------
  # Poffins
  #-----------------------------------------------------------------------------
  # @brief How many poffins the Poffin Case holds.
  POFFIN_CASE_SIZE = 100

  # @brief Most berries that can go into one poffin. In DPPt every cook adds
  # one berry, so this is the number of cooks at the table.
  MAX_BERRIES_PER_COOK = 4

  # @brief Stands in for the cooking minigame's time bonus. In DPPt flavors
  # are multiplied by 60 / seconds taken; 1.5 matches a well-cooked 40 second
  # batch. 1.0 gives the raw berry values.
  COOK_MULTIPLIER = 1.5

  # @brief Highest flavor value (and so level) a poffin can have.
  MAX_POFFIN_FLAVOR = 100

  # @brief A Foul poffin has this many random flavors, each at FOUL_POFFIN_LEVEL.
  FOUL_POFFIN_FLAVORS = 3
  FOUL_POFFIN_LEVEL   = 2

  # @brief Lowest smoothness a poffin can have.
  MIN_POFFIN_SMOOTHNESS = 1

  # @brief Key item that opens the Poffin Case from the Bag.
  POFFIN_CASE_ITEM = :POFFINCASE

  #-----------------------------------------------------------------------------
  # Summary screen
  #-----------------------------------------------------------------------------
  # @brief Background of the summary's Condition page. If the file doesn't
  # exist, CONDITION_PAGE_FALLBACK_BG is used instead.
  CONDITION_PAGE_BG = "Graphics/UI/Summary/bg_6"

  # @brief Placeholder background used until CONDITION_PAGE_BG is drawn.
  CONDITION_PAGE_FALLBACK_BG = "Graphics/UI/Summary/bg_5"

  # @brief Centre and radius of the condition pentagon on the Condition page.
  PENTAGON_CENTER = [362, 190]
  PENTAGON_RADIUS = 64

  # @brief Optional graphic of condition icons (64x28 cells stacked
  # vertically in GameData::ContestCondition#icon_position order, like
  # Graphics/UI/types). Text labels are drawn while it doesn't exist.
  CONDITION_ICONS = "Graphics/UI/contest_types"

  # @brief Button that switches the summary's Moves page between battle and
  # contest information.
  CONTEST_MOVES_TOGGLE = Input::SPECIAL

  # @brief Game switch that shows the summary's Condition page. 0 means
  # always shown; otherwise the page only appears while the switch is ON.
  CONDITION_PAGE_SWITCH = 0

  # @brief Game switch that lets CONTEST_MOVES_TOGGLE switch the Moves page
  # to contest information. 0 means always allowed; otherwise only while
  # the switch is ON.
  CONTEST_MOVES_SWITCH = 0

  # @brief Whether a feature gated by a game switch is on.
  # @param switch_id [Integer] 0 or less for "always on".
  # @return [Boolean]
  def self.switch_on?(switch_id)
    return true if switch_id <= 0
    return false if !$game_switches
    return $game_switches[switch_id] ? true : false
  end
end
