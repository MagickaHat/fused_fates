#================================================================================================
# Pokémon Fused Fates Character Customization System - 010_EditorScreen.rb
#================================================================================================

#==================================================================
# class CharacterEditor_Screen
#==================================================================
# @brief The character editor's logic: what each command does to the appearance, and what
# leaving costs. What is offered follows the session's CustomizationConfig.
class CharacterEditor_Screen
  # Longest share code the player can type or paste
  SHARE_CODE_LENGTH = 500

  # @brief Creates the editor.
  # @param scene [CharacterEditor_Scene]
  # @param appearance [PlayerAppearance] Edited in place.
  # @param config [CustomizationConfig, Boolean] The session's rules. A Boolean is read as the
  #   old allow_cancel argument and gives the mirror's rules.
  def initialize(scene, appearance, config = CustomizationConfig.mirror)
    config = CustomizationConfig.new(allow_cancel: config) if [true, false].include?(config)
    @scene      = scene
    @appearance = appearance
    @config     = config
    @history    = AppearanceHistory.new(appearance)
  end

  # @brief Runs the editor until the player leaves.
  # @return [Boolean] Whether the changes should be kept (and, in paid sessions, were paid for).
  def pbStartScreen
    @scene.pbStartScene(@appearance, @config)
    refresh
    keep = false
    last_index = nil
    loop do
      @scene.pbUpdate
      win = @scene.slot_window
      if win.index != last_index
        last_index = win.index
        show_row_info(last_index)
      end
      next if @scene.handle_preview_input
      if Input.trigger?(Input::USE)
        pbPlayDecisionSE
        slot = slots[win.index]
        if slot
          edit_slot(slot)
        else
          case commands[win.index - slots.length]
          when :undo    then message(_INTL("There's nothing to undo.")) if !changed { @history.undo }
          when :redo    then message(_INTL("There's nothing to redo.")) if !changed { @history.redo }
          when :revert
            if @history.dirty? && confirm(_INTL("Undo every change made since opening the editor?"))
              changed { @history.revert_all }
            end
          when :outfits then outfits_menu
          when :share   then share_menu
          when :done
            result = finish
            if !result.nil?
              keep = result
              break
            end
          end
        end
        last_index = nil
      elsif Input.trigger?(Input::BACK)
        pbPlayCancelSE
        result = confirm_exit
        if !result.nil?
          keep = result
          break
        end
        last_index = nil
      end
    end
    @scene.pbEndScene
    return keep
  end

  private

  #----------------------------------------------------------------
  # Main list
  #----------------------------------------------------------------
  # @return [Array<Symbol>] Slots the player may change in this session.
  def slots
    return @config.slots
  end

  # @return [Array<Symbol>] Commands listed under the slots.
  def commands
    return @config.commands
  end

  # @param command [Symbol]
  # @return [String] The command's row in the list.
  def command_name(command)
    case command
    when :undo    then return _INTL("Undo")
    when :redo    then return _INTL("Redo")
    when :revert  then return _INTL("Revert all")
    when :outfits then return _INTL("Outfits...")
    when :share   then return _INTL("Share code...")
    when :done    then return @config.pricing == :purchase ? _INTL("Checkout") : _INTL("Done")
    end
    return command.to_s
  end

  # @brief Redraws the command list and the preview after a change.
  def refresh
    rows = slots.map { |slot| _INTL("{1}: {2}", slot_name(slot), slot_value(slot)) }
    rows += commands.map { |command| command_name(command) }
    @scene.set_rows(rows)
    @scene.refresh_preview
    show_row_info(@scene.slot_window.index)
  end

  # @brief Runs a change (made through the history) and redraws everything.
  # @yieldreturn [Boolean] Whether the appearance changed.
  # @return [Boolean] The block's result.
  def changed
    ret = yield
    refresh
    return ret
  end

  # @param slot [Symbol]
  # @return [String]
  def slot_name(slot)
    return _INTL(slot.to_s)
  end

  # @brief What a slot holds, as shown in the list (slot occupancy included).
  # @param slot [Symbol]
  # @return [String]
  def slot_value(slot)
    part = @appearance.part_for(slot)
    return part.name if part
    occupant = @appearance.occupant(slot)
    return _INTL("({1})", occupant.name) if occupant
    return _INTL("None")
  end

  # @brief Describes the selected row in the info panel.
  # @param index [Integer]
  def show_row_info(index)
    slot = slots[index]
    if !slot
      @scene.show_info(command_info_lines(commands[index - slots.length]))
      return
    end
    @scene.show_info(slot_info_lines(slot))
  end

  # @param command [Symbol]
  # @return [Array] Info panel lines for a command row.
  def command_info_lines(command)
    case command
    when :undo    then return [_INTL("Undo the last change.")]
    when :redo    then return [_INTL("Redo what you undid.")]
    when :revert  then return [_INTL("Back to how you started.")]
    when :outfits then return [_INTL("Saved outfits: {1}/{2}", $player.outfits.length, CustomizationSettings::MAX_OUTFITS)]
    when :share   then return [_INTL("Show or enter a look code.")]
    when :done
      lines = [_INTL("Finish and keep changes.")]
      case @config.pricing
      when :purchase
        total = @config.unpaid_parts(@appearance).sum(&:price)
        lines = [_INTL("Pay for what you're wearing.")]
        lines.push([_INTL("Total: ${1}", total.to_s_formatted), nil, EditorStyle::PRICE_COLOR]) if total > 0
      when :fee
        lines.push([_INTL("Fee: ${1}", @config.fee.to_s_formatted), nil, EditorStyle::PRICE_COLOR]) if @history.dirty?
      end
      return lines
    end
    return [""]
  end

  # @brief Lines describing a slot: what fills it, what it hides, its price and each region's color.
  # @param slot [Symbol]
  # @param appearance [PlayerAppearance]
  # @return [Array]
  def slot_info_lines(slot, appearance = @appearance)
    part = appearance.part_for(slot)
    if !part
      occupant = appearance.occupant(slot)
      return [_INTL("Covered by {1}.", occupant.name)] if occupant
      return [_INTL("Nothing is worn here.")]
    end
    lines = []
    lines.push(price_line(part)) if @config.pricing == :purchase
    hidden = appearance.hidden_slots
    lines.push(_INTL("Hidden by another part.")) if hidden.include?(slot)
    covers = part.occupies - [slot]
    lines.push(_INTL("Also covers: {1}", covers.map { |s| slot_name(s) }.join(", "))) if !covers.empty?
    (1..part.color_slots).each do |region|
      color = appearance.color_for(slot, region)
      text = _INTL("{1}: {2}", part.region_name(region), color_name(color))
      text += _INTL(" (linked)") if appearance.linked?([slot, region])
      lines.push([text, color])
    end
    return lines
  end

  # @param part [GameData::PlayerPart]
  # @return [Array] An info panel line with the part's price, or that it's already owned.
  def price_line(part)
    return _INTL("You own this.") if !@config.for_sale?(part)
    return [_INTL("Price: ${1}", part.price.to_s_formatted), nil, EditorStyle::PRICE_COLOR]
  end

  # @param color [RegionColor]
  # @return [String] The swatch's label, marked if fine-tuned.
  def color_name(color)
    swatch = color.swatch_data
    name = swatch ? swatch.name : _INTL("No color")
    name += "*" if !color.adjust.identity?
    return name
  end

  #----------------------------------------------------------------
  # Editing a slot
  #----------------------------------------------------------------
  # @brief Shows what can be done to a slot and does it.
  # @param slot [Symbol]
  def edit_slot(slot)
    part = @appearance.part_for(slot)
    cmds = []
    cmds.push([:part, _INTL("Change part")])
    if part
      cmds.push([:colors, _INTL("Colors")]) if @config.allow_colors
      removable = @config.allow_remove && !CustomizationSettings::REQUIRED_SLOTS.include?(slot)
      cmds.push([:remove, _INTL("Remove")]) if removable
      cmds.push([:reset_colors, _INTL("Default colors")]) if @config.allow_colors
    end
    cmds.push([:revert, _INTL("Revert this slot")])
    cmds.push([:cancel, _INTL("Cancel")])
    text = _INTL("{1}: {2}", slot_name(slot), slot_value(slot))
    choice = pbMessage(text, cmds.map { |c| c[1] }, -1) { @scene.update }
    return if choice < 0
    case cmds[choice][0]
    when :part         then choose_part(slot)
    when :colors       then choose_region(slot)
    when :remove       then changed { @history.change { @appearance.unequip(slot) } }
    when :reset_colors then changed { @history.reset_colors(slot) }
    when :revert       then changed { @history.revert_slot(slot) }
    end
  end

  # @param part [GameData::PlayerPart, nil] nil is the "None" choice.
  # @param slot [Symbol]
  # @return [String] A row of the part picker: name, whether it's worn and its price.
  def part_label(part, slot)
    return _INTL("None") if !part
    name = part.name
    name = _INTL("{1} (worn)", name) if @appearance.parts[slot] == part.id
    name = _INTL("{1} ${2}", name, part.price.to_s_formatted) if @config.for_sale?(part)
    return name
  end

  # @brief Lets the player pick a part for a slot, previewing each one.
  # @param slot [Symbol]
  def choose_part(slot)
    parts = GameData::PlayerPart.for_slot(slot).select { |p| @config.part_offered?(p, @appearance) }
    options = parts.map(&:id)
    # Keep the worn part listed even if it isn't on offer, so the cursor can rest on it
    worn = @appearance.parts[slot]
    options.unshift(worn) if worn && !options.include?(worn) && GameData::PlayerPart.exists?(worn)
    options.unshift(nil) if @config.allow_remove && !CustomizationSettings::REQUIRED_SLOTS.include?(slot)
    if options.compact.empty?
      message(_INTL("There are no parts for this slot yet."))
      return
    end
    names = options.map { |id| part_label(id ? GameData::PlayerPart.get(id) : nil, slot) }
    current = options.index(worn) || 0
    choice = @scene.pick(names, current) do |i|
      preview = @appearance.snapshot
      id = options[i]
      removed = id ? preview.conflicts_with(id) : []
      id ? preview.equip(slot, id) : preview.unequip(slot)
      @scene.refresh_preview(preview)
      lines = slot_info_lines(slot, preview)
      lines.unshift(_INTL("Removes: {1}", removed.map { |s| slot_name(s) }.join(", "))) if !removed.empty?
      @scene.show_info(lines)
    end
    if choice >= 0
      id = options[choice]
      changed { @history.change { id ? @appearance.equip(slot, id) : @appearance.unequip(slot) } }
    else
      refresh
    end
  end

  # @brief Lets the player pick which color region of a part to color.
  # @param slot [Symbol]
  def choose_region(slot)
    part = @appearance.part_for(slot)
    return if !part
    return choose_color(slot, 1) if part.color_slots == 1
    region = 0
    loop do
      names = (1..part.color_slots).map do |r|
        _INTL("{1}: {2}", part.region_name(r), color_name(@appearance.color_for(slot, r)))
      end
      region = @scene.pick(names, region) { |_i| @scene.show_info(slot_info_lines(slot)) }
      break if region < 0
      choose_color(slot, region + 1)
    end
    refresh
  end

  # @brief Lets the player pick a labeled swatch for a region, previewing each one.
  # Only the swatches of the slot's palette are offered (see CustomizationSettings::SWATCH_PALETTES).
  # @param slot [Symbol]
  # @param region [Integer] 1-based region number.
  def choose_color(slot, region)
    part = @appearance.part_for(slot)
    swatches = [nil] + GameData::PlayerColor.for_slot(slot)
    title = _INTL("{1} - {2}", part.name, part.region_name(region))
    more = @config.color_options?
    loop do
      color = @appearance.color_for(slot, region)
      index = swatches.index { |s| s&.id == color.swatch } || 0
      action, index = @scene.pick_swatch(swatches, index, title, more) do |i|
        preview = @appearance.snapshot
        preview.set_color(slot, region, swatches[i]&.id, color.adjust)
        @scene.refresh_preview(preview)
      end
      case action
      when :use
        changed { @history.change { @appearance.set_color(slot, region, swatches[index]&.id, color.adjust) } }
        return
      when :action
        changed { @history.change { @appearance.set_color(slot, region, swatches[index]&.id, color.adjust) } }
        color_options(slot, region, title)
      else
        refresh
        return
      end
    end
  end

  # @brief Extra color options: fine-tuning and color linking. Returns to the swatch grid after.
  # @param slot [Symbol]
  # @param region [Integer]
  # @param title [String]
  def color_options(slot, region, title)
    key = [slot, region]
    cmds = []
    cmds.push([:tune, _INTL("Fine-tune")]) if @config.fine_tune?
    if @config.allow_link
      cmds.push([:link, _INTL("Link with...")])
      cmds.push([:unlink, _INTL("Unlink")]) if @appearance.linked?(key)
    end
    cmds.push([:back, _INTL("Back")])
    linked = @appearance.linked_keys(key) - [key]
    text = linked.empty? ? title : _INTL("{1}\nLinked with {2}.", title, linked.map { |k| region_label(k) }.join(", "))
    choice = pbMessage(text, cmds.map { |c| c[1] }, cmds.length) { @scene.update }
    case cmds[choice][0]
    when :tune
      color = @appearance.color_for(slot, region)
      adjust = @scene.pick_adjust(color.adjust, title) do |a|
        preview = @appearance.snapshot
        preview.set_color(slot, region, color.swatch, a)
        @scene.refresh_preview(preview)
      end
      changed { @history.change { @appearance.set_color(slot, region, color.swatch, adjust) } } if adjust
      refresh if !adjust
    when :link
      link_region(key)
    when :unlink
      changed { @history.change { @appearance.unlink(key) } }
    end
  end

  # @brief Lets the player link a region to another worn region in a slot they may change;
  # the other takes this color.
  # @param key [Array] [slot, region]
  def link_region(key)
    group = @appearance.linked_keys(key)
    others = []
    slots.each do |slot|
      part = @appearance.part_for(slot)
      next if !part
      (1..part.color_slots).each { |r| others.push([slot, r]) if !group.include?([slot, r]) }
    end
    if others.empty?
      message(_INTL("There's nothing else to link this color with."))
      return
    end
    names = others.map { |k| region_label(k) }
    choice = @scene.pick(names, 0) { |_i| @scene.show_info([_INTL("Share this color with:")]) }
    changed { @history.change { @appearance.link(key, others[choice]) } } if choice >= 0
    refresh if choice < 0
  end

  # @param key [Array] [slot, region]
  # @return [String] e.g. "Short hair (Color)".
  def region_label(key)
    part = @appearance.part_for(key[0])
    return _INTL("{1} ({2})", slot_name(key[0]), key[1]) if !part
    return _INTL("{1} ({2})", part.name, part.region_name(key[1]))
  end

  #----------------------------------------------------------------
  # Outfits
  #----------------------------------------------------------------
  # @brief Lists saved outfits and lets the player save, wear, rename or delete them.
  def outfits_menu
    loop do
      names = Wardrobe.names
      cmds = names.dup
      cmds.push(_INTL("Save current look")) if Wardrobe.room?
      cmds.push(_INTL("Cancel"))
      choice = pbMessage(_INTL("Outfits ({1}/{2})", names.length, CustomizationSettings::MAX_OUTFITS),
                         cmds, cmds.length) { @scene.update }
      if choice < names.length
        outfit_menu(choice)
      elsif Wardrobe.room? && choice == names.length
        name = pbMessageFreeText(_INTL("Name this outfit."), Wardrobe.default_name, false,
                                 CustomizationSettings::OUTFIT_NAME_LENGTH)
        next if !name || name.strip.empty?
        Wardrobe.save(name.strip, @appearance)
        message(_INTL("Saved \"{1}\".", name.strip))
      else
        break
      end
    end
    show_row_info(@scene.slot_window.index)
  end

  # @brief Actions for one saved outfit.
  # @param index [Integer]
  def outfit_menu(index)
    name = Wardrobe.names[index]
    cmds = [_INTL("Wear"), _INTL("Overwrite with current look"), _INTL("Rename"), _INTL("Delete"), _INTL("Cancel")]
    case pbMessage(_INTL("\"{1}\"", name), cmds, cmds.length) { @scene.update }
    when 0
      skipped = []
      changed { @history.change { skipped = Wardrobe.load(index, @appearance) } }
      report_skipped(skipped)
    when 1
      if confirm(_INTL("Replace \"{1}\" with your current look?", name))
        Wardrobe.overwrite(index, @appearance)
        message(_INTL("Saved \"{1}\".", name))
      end
    when 2
      new_name = pbMessageFreeText(_INTL("Rename this outfit."), name, false, CustomizationSettings::OUTFIT_NAME_LENGTH)
      Wardrobe.rename(index, new_name.strip) if new_name && !new_name.strip.empty?
    when 3
      Wardrobe.delete(index) if confirm(_INTL("Delete \"{1}\"?", name))
    end
  end

  #----------------------------------------------------------------
  # Share codes
  #----------------------------------------------------------------
  # @brief Shows this look's code, or wears a look from a code.
  def share_menu
    cmds = [_INTL("Show my code"), _INTL("Enter a code"), _INTL("Cancel")]
    case pbMessage(_INTL("Share code"), cmds, cmds.length) { @scene.update }
    when 0
      code = @appearance.to_code
      copied = Wardrobe.copy_to_clipboard(code)
      message(_INTL("Your code is:\n{1}", code))
      message(_INTL("The code was copied to the clipboard.")) if copied
    when 1
      pasted = Wardrobe.read_clipboard.to_s
      pasted = "" if pasted.length > SHARE_CODE_LENGTH || pasted.include?("\n")
      code = pbMessageFreeText(_INTL("Enter a code."), pasted, false, SHARE_CODE_LENGTH, Graphics.width)
      return if !code || code.strip.empty?
      look = PlayerAppearance.from_code(code.strip)
      if !look
        message(_INTL("That code isn't valid."))
        return
      end
      skipped = []
      changed { @history.change { skipped = Wardrobe.apply(look, @appearance) } }
      report_skipped(skipped)
    end
  end

  #----------------------------------------------------------------
  # Leaving, buying and paying
  #----------------------------------------------------------------
  # @brief The player chose Done (or Checkout).
  # @return [Boolean, nil] true to keep, false to discard, nil to keep editing.
  def finish
    return nil if @config.confirm_text && !confirm(@config.confirm_text)
    return settle
  end

  # @brief The player pressed Back: asks what to do with unsaved changes.
  # @return [Boolean, nil] true to keep, false to discard, nil to keep editing.
  def confirm_exit
    return false if !@history.dirty?
    return confirm(_INTL("Finish customizing?")) ? settle : nil if !@config.allow_cancel
    cmds = [_INTL("Keep changes"), _INTL("Discard changes"), _INTL("Keep editing")]
    case pbMessage(_INTL("You have unsaved changes."), cmds, 3) { @scene.update }
    when 0 then return settle
    when 1 then return false
    end
    return nil
  end

  # @brief Charges for the changes before they are kept, as the session's pricing says.
  # @return [Boolean, nil] true to keep, false to discard, nil to keep editing.
  def settle
    case @config.pricing
    when :purchase then return checkout
    when :fee      then return pay_fee
    end
    return true
  end

  # @brief Boutique checkout: buys every worn part the player doesn't own yet.
  # Bought parts are unlocked for good. The player can also buy them without wearing them,
  # go back to browsing, or leave without buying (which drops every change).
  # @return [Boolean, nil] true to keep, false to discard, nil to keep editing.
  def checkout
    unpaid = @config.unpaid_parts(@appearance)
    return true if unpaid.empty?
    total = unpaid.sum(&:price)
    names = unpaid.map(&:name).join(", ")
    cmds = [_INTL("Buy and wear"), _INTL("Buy only"), _INTL("Keep browsing"), _INTL("Leave without buying")]
    choice = pbMessage(_INTL("{1}\nThat comes to ${2}.", names, total.to_s_formatted), cmds, 3) { @scene.update }
    case choice
    when 0, 1
      return nil if !pay(total)
      unpaid.each { |part| $player.unlock_part(part.id) }
      message(_INTL("Here you are! Thank you!"))
      return choice == 0
    when 3
      return false
    end
    return nil
  end

  # @brief Stylist fee, charged only if the look changed.
  # @return [Boolean, nil] true to keep, false to discard, nil to keep editing.
  def pay_fee
    return true if @config.fee <= 0 || !@history.dirty?
    return nil if !confirm(_INTL("That will be ${1}. Is that OK?", @config.fee.to_s_formatted))
    return nil if !pay(@config.fee)
    message(_INTL("Thank you! Come again!"))
    return true
  end

  # @brief Takes money from the player.
  # @param amount [Integer]
  # @return [Boolean] false if the player can't afford it.
  def pay(amount)
    if $player.money < amount
      message(_INTL("You don't have enough money."))
      return false
    end
    $player.money -= amount
    pbSEPlay(CustomizationSettings::PAY_SE)
    @scene.refresh_header
    return true
  end

  #----------------------------------------------------------------
  # Messages
  #----------------------------------------------------------------
  # @brief Tells the player which parts couldn't be worn.
  # @param ids [Array<Symbol>]
  def report_skipped(ids)
    return if ids.empty?
    names = ids.filter_map { |id| GameData::PlayerPart.try_get(id)&.name }
    message(_INTL("You don't have these parts yet: {1}.", names.join(", "))) if !names.empty?
  end

  # @param text [String]
  def message(text)
    pbMessage(text) { @scene.update }
  end

  # @param text [String]
  # @return [Boolean]
  def confirm(text)
    return pbConfirmMessage(text) { @scene.update }
  end
end
