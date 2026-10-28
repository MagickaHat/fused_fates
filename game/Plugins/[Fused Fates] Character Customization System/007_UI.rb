#================================================================================================
# Pokémon Fused Fates Character Customization System - 007_UI.rb
#================================================================================================

#==================================================================
# class CharacterEditor_Scene
#==================================================================
# @brief Draws the character editor. Uses no graphics of its own: panels, swatches and sliders
# are drawn with the windowskin, filled rectangles and text.
#
# Layout: the slot list on the left, a live preview of the player on the right (left/right turn
# the player, the Action button switches between sprite contexts) and an info panel underneath
# showing the selected slot's colors, the swatch grid or the fine-tune sliders.
class CharacterEditor_Scene
  LIST_WIDTH   = 224
  INFO_HEIGHT  = 112
  SWATCH_SIZE  = 20
  SWATCH_GAP   = 4
  # Facing order used when turning the preview, and each facing's row in a charset
  FACINGS      = [2, 4, 8, 6].freeze
  FACING_ROWS  = { 2 => 0, 4 => 1, 6 => 2, 8 => 3 }.freeze

  BG_COLOR       = Color.new(48, 56, 72)
  PANEL_COLOR    = Color.new(232, 232, 240)
  BASE_COLOR     = Color.new(64, 64, 64)
  SHADOW_COLOR   = Color.new(176, 176, 176)
  LIGHT_BASE     = Color.new(248, 248, 248)
  LIGHT_SHADOW   = Color.new(40, 40, 48)
  CURSOR_COLOR   = Color.new(232, 88, 64)
  BAR_COLOR      = Color.new(120, 144, 200)

  attr_reader :context

  # @brief Opens the editor's sprites.
  # @param appearance [PlayerAppearance] The appearance being edited.
  def pbStartScene(appearance)
    @appearance = appearance
    @context    = CustomizationSettings::CONTEXTS.keys.first
    @facing     = 0
    @frame      = 0
    @viewport   = Viewport.new(0, 0, Graphics.width, Graphics.height)
    @viewport.z = 99999
    @sprites    = {}
    @sprites["bg"] = BitmapSprite.new(Graphics.width, Graphics.height, @viewport)
    draw_background
    @sprites["preview"] = Sprite.new(@viewport)
    @sprites["preview"].zoom_x = CustomizationSettings::PREVIEW_ZOOM
    @sprites["preview"].zoom_y = CustomizationSettings::PREVIEW_ZOOM
    @sprites["overlay"] = BitmapSprite.new(Graphics.width, Graphics.height, @viewport)
    pbSetSystemFont(@sprites["overlay"].bitmap)
    @sprites["slots"] = Window_CommandPokemon.newWithSize([""], 0, 0, LIST_WIDTH, Graphics.height, @viewport)
    @sprites["picker"] = Window_CommandPokemon.newWithSize([""], 0, 0, LIST_WIDTH, Graphics.height, @viewport)
    @sprites["picker"].visible = false
    @sprites["picker"].active  = false
    refresh_preview
    pbFadeInAndShow(@sprites) { update }
  end

  # @brief Closes the editor's sprites.
  def pbEndScene
    pbFadeOutAndHide(@sprites) { update }
    pbDisposeSpriteHash(@sprites)
    @preview_bitmap&.dispose
    @preview_bitmap = nil
    @viewport.dispose
  end

  # @brief Updates windows and animates the preview. Call once per frame.
  def update
    pbUpdateSpriteHash(@sprites)
    @frame += 1
    update_preview_frame
  end

  # @brief Waits one frame.
  def pbUpdate
    Graphics.update
    Input.update
    update
  end

  #----------------------------------------------------------------
  # Slot list
  #----------------------------------------------------------------
  # @return [Window_CommandPokemon]
  def slot_window
    return @sprites["slots"]
  end

  # @brief Rebuilds the slot list's rows.
  # @param rows [Array<String>]
  def set_rows(rows)
    index = slot_window.index
    slot_window.commands = rows
    slot_window.index = index.clamp(0, [rows.length - 1, 0].max)
  end

  #----------------------------------------------------------------
  # Preview
  #----------------------------------------------------------------
  # @brief Turns the preview to face another direction.
  # @param step [Integer] 1 to turn clockwise, -1 anticlockwise.
  def turn(step)
    @facing = (@facing + step) % FACINGS.length
    update_preview_frame
  end

  # @brief Switches the preview to another sprite context.
  # @param step [Integer] 1 for the next context, -1 for the previous.
  def cycle_context(step = 1)
    keys = PlayerCompositor.all_contexts
    @context = keys[(keys.index(@context) + step) % keys.length]
    refresh_preview
  end

  # @brief Redraws the preview, optionally showing an appearance that isn't saved yet.
  # @param appearance [PlayerAppearance] Defaults to the appearance being edited.
  def refresh_preview(appearance = @appearance)
    old = @preview_bitmap
    @preview_bitmap = PlayerCompositor.bitmap_for(@context, appearance)
    @art_context = PlayerCompositor.art_context(@context, appearance)
    @sprites["preview"].bitmap = @preview_bitmap
    old&.dispose
    update_preview_frame
    draw_preview_labels
  end

  # @brief Picks the frame of the preview bitmap to show.
  def update_preview_frame
    sprite = @sprites["preview"]
    bmp = @preview_bitmap
    return if !sprite || !bmp || bmp.disposed?
    if CustomizationSettings::CONTEXTS.dig(@context, :kind) == :charset
      fw = bmp.width / 4
      fh = bmp.height / 4
      pattern = (@frame / CustomizationSettings::PREVIEW_FRAME_TIME) % 4
      sprite.src_rect.set(pattern * fw, FACING_ROWS[FACINGS[@facing]] * fh, fw, fh)
    else
      # Battle back sprites are 5-frame strips; trainer card sprites and derived graphics are whole
      frames = (bmp.width > bmp.height * 2) ? 5 : 1
      sprite.src_rect.set(0, 0, bmp.width / frames, bmp.height)
    end
    sprite.ox = sprite.src_rect.width / 2
    sprite.oy = sprite.src_rect.height / 2
    sprite.x  = LIST_WIDTH + ((Graphics.width - LIST_WIDTH) / 2)
    sprite.y  = (Graphics.height - INFO_HEIGHT) / 2
  end

  # @brief Draws the context name, the controls and a note when there is no art.
  def draw_preview_labels
    overlay = @sprites["overlay"].bitmap
    overlay.clear_rect(LIST_WIDTH, 0, Graphics.width - LIST_WIDTH, Graphics.height - INFO_HEIGHT)
    center = LIST_WIDTH + ((Graphics.width - LIST_WIDTH) / 2)
    name = PlayerCompositor.context_name(@context)
    texts = [[_INTL("< {1} >", name), center, 12, :center, LIGHT_BASE, LIGHT_SHADOW]]
    if !@art_context
      texts.push([_INTL("No art for this view"), center, ((Graphics.height - INFO_HEIGHT) / 2) - 12,
                  :center, LIGHT_BASE, LIGHT_SHADOW])
    elsif @art_context != @context
      art_name = PlayerCompositor.context_name(@art_context)
      texts.push([_INTL("(using {1} art)", art_name), center, 40, :center, LIGHT_BASE, LIGHT_SHADOW])
    end
    texts.push([_INTL("Action: change view"), center, Graphics.height - INFO_HEIGHT - 64,
                :center, LIGHT_BASE, LIGHT_SHADOW])
    texts.push([_INTL("Left/Right: turn"), center, Graphics.height - INFO_HEIGHT - 36,
                :center, LIGHT_BASE, LIGHT_SHADOW])
    pbDrawTextPositions(overlay, texts)
  end

  #----------------------------------------------------------------
  # Info panel
  #----------------------------------------------------------------
  # @return [Rect] Area of the info panel.
  def info_rect
    return Rect.new(LIST_WIDTH, Graphics.height - INFO_HEIGHT, Graphics.width - LIST_WIDTH, INFO_HEIGHT)
  end

  # @brief Clears the info panel and returns the overlay to draw on.
  # @return [Bitmap]
  def clear_info
    overlay = @sprites["overlay"].bitmap
    r = info_rect
    overlay.clear_rect(r.x, r.y, r.width, r.height)
    return overlay
  end

  # @brief Shows lines of text in the info panel, each optionally led by a color swatch.
  # @param lines [Array] Each a String, or [String, RegionColor] to draw the color in front.
  def show_info(lines)
    overlay = clear_info
    r = info_rect
    texts = []
    lines.first(INFO_HEIGHT / 26).each_with_index do |line, i|
      text, color = line.is_a?(Array) ? line : [line, nil]
      y = r.y + 8 + (i * 26)
      x = r.x + 12
      if color
        draw_region_color(overlay, x, y + 4, color)
        x += SWATCH_SIZE + 8
      end
      texts.push([text, x, y, :left, BASE_COLOR, SHADOW_COLOR])
    end
    pbDrawTextPositions(overlay, texts)
  end

  # @brief Draws a small box filled with a region's color.
  # @param bitmap [Bitmap]
  # @param x [Integer]
  # @param y [Integer]
  # @param color [RegionColor, GameData::PlayerColor, nil] nil draws the "no color" box.
  def draw_region_color(bitmap, x, y, color)
    swatch = color.is_a?(RegionColor) ? color.swatch_data : color
    bitmap.fill_rect(x, y, SWATCH_SIZE, SWATCH_SIZE, BASE_COLOR)
    if swatch
      rgb = ColorMath.to_rgb(swatch.color)
      rgb = Recolor.transform(*rgb, color.adjust) if color.is_a?(RegionColor)
      bitmap.fill_rect(x + 2, y + 2, SWATCH_SIZE - 4, SWATCH_SIZE - 4, ColorMath.to_color(rgb))
    else
      # No swatch: the art keeps its own shades, shown as a struck-out box
      bitmap.fill_rect(x + 2, y + 2, SWATCH_SIZE - 4, SWATCH_SIZE - 4, PANEL_COLOR)
      (SWATCH_SIZE - 4).times { |i| bitmap.fill_rect(x + 2 + i, y + 2 + i, 1, 1, CURSOR_COLOR) }
    end
  end

  # @brief Draws the swatch grid with a cursor and the selected swatch's name.
  # @param swatches [Array<GameData::PlayerColor, nil>] nil is the "no color" choice.
  # @param index [Integer] Selected entry.
  # @param title [String] Shown above the grid.
  def draw_swatch_grid(swatches, index, title)
    overlay = clear_info
    r = info_rect
    cell = SWATCH_SIZE + SWATCH_GAP
    cols = swatch_columns
    rows = 2
    top_row = [(index / cols) - rows + 1, 0].max
    swatches.each_with_index do |swatch, i|
      row = (i / cols) - top_row
      next if row < 0 || row >= rows
      x = r.x + 12 + ((i % cols) * cell)
      y = r.y + 32 + (row * cell)
      overlay.fill_rect(x - 2, y - 2, SWATCH_SIZE + 4, SWATCH_SIZE + 4, CURSOR_COLOR) if i == index
      draw_region_color(overlay, x, y, swatch)
    end
    label = swatches[index] ? swatches[index].name : _INTL("No color")
    pbDrawTextPositions(overlay, [
      [title, r.x + 12, r.y + 4, :left, BASE_COLOR, SHADOW_COLOR],
      [label, r.x + 12, r.y + 32 + (rows * cell), :left, CURSOR_COLOR, SHADOW_COLOR],
      [_INTL("Action: more"), r.x + r.width - 12, r.y + 32 + (rows * cell), :right, BASE_COLOR, SHADOW_COLOR]
    ])
  end

  # @return [Integer] Number of swatches per row of the grid.
  def swatch_columns
    return [(info_rect.width - 24) / (SWATCH_SIZE + SWATCH_GAP), 1].max
  end

  # @brief Draws the hue/saturation/value sliders.
  # @param adjust [ColorAdjust]
  # @param row [Integer] Selected slider (0-2).
  # @param title [String]
  def draw_sliders(adjust, row, title)
    overlay = clear_info
    r = info_rect
    bar_x = r.x + 112
    bar_w = r.width - 124
    sliders = [
      [_INTL("Hue"),        adjust.hue % 360,  0,    359],
      [_INTL("Saturation"), adjust.saturation, -100, 100],
      [_INTL("Value"),      adjust.value,      -100, 100]
    ]
    texts = [[title, r.x + 12, r.y + 4, :left, BASE_COLOR, SHADOW_COLOR]]
    sliders.each_with_index do |(name, value, min, max), i|
      y = r.y + 30 + (i * 26)
      texts.push([name, r.x + 12, y, :left, (i == row) ? CURSOR_COLOR : BASE_COLOR, SHADOW_COLOR])
      overlay.fill_rect(bar_x, y + 10, bar_w, 6, SHADOW_COLOR)
      fill = ((value - min) * bar_w / (max - min).to_f).round
      overlay.fill_rect(bar_x, y + 10, fill, 6, BAR_COLOR)
      overlay.fill_rect(bar_x + fill - 2, y + 6, 4, 14, (i == row) ? CURSOR_COLOR : BASE_COLOR)
    end
    pbDrawTextPositions(overlay, texts)
  end

  #----------------------------------------------------------------
  # Pickers
  #----------------------------------------------------------------
  # @brief Lets the player choose from a list shown over the slot list.
  # @param commands [Array<String>]
  # @param index [Integer] Initially selected entry.
  # @yieldparam index [Integer] Called whenever the cursor moves (and once at the start).
  # @return [Integer] The chosen entry, or -1 if cancelled.
  def pick(commands, index = 0)
    win = @sprites["picker"]
    win.commands = commands
    win.index = index.clamp(0, commands.length - 1)
    win.visible = true
    win.active = true
    slot_window.visible = false
    slot_window.active = false
    last = nil
    ret = -1
    loop do
      if win.index != last
        last = win.index
        yield last if block_given?
      end
      pbUpdate
      handle_preview_input
      if Input.trigger?(Input::USE)
        pbPlayDecisionSE
        ret = win.index
        break
      elsif Input.trigger?(Input::BACK)
        pbPlayCancelSE
        break
      end
    end
    win.visible = false
    win.active = false
    slot_window.visible = true
    slot_window.active = true
    return ret
  end

  # @brief Lets the player choose a swatch from the grid.
  # @param swatches [Array<GameData::PlayerColor, nil>]
  # @param index [Integer] Initially selected entry.
  # @param title [String]
  # @yieldparam index [Integer] Called whenever the cursor moves (and once at the start).
  # @return [Array] [:use, index], [:action, index] or [:back, nil].
  def pick_swatch(swatches, index, title)
    cols = swatch_columns
    last = nil
    slot_window.active = false
    loop do
      if index != last
        last = index
        draw_swatch_grid(swatches, index, title)
        yield index if block_given?
      end
      pbUpdate
      if Input.repeat?(Input::LEFT)
        index -= 1 if index > 0
      elsif Input.repeat?(Input::RIGHT)
        index += 1 if index < swatches.length - 1
      elsif Input.repeat?(Input::UP)
        index -= cols if index - cols >= 0
      elsif Input.repeat?(Input::DOWN)
        index = [index + cols, swatches.length - 1].min if (index / cols) < ((swatches.length - 1) / cols)
      elsif Input.trigger?(Input::USE)
        pbPlayDecisionSE
        slot_window.active = true
        return [:use, index]
      elsif Input.trigger?(Input::ACTION)
        pbPlayDecisionSE
        slot_window.active = true
        return [:action, index]
      elsif Input.trigger?(Input::BACK)
        pbPlayCancelSE
        slot_window.active = true
        return [:back, nil]
      end
      pbPlayCursorSE if index != last
    end
  end

  # @brief Lets the player fine-tune a color with hue/saturation/value sliders.
  # @param adjust [ColorAdjust] Starting values (not changed).
  # @param title [String]
  # @yieldparam adjust [ColorAdjust] Called whenever a value changes (and once at the start).
  # @return [ColorAdjust, nil] The new adjustment, or nil if cancelled.
  def pick_adjust(adjust, title)
    values = [adjust.hue % 360, adjust.saturation, adjust.value]
    step = CustomizationSettings::CUSTOM_COLOR_STEP
    row = 0
    dirty = true
    slot_window.active = false
    loop do
      if dirty
        dirty = false
        current = ColorAdjust.new(*values)
        draw_sliders(current, row, title)
        yield current if block_given?
      end
      pbUpdate
      if Input.repeat?(Input::UP) && row > 0
        row -= 1
        dirty = true
      elsif Input.repeat?(Input::DOWN) && row < 2
        row += 1
        dirty = true
      elsif Input.repeat?(Input::LEFT) || Input.repeat?(Input::RIGHT)
        delta = Input.repeat?(Input::LEFT) ? -step : step
        values[row] = (row == 0) ? (values[row] + delta) % 360 : (values[row] + delta).clamp(-100, 100)
        pbPlayCursorSE
        dirty = true
      elsif Input.trigger?(Input::USE)
        pbPlayDecisionSE
        slot_window.active = true
        return ColorAdjust.new(*values)
      elsif Input.trigger?(Input::BACK)
        pbPlayCancelSE
        slot_window.active = true
        return nil
      end
    end
  end

  # @brief Turns the preview or changes its context in response to input.
  # @return [Boolean] Whether any input was handled.
  def handle_preview_input
    if Input.trigger?(Input::ACTION)
      pbPlayCursorSE
      cycle_context(1)
    elsif Input.repeat?(Input::LEFT)
      turn(1)
    elsif Input.repeat?(Input::RIGHT)
      turn(-1)
    else
      return false
    end
    return true
  end

  private

  # @brief Fills the background and the preview and info panels.
  def draw_background
    bmp = @sprites["bg"].bitmap
    bmp.fill_rect(0, 0, Graphics.width, Graphics.height, BG_COLOR)
    r = info_rect
    bmp.fill_rect(r.x + 4, r.y, r.width - 8, r.height - 4, PANEL_COLOR)
  end
