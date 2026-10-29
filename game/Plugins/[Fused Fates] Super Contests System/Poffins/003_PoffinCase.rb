#================================================================================================
# Pokémon Fused Fates Super Contests System/Poffin - 003_PoffinCase.rb
#================================================================================================

#==================================================================
# class PoffinCase
#==================================================================
# @brief The player's poffins. Saved with $PokemonGlobal and created on first
# use, so saves made before the contest plugin load fine.
class PoffinCase
  # @brief The poffins in the case, in the order they are listed.
  attr_reader :poffins

  # @brief Ways the case can be sorted, with the key each one sorts by.
  SORTS = {
    :level      => proc { |p| [-p.level, -p.smoothness] },
    :smoothness => proc { |p| [-p.smoothness, -p.level] },
    :flavor     => proc { |p| [GameData::Flavor.keys.index(p.main_flavors.first) || 99, -p.level] }
  }

  # @brief The player's Poffin Case.
  # @return [PoffinCase]
  def self.instance
    $PokemonGlobal.poffin_case ||= PoffinCase.new
    return $PokemonGlobal.poffin_case
  end

  # @brief Creates an empty case.
  def initialize
    @poffins = []
  end

  # @brief How many poffins are in the case.
  # @return [Integer]
  def length
    return @poffins.length
  end

  # @brief Whether the case has no poffins.
  # @return [Boolean]
  def empty?
    return @poffins.empty?
  end

  # @brief Whether the case can't hold any more poffins.
  # @return [Boolean]
  def full?
    return @poffins.length >= ContestSettings::POFFIN_CASE_SIZE
  end

  # @brief The poffin at a position in the list.
  # @param index [Integer]
  # @return [Poffin, nil]
  def [](index)
    return @poffins[index]
  end

  # @brief Puts a poffin in the case.
  # @param poffin [Poffin]
  # @return [Boolean] false if the case is full.
  def add(poffin)
    return false if full?
    @poffins.push(poffin)
    return true
  end

  # @brief Takes a poffin out of the case.
  # @param poffin [Poffin, Integer] The poffin, or its position in the list.
  # @return [Poffin, nil] The poffin removed.
  def remove(poffin)
    return @poffins.delete_at(poffin) if poffin.is_a?(Integer)
    index = @poffins.index { |p| p.equal?(poffin) }
    return index ? @poffins.delete_at(index) : nil
  end

  # @brief Empties the case.
  def clear
    @poffins.clear
  end

  # @brief Sorts the case.
  # @param key [Symbol] A key of SORTS.
  def sort!(key)
    sorter = SORTS[key]
    return if !sorter
    @poffins = @poffins.each_with_index.sort_by { |p, i| sorter.call(p) + [i] }.map(&:first)
  end

  # @brief Feeds a poffin from the case to a Pokémon, removing it from the case.
  # @param poffin [Poffin, Integer]
  # @param pkmn [Pokemon]
  # @return [Hash, nil] The gains (see Pokemon#poffin_gains), or nil if the
  #   Pokémon wouldn't eat it.
  def feed(poffin, pkmn)
    poffin = @poffins[poffin] if poffin.is_a?(Integer)
    return nil if !poffin
    gains = pkmn.feed_poffin(poffin)
    return nil if !gains
    remove(poffin)
    $stats.poffins_fed += 1 if $stats
    return gains
  end
end

#==================================================================
# class PokemonGlobalMetadata
#==================================================================
class PokemonGlobalMetadata
  # @brief The player's Poffin Case. Use PoffinCase.instance instead, which
  # creates it on first use.
  attr_accessor :poffin_case
end

#==================================================================
# Poffin Case screen
#==================================================================
# @brief Describes what a poffin did to a Pokémon.
# @param pkmn [Pokemon]
# @param gains [Hash] As returned by Pokemon#feed_poffin.
# @return [String]
def pbPoffinGainsText(pkmn, gains)
  parts = []
  gains[:conditions].each do |condition, gain|
    next if gain <= 0
    parts.push(_INTL("{1} +{2}", GameData::ContestCondition.get(condition).name, gain))
  end
  parts.push(_INTL("Sheen +{1}", gains[:sheen])) if gains[:sheen] > 0
  return _INTL("{1}'s condition didn't change.", pkmn.name) if parts.empty?
  return _INTL("{1}: {2}", pkmn.name, parts.join(", "))
