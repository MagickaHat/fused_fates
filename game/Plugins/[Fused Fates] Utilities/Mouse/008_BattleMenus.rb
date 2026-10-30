#================================================================================================
# Pokémon Fused Fates Utilities/Mouse - 008_BattleMenus.rb
#================================================================================================
# Mouse support for the battle menus: the Fight/Bag/Pokémon/Run command menu, move selection
# (with the Mega Evolution and Shift buttons) and target selection. Hovering a button highlights
# it, a left click chooses it and a right click is Back, as everywhere else.

#==================================================================
# class BattleMenuMouseAdapter
#==================================================================
# @brief Shared logic for the battle menus, which keep their buttons in a private @buttons array.
class BattleMenuMouseAdapter < ScreenAdapter
  # @brief The @sprites key of the menu this adapter drives. Override in subclasses.
  # @return [String]
  def menu_key
    return ""
  end

  # @brief The menu object (Battle::Scene::CommandMenu, FightMenu or TargetMenu).
  # @return [Battle::Scene::MenuBase, nil]
  def menu
    return ivar(:@sprites)&.[](menu_key)
  end

  # @brief Checks whether a menu button can be chosen.
  # @param i [Integer]
  # @return [Boolean]
  def selectable?(i)
    return true
  end

  # @return [Array<Hash>]
  def hotspots
    cw = menu
    return [] if !cw || !cw.visible
    buttons = cw.instance_variable_get(:@buttons)
    return [] if !buttons
    visibility = cw.instance_variable_get(:@visibility) || {}
    spots = []
    buttons.each_with_index do |button, i|
      next if !button || button.disposed? || visibility["button_#{i}"] == false || !selectable?(i)
      n = i
      spots.push({ id: n, rect: button, hover: proc { select(n) }, click: Input::USE })
    end
    return spots
  end

  # @brief Highlights a button. The battle loop notices the change, plays the cursor sound and
  # (for targets) highlights the battler.
  # @param i [Integer]
  def select(i)
    cw = menu
    cw.index = i if cw && cw.index != i
  end
end

#==================================================================
# Command menu
#==================================================================
# @brief Fight / Bag / Pokémon / Run.
class BattleCommandMouseAdapter < BattleMenuMouseAdapter
  # @return [String]
  def menu_key
    return "commandWindow"
  end
end

#==================================================================
# Fight menu
#==================================================================
# @brief Move selection, plus the Mega Evolution (Action) and Shift (Special) buttons.
class BattleFightMouseAdapter < BattleMenuMouseAdapter
  # @return [String]
  def menu_key
    return "fightWindow"
  end

  # @brief Empty move slots can't be chosen.
  # @param i [Integer]
  # @return [Boolean]
  def selectable?(i)
    battler = menu&.battler
    return battler ? !battler.moves[i]&.id.nil? : false
  end

  # @return [Array<Hash>]
  def hotspots
    spots = super
    cw = menu
    return spots if !cw || !cw.visible
    visibility = cw.instance_variable_get(:@visibility) || {}
    mega = cw.instance_variable_get(:@megaButton)
    shift = cw.instance_variable_get(:@shiftButton)
    if mega && !mega.disposed? && visibility["megaButton"]
      spots.push({ id: :mega, rect: mega, click: Input::ACTION })
    end
    if shift && !shift.disposed? && visibility["shiftButton"]
      spots.push({ id: :shift, rect: shift, click: Input::SPECIAL })
    end
    return spots
  end
end

#==================================================================
# Target menu
#==================================================================
# @brief Choosing which battler a move targets. When a move hits several battlers, any target
# button confirms.
class BattleTargetMouseAdapter < BattleMenuMouseAdapter
  # @return [String]
  def menu_key
    return "targetWindow"
  end

  # @brief Only named positions can be targeted.
  # @param i [Integer]
  # @return [Boolean]
  def selectable?(i)
    texts = menu&.instance_variable_get(:@texts)
    return texts ? !texts[i].nil? : true
  end

  # @param i [Integer]
  def select(i)
    return if menu&.mode != 0   # Several targets: the highlight can't move
    super
  end
end

ScreenMouse.wrap(Battle::Scene, BattleCommandMouseAdapter, :pbCommandMenuEx)
ScreenMouse.wrap(Battle::Scene, BattleFightMouseAdapter, :pbFightMenu)
ScreenMouse.wrap(Battle::Scene, BattleTargetMouseAdapter, :pbChooseTarget)
