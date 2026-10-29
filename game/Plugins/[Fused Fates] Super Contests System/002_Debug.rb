#================================================================================================
# Pokémon Fused Fates Super Contests System - 002_Debug.rb
#================================================================================================

#==================================================================
# module ContestDebug
#==================================================================
# @brief Shared helpers for the Super Contests debug menu commands.
module ContestDebug
  module_function

  # @brief Makes a random poffin from 1 to MAX_BERRIES_PER_COOK different
  # cookable berries, without touching the Bag.
  # @return [Poffin, nil] nil if no berries have flavor data.
  def random_poffin
    berries = GameData::BerryFlavor.keys
    return nil if berries.empty?
    count = rand(1..[ContestSettings::MAX_BERRIES_PER_COOK, berries.length].min)
    return PoffinCooking.preview(berries.sample(count))
  end

  # @brief Lets the debugger pick berries (from every cookable berry, not the
  # Bag) and shows the poffin they would make.
  # @return [Array] [berries, poffin], or nil if cancelled.
  def choose_berries
    all = GameData::BerryFlavor.keys
    if all.empty?
      pbMessage(_INTL("No berries have flavor data. Check PBS/berry_flavors.txt."))
      return nil
    end
    names = all.map { |b| GameData::Item.get(b).name }
    berries = []
    loop do
      text = berries.empty? ? _INTL("Choose berries to cook.") :
                              _INTL("Berries: {1}", berries.map { |b| GameData::Item.get(b).name }.join(", "))
      cmds = []
      cmds.push(:add) if berries.length < ContestSettings::MAX_BERRIES_PER_COOK
      cmds.push(:done) if !berries.empty?
      cmds.push(:cancel)
      labels = { add: _INTL("Add a berry"), done: _INTL("Done"), cancel: _INTL("Cancel") }
      choice = cmds[pbMessage(text, cmds.map { |c| labels[c] }, cmds.length)]
      case choice
      when :add
        idx = pbMessage(_INTL("Add which berry?"), names + [_INTL("Cancel")], names.length + 1)
        berries.push(all[idx]) if idx < names.length
      when :done
        return [berries, PoffinCooking.preview(berries)]
      else
        return nil
      end
    end
  end

  # @brief Lines describing a poffin, for messages.
  # @param poffin [Poffin]
  # @return [String]
  def poffin_text(poffin)
    flavors = poffin.flavor_lines
    flavors = [_INTL("no flavor")] if flavors.empty?
    return _INTL("{1}: level {2}, smoothness {3}.\n{4}", poffin.name, poffin.level, poffin.smoothness, flavors.join(", "))
  end
end

#==================================================================
# Debug menu
#==================================================================
MenuHandlers.add(:debug_menu, :contests_menu, {
  "name"        => _INTL("Super Contests..."),
  "parent"      => :main,
  "description" => _INTL("Poffins, the Poffin Case and contest PBS data."),
  "always_show" => false
})

MenuHandlers.add(:debug_menu, :contests_preview_poffin, {
  "name"        => _INTL("Preview a poffin"),
  "parent"      => :contests_menu,
  "description" => _INTL("Pick berries and see the poffin they would make. Nothing is used up."),
  "effect"      => proc {
    ret = ContestDebug.choose_berries
    next if !ret
    poffin = ret[1]
    if !poffin
      pbMessage(PoffinCooking.problem_with(ret[0]))
      next
    end
    pbMessage(ContestDebug.poffin_text(poffin))
    if pbConfirmMessage(_INTL("Put this poffin in the Poffin Case?"))
      if PoffinCase.instance.add(poffin)
        pbMessage(_INTL("The {1} was put in the Poffin Case.", poffin.name))
      else
        pbMessage(_INTL("The Poffin Case is full."))
      end
    end
  }
})

MenuHandlers.add(:debug_menu, :contests_cook, {
  "name"        => _INTL("Cook poffins"),
  "parent"      => :contests_menu,
  "description" => _INTL("Open the cooking screen, using berries from the Bag."),
  "effect"      => proc {
    pbPoffinCookingScreen
  }
})