end

# @brief Asks the player which party Pokémon to feed a poffin to.
# @param poffin [Poffin]
# @return [Pokemon, nil]
def pbChoosePokemonForPoffin(poffin)
  chosen = -1
  pbFadeOutIn do
    scene = PokemonParty_Scene.new
    screen = PokemonPartyScreen.new(scene, $player.party)
    chosen = screen.pbChooseAblePokemon(proc { |pkmn| pkmn.can_eat_poffin?(poffin) })
  end
  return (chosen >= 0) ? $player.party[chosen] : nil
end

# @brief Feeds a poffin from the case to a party Pokémon the player chooses,
# with messages.
# @param poffin [Poffin]
# @return [Boolean] Whether it was eaten.
def pbFeedPoffin(poffin)
  pkmn = pbChoosePokemonForPoffin(poffin)
  return false if !pkmn
  if pkmn.sheen_maxed?
    pbMessage(_INTL("{1} won't eat any more...", pkmn.name))
    return false
  end
  liked    = pkmn.liked_flavor
  disliked = pkmn.disliked_flavor
  main     = poffin.main_flavors.first
  gains = PoffinCase.instance.feed(poffin, pkmn)
  return false if !gains
  if liked && main == liked.id
    pbMessage(_INTL("{1} happily ate the {2}!", pkmn.name, poffin.name))
  elsif disliked && main == disliked.id
    pbMessage(_INTL("{1} disdainfully ate the {2}.", pkmn.name, poffin.name))
  else
    pbMessage(_INTL("{1} ate the {2}.", pkmn.name, poffin.name))
  end
  pbMessage(pbPoffinGainsText(pkmn, gains))
  return true
end

# @brief Opens the Poffin Case. A plain menu for now; the visual Poffin Case
# will replace it.
def pbPoffinCaseScreen
  poffin_case = PoffinCase.instance
  index = 0
  loop do
    if poffin_case.empty?
      pbMessage(_INTL("The Poffin Case is empty."))
      return
    end
    cmds = poffin_case.poffins.map { |p| p.summary }
    cmds.push(_INTL("Sort"))
    cmds.push(_INTL("Close"))
    index = index.clamp(0, cmds.length - 1)
    choice = pbMessage(_INTL("Poffin Case ({1}/{2})", poffin_case.length, ContestSettings::POFFIN_CASE_SIZE),
                       cmds, cmds.length, nil, index)
    break if choice == cmds.length - 1
    if choice == cmds.length - 2
      sorts = [[:level, _INTL("By level")], [:smoothness, _INTL("By smoothness")],
               [:flavor, _INTL("By flavor")], [nil, _INTL("Cancel")]]
      sort = sorts[pbMessage(_INTL("Sort the poffins how?"), sorts.map { |s| s[1] }, sorts.length)][0]
      poffin_case.sort!(sort) if sort
      next
    end
    index = choice
    poffin = poffin_case[choice]
    actions = [[:feed, _INTL("Feed")], [:check, _INTL("Check")], [:toss, _INTL("Throw away")], [:cancel, _INTL("Cancel")]]
    action = actions[pbMessage(_INTL("{1}\nLevel {2}, smoothness {3}.", poffin.name, poffin.level, poffin.smoothness),
                               actions.map { |a| a[1] }, actions.length)][0]
    case action
    when :feed
      pbFeedPoffin(poffin)
    when :check
      lines = poffin.flavor_lines
      lines = [_INTL("It has no flavor.")] if lines.empty?
      pbMessage(_INTL("{1}\n{2}", poffin.name, lines.join(", ")))
      pbMessage(poffin.description) if !nil_or_empty?(poffin.description)
    when :toss
      if pbConfirmMessage(_INTL("Throw away the {1}?", poffin.name))
        poffin_case.remove(poffin)
        pbMessage(_INTL("The {1} was thrown away.", poffin.name))
      end
    end
  end
end

#==================================================================
# Poffin Case item
#==================================================================
# Also used from the Bag, which falls back to UseInField handlers.
ItemHandlers::UseInField.add(ContestSettings::POFFIN_CASE_ITEM, proc { |item|
  pbPoffinCaseScreen
  next true
})
