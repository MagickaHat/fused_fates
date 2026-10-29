#================================================================================================
# Pokémon Fused Fates Super Contests System/Poffin - 002_PoffinCooking.rb
#================================================================================================

#==================================================================
# module PoffinCooking
#==================================================================
# @brief Turns berries into a poffin using the DPPt formula, with no cooking
# minigame (like ORAS's Pokéblock Kit). The minigame's time bonus is replaced
# by ContestSettings::COOK_MULTIPLIER, and there are no burns or spills.
#
# 1. Using the same berry twice gives a Foul poffin (see #foul_poffin).
# 2. Each flavor is the sum of that flavor over every berry...
# 3. ...minus the sum of the flavor that weakens it (Spicy is weakened by
#    Dry, Dry by Sweet, Sweet by Bitter, Bitter by Sour, Sour by Spicy).
# 4. Every flavor loses 1 for each flavor that is now below 0, then
#    flavors below 0 become 0.
# 5. Flavors are multiplied by COOK_MULTIPLIER and capped at MAX_POFFIN_FLAVOR.
#    If none is above 0, the poffin is Foul.
# 6. Smoothness is the berries' average smoothness minus the number of berries.
module PoffinCooking
  module_function

  # @brief Whether a berry can be cooked (it has data in berry_flavors.txt).
  # @param item [Symbol, GameData::Item]
  # @return [Boolean]
  def cookable?(item)
    return GameData::BerryFlavor.exists?(item.is_a?(Symbol) ? item : GameData::Item.get(item).id)
  end

  # @brief Why a set of berries can't be cooked.
  # @param berries [Array<Symbol>]
  # @return [String, nil] nil if they can be cooked.
  def problem_with(berries)
    return _INTL("No berries were chosen.") if berries.empty?
    if berries.length > ContestSettings::MAX_BERRIES_PER_COOK
      return _INTL("Only {1} berries can be cooked at once.", ContestSettings::MAX_BERRIES_PER_COOK)
    end
    berries.each do |berry|
      next if cookable?(berry)
      return _INTL("{1} can't be used for cooking.", GameData::Item.get(berry).name)
    end
    return nil
  end

  # @brief Works out the poffin some berries make, without using them up.
  # @param berries [Array<Symbol>] 1 to MAX_BERRIES_PER_COOK berry IDs.
  # @return [Poffin, nil] nil if the berries can't be cooked.
  def preview(berries)
    return nil if problem_with(berries)
    data = berries.map { |b| GameData::BerryFlavor.get(b) }
    flavor_ids = GameData::Flavor.keys
    smoothness = (data.sum(&:smoothness) / data.length) - data.length
    smoothness = [smoothness, ContestSettings::MIN_POFFIN_SMOOTHNESS].max
    foul = foul_poffin(berries, smoothness)
    return foul if berries.uniq.length != berries.length
    # Sum each flavor, then weaken it by the next one
    sums = flavor_ids.map { |f| data.sum { |d| d.flavor(f) } }
    values = sums.each_with_index.map { |sum, i| sum - sums[(i + 1) % sums.length] }
    negatives = values.count { |v| v < 0 }
    values = values.map { |v| [v - negatives, 0].max }
    values = values.map { |v| [(v * ContestSettings::COOK_MULTIPLIER).floor, ContestSettings::MAX_POFFIN_FLAVOR].min }
    return foul if values.all? { |v| v <= 0 }
    flavors = {}
    flavor_ids.each_with_index { |f, i| flavors[f] = values[i] }
    return Poffin.new(flavors, smoothness)
  end

  # @brief Makes a Foul poffin: as in DPPt, FOUL_POFFIN_FLAVORS random flavors
  # at FOUL_POFFIN_LEVEL. The flavors are picked from the berries used, so
  # the same berries always give the same Foul poffin (and #preview matches
  # #cook).
  # @param berries [Array<Symbol>]
  # @param smoothness [Integer]
  # @return [Poffin]
  def foul_poffin(berries, smoothness)
    rng = Random.new(berries.map(&:to_s).join(",").sum)
    flavors = {}
    GameData::Flavor.keys.sample(ContestSettings::FOUL_POFFIN_FLAVORS, random: rng).each do |f|
      flavors[f] = ContestSettings::FOUL_POFFIN_LEVEL
    end
    return Poffin.new(flavors, smoothness, GameData::PoffinType.foul_type&.id)
  end

  # @brief Cooks a poffin from berries in the Bag, using them up and putting
  # the poffin in the Poffin Case.
  # @param berries [Array<Symbol>]
  # @return [Poffin, nil] nil if nothing was cooked (bad berries, missing
  #   from the Bag, or the case is full).
  def cook(berries)
    return nil if PoffinCase.instance.full?
    counts = Hash.new(0)
    berries.each { |b| counts[b] += 1 }
    return nil if counts.any? { |berry, qty| !$bag.has?(berry, qty) }
    poffin = preview(berries)
    return nil if !poffin
    berries.each { |b| $bag.remove(b) }
    PoffinCase.instance.add(poffin)
    $stats.poffins_cooked += 1 if $stats
    return poffin
  end