MenuHandlers.add(:debug_menu, :contests_poffin_case, {
  "name"        => _INTL("Open the Poffin Case"),
  "parent"      => :contests_menu,
  "description" => _INTL("Open the Poffin Case to check, feed or throw away poffins."),
  "effect"      => proc {
    pbPoffinCaseScreen
  }
})

MenuHandlers.add(:debug_menu, :contests_fill_case, {
  "name"        => _INTL("Fill the Poffin Case"),
  "parent"      => :contests_menu,
  "description" => _INTL("Fill the Poffin Case with poffins made from random berries."),
  "effect"      => proc {
    poffin_case = PoffinCase.instance
    added = 0
    until poffin_case.full?
      poffin = ContestDebug.random_poffin
      break if !poffin
      poffin_case.add(poffin)
      added += 1
    end
    pbMessage(_INTL("Added {1} poffins.", added))
  }
})

MenuHandlers.add(:debug_menu, :contests_clear_case, {
  "name"        => _INTL("Empty the Poffin Case"),
  "parent"      => :contests_menu,
  "description" => _INTL("Throw away every poffin in the Poffin Case."),
  "effect"      => proc {
    if pbConfirmMessage(_INTL("Throw away all {1} poffins?", PoffinCase.instance.length))
      PoffinCase.instance.clear
      pbMessage(_INTL("The Poffin Case is empty."))
    end
  }
})

MenuHandlers.add(:debug_menu, :contests_reload_pbs, {
  "name"        => _INTL("Reload contest PBS files"),
  "parent"      => :contests_menu,
  "description" => _INTL("Recompile contest_effects.txt, contest_moves.txt, berry_flavors.txt and poffins.txt so edits apply without restarting."),
  "effect"      => proc {
    ok = DevLog.guard("Contests: compiling PBS files failed", false) do
      Compiler.compile_contest_data
      next true
    end
    if ok
      pbMessage(_INTL("The contest PBS files were recompiled."))
    else
      pbMessage(_INTL("Compiling failed. See the console for the error."))
    end
  }
})

#==================================================================
# Pokémon debug menu
#==================================================================
MenuHandlers.add(:pokemon_debug_menu, :set_all_conditions, {
  "name"   => _INTL("Set all conditions"),
  "parent" => :contest_stats,
  "effect" => proc { |pkmn, pkmnid, heldpoke, settingUpBattle, screen|
    params = ChooseNumberParams.new
    params.setRange(0, ContestSettings::MAX_CONDITION)
    params.setDefaultValue(0)
    value = pbMessageChooseNumber(
      _INTL("Set all of the Pokémon's conditions (max. {1}).", ContestSettings::MAX_CONDITION), params
    ) { screen.pbUpdate }
    GameData::ContestCondition.each { |c| pkmn.set_condition(c.id, value) }
    screen.pbRefreshSingle(pkmnid)
    next false
  }
})

MenuHandlers.add(:pokemon_debug_menu, :reset_conditions, {
  "name"   => _INTL("Reset conditions and sheen"),
  "parent" => :contest_stats,
  "effect" => proc { |pkmn, pkmnid, heldpoke, settingUpBattle, screen|
    pkmn.reset_conditions
    screen.pbDisplay(_INTL("{1}'s conditions and sheen were reset.", pkmn.name))
    screen.pbRefreshSingle(pkmnid)
    next false
  }
})

MenuHandlers.add(:pokemon_debug_menu, :feed_random_poffin, {
  "name"   => _INTL("Feed a random poffin"),
  "parent" => :contest_stats,
  "effect" => proc { |pkmn, pkmnid, heldpoke, settingUpBattle, screen|
    poffin = ContestDebug.random_poffin
    if !poffin
      screen.pbDisplay(_INTL("No berries have flavor data."))
      next false
    end
    gains = pkmn.feed_poffin(poffin)
    if gains
      screen.pbDisplay(_INTL("Fed a {1} (level {2}).", poffin.name, poffin.level))
      screen.pbDisplay(pbPoffinGainsText(pkmn, gains))
    else
      screen.pbDisplay(_INTL("{1} won't eat any more...", pkmn.name))
    end
    screen.pbRefreshSingle(pkmnid)
    next false
  }
})