end

#==================================================================
# class CharacterEditor_Screen
#==================================================================
# @brief The character editor's logic: what each command does to the appearance.
class CharacterEditor_Screen
  # Commands listed under the slots
  COMMANDS = [:undo, :redo, :revert, :outfits, :share, :done].freeze
  # Longest share code the player can type or paste
  SHARE_CODE_LENGTH = 500

  # @brief Creates the editor.
  # @param scene [CharacterEditor_Scene]
  # @param appearance [PlayerAppearance] Edited in place.
  # @param allow_cancel [Boolean] Whether the player may leave without keeping changes.
  def initialize(scene, appearance, allow_cancel = true)
    @scene        = scene
    @appearance   = appearance
    @history      = AppearanceHistory.new(appearance)
    @allow_cancel = allow_cancel
  end

  # @brief Runs the editor until the player leaves.
  # @return [Boolean] Whether the changes should be kept.
  def pbStartScreen
    @scene.pbStartScene(@appearance)
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
          case COMMANDS[win.index - slots.length]
          when :undo    then message(_INTL("There's nothing to undo.")) if !changed { @history.undo }
          when :redo    then message(_INTL("There's nothing to redo.")) if !changed { @history.redo }
          when :revert
            if @history.dirty? && confirm(_INTL("Undo every change made since opening the editor?"))
              changed { @history.revert_all }
            end
          when :outfits then outfits_menu
          when :share   then share_menu
          when :done
            keep = true
            break
          end
        end
        last_index = nil
      elsif Input.trigger?(Input::BACK)
        pbPlayCancelSE
        result = confirm_exit
        next if result.nil?
        keep = result
        break
      end
    end
    @scene.pbEndScene
    return keep
  end

  private

  #----------------------------------------------------------------
  # Main list
  #----------------------------------------------------------------
  # @return [Array<Symbol>]
  def slots
    return CustomizationSettings::SLOT_ORDER
  end

  # @brief Redraws the slot list and the preview after a change.
  def refresh
    rows = slots.map { |slot| _INTL("{1}: {2}", slot_name(slot), slot_value(slot)) }
    rows += [_INTL("Undo"), _INTL("Redo"), _INTL("Revert all"), _INTL("Outfits..."),
             _INTL("Share code..."), _INTL("Done")]
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
      descriptions = {
        undo:    _INTL("Undo the last change."),
        redo:    _INTL("Redo what you undid."),
        revert:  _INTL("Back to how you started."),
        outfits: _INTL("Saved outfits: {1}/{2}", $player.outfits.length, CustomizationSettings::MAX_OUTFITS),
        share:   _INTL("Show or enter a look code."),
        done:    _INTL("Finish and keep changes.")
      }
      @scene.show_info([descriptions[COMMANDS[index - slots.length]] || ""])
      return
    end
    @scene.show_info(slot_info_lines(slot))
  end

  # @brief Lines describing a slot: what fills it, what it hides and each region's color.
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
    cmds.push([:colors, _INTL("Colors")]) if part
    cmds.push([:remove, _INTL("Remove")]) if part && !CustomizationSettings::REQUIRED_SLOTS.include?(slot)
    cmds.push([:reset_colors, _INTL("Default colors")]) if part
    cmds.push([:revert, _INTL("Revert this slot")])
    cmds.push([:cancel, _INTL("Cancel")])
    choice = pbMessage(_INTL("{1}: {2}", slot_name(slot), slot_value(slot)), cmds.map { |c| c[1] }, -1) { @scene.update }
    return if choice < 0
    case cmds[choice][0]
    when :part         then choose_part(slot)
    when :colors       then choose_region(slot)
    when :remove       then changed { @history.change { @appearance.unequip(slot) } }
    when :reset_colors then changed { @history.reset_colors(slot) }
    when :revert       then changed { @history.revert_slot(slot) }
    end
  end

  # @brief Lets the player pick a part for a slot, previewing each one.
  # @param slot [Symbol]
  def choose_part(slot)
    parts = GameData::PlayerPart.for_slot(slot).select { |p| $player.part_selectable?(p.id) }
    required = CustomizationSettings::REQUIRED_SLOTS.include?(slot)
    options = parts.map(&:id)
    options.unshift(nil) if !required
    if options.empty?
      message(_INTL("There are no parts for this slot yet."))
      return
    end
    names = options.map do |id|
      name = id ? GameData::PlayerPart.get(id).name : _INTL("None")
      next (@appearance.parts[slot] == id) ? _INTL("{1} (worn)", name) : name
    end
    current = options.index(@appearance.parts[slot]) || 0
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
      region = @scene.pick(names, region) { |i| @scene.show_info(slot_info_lines(slot)) }
      break if region < 0
      choose_color(slot, region + 1)
    end
    refresh
  end

  # @brief Lets the player pick a labeled swatch for a region, previewing each one.
  # @param slot [Symbol]
  # @param region [Integer] 1-based region number.
  def choose_color(slot, region)
    part = @appearance.part_for(slot)
    swatches = [nil]
    GameData::PlayerColor.each { |swatch| swatches.push(swatch) }
    title = _INTL("{1} - {2}", part.name, part.region_name(region))
    loop do
      color = @appearance.color_for(slot, region)
      index = swatches.index { |s| s&.id == color.swatch } || 0
      action, index = @scene.pick_swatch(swatches, index, title) do |i|
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
    cmds.push([:tune, _INTL("Fine-tune")]) if CustomizationSettings::ALLOW_CUSTOM_COLOR
    cmds.push([:link, _INTL("Link with...")])
    cmds.push([:unlink, _INTL("Unlink")]) if @appearance.linked?(key)
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

  # @brief Lets the player link a region to another worn region; the other takes this color.
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
  # Messages
  #----------------------------------------------------------------
  # @brief Tells the player which parts couldn't be worn.
  # @param ids [Array<Symbol>]
  def report_skipped(ids)
    return if ids.empty?
    names = ids.filter_map { |id| GameData::PlayerPart.try_get(id)&.name }
    message(_INTL("You don't have these parts yet: {1}.", names.join(", "))) if !names.empty?
  end

  # @brief Asks what to do with unsaved changes when leaving.
  # @return [Boolean, nil] true to keep, false to discard, nil to keep editing.
  def confirm_exit
    return false if !@history.dirty?
    return confirm(_INTL("Finish customizing?")) ? true : nil if !@allow_cancel
    cmds = [_INTL("Keep changes"), _INTL("Discard changes"), _INTL("Keep editing")]
    case pbMessage(_INTL("You have unsaved changes."), cmds, 3) { @scene.update }
    when 0 then return true
    when 1 then return false
    end
    return nil
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

#==================================================================
# Script helpers
#==================================================================
# @brief Opens the character editor (for use in events, e.g. a mirror or a boutique).
# @param allow_cancel [Boolean] Whether the player may leave without keeping their changes.
# @return [Boolean] Whether the player's appearance changed.
def pbCustomizeCharacter(allow_cancel: true)
  editing = $player.appearance.snapshot.sanitize!
  before = $player.appearance.snapshot
  keep = false
  pbFadeOutIn do
    screen = CharacterEditor_Screen.new(CharacterEditor_Scene.new, editing, allow_cancel)
    keep = screen.pbStartScreen
  end
  return false if !keep || editing == before
  $player.appearance = editing
  CharacterCustomization.refresh
  return true
end