end

#==================================================================
# class GameStats
#==================================================================
class GameStats
  # @brief How many poffins the player has cooked. Created on first use so
  # older saves load.
  # @return [Integer]
  def poffins_cooked
    return @poffins_cooked || 0
  end

  # @param value [Integer]
  def poffins_cooked=(value)
    @poffins_cooked = value
  end

  # @brief How many poffins the player has fed to Pokémon.
  # @return [Integer]
  def poffins_fed
    return @poffins_fed || 0
  end

  # @param value [Integer]
  def poffins_fed=(value)
    @poffins_fed = value
  end
end

#==================================================================
# Cooking screen
#==================================================================
# @brief Lets the player choose berries from the Bag and cook a poffin with
# them. Call it from an event (e.g. a Poffin House table). A plain menu for
# now; the visual cooking screen will replace it.
# @param max_berries [Integer] How many berries the player may add.
# @return [Poffin, nil] The poffin cooked, or nil if cancelled.
def pbPoffinCookingScreen(max_berries = ContestSettings::MAX_BERRIES_PER_COOK)
  if PoffinCase.instance.full?
    pbMessage(_INTL("The Poffin Case is full! Make room before cooking."))
    return nil
  end
  berries = []
  loop do
    cmds = []
    cmds.push([:add, _INTL("Add a berry")]) if berries.length < max_berries
    cmds.push([:remove, _INTL("Remove last berry")]) if !berries.empty?
    cmds.push([:cook, _INTL("Cook")]) if !berries.empty?
    cmds.push([:cancel, _INTL("Cancel")])
    text = berries.empty? ? _INTL("Which berries will you cook?") :
                            _INTL("Berries: {1}", berries.map { |b| GameData::Item.get(b).name }.join(", "))
    choice = cmds[pbMessage(text, cmds.map { |c| c[1] }, cmds.length)][0]
    case choice
    when :add
      berry = nil
      pbFadeOutIn do
        scene = PokemonBag_Scene.new
        screen = PokemonBagScreen.new(scene, $bag)
        berry = screen.pbChooseItemScreen(proc { |item|
          next false if !PoffinCooking.cookable?(item)
          next $bag.quantity(item) > berries.count(item)
        })
      end
      berries.push(berry) if berry
    when :remove
      berries.pop
    when :cook
      poffin = PoffinCooking.preview(berries)
      if !poffin
        pbMessage(PoffinCooking.problem_with(berries))
        next
      end
      next if !pbConfirmMessage(_INTL("Cook these berries?"))
      poffin = PoffinCooking.cook(berries)
      if poffin
        pbMessage(_INTL("\\me[Item get]A {1} was made!\\wtnp[30]", poffin.name))
        pbMessage(_INTL("Level {1}, smoothness {2}.\n{3}", poffin.level, poffin.smoothness, poffin.flavor_lines.join(", ")))
        pbMessage(_INTL("The poffin was put in the Poffin Case."))
      else
        pbMessage(_INTL("The poffin couldn't be made."))
      end
      return poffin
    else
      return nil
    end
  end
end
