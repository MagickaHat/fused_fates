#================================================================================================
# Pokémon Fused Fates Character Customization System - 009_EditorScene.rb
#================================================================================================

#==================================================================
# class CharacterEditor_Scene
#==================================================================
# @brief Draws the character editor and reads the player's input inside pickers.
#
# Layout (sizes in CustomizationSettings::EDITOR_LAYOUT): the command list down the left side;
# on the right, top to bottom, the header (title and money, only when the session has either),
# the live preview (left/right turn the player, the Action button switches between sprite
# contexts) and the info panel (the selected row's details, the swatch grid or the sliders).
#
# The drawing lives in the panels of 008_EditorPanels.rb. Each panel takes optional art from
# CustomizationSettings::UI_GRAPHICS and falls back to flat colors, so the editor can be
# restyled by adding graphics without touching this class or the editor's logic.
class CharacterEditor_Scene
  # @brief Opens the editor's sprites.
  # @param appearance [PlayerAppearance] The appearance being edited.
  # @param config [CustomizationConfig] What the session allows (title, prices, first view...).
  def pbStartScene(appearance, config = CustomizationConfig.mirror)
    @appearance = appearance
    @config     = config
    @viewport   = Viewport.new(0, 0, Graphics.width, Graphics.height)
    @viewport.z = 99999
    @sprites    = {}
    @panels     = {}
    rects = layout
    @sprites["bg"] = BitmapSprite.new(Graphics.width, Graphics.height, @viewport)
    @sprites["bg"].z = 0
    if !EditorStyle.draw_graphic(@sprites["bg"].bitmap, :background)
      @sprites["bg"].bitmap.fill_rect(0, 0, Graphics.width, Graphics.height, EditorStyle::BG_COLOR)
    end
    if @config.show_header?
      @panels[:header] = EditorHeaderPanel.new(rects[:header], @viewport, :header)
    end
    @panels[:preview] = EditorPreviewPanel.new(rects[:preview], @viewport, first_context)
    @panels[:info]    = EditorInfoPanel.new(rects[:info], @viewport)
    list = rects[:list]
    @sprites["slots"] = Window_CommandPokemon.newWithSize([""], list.x, list.y, list.width, list.height, @viewport)
    @sprites["picker"] = Window_CommandPokemon.newWithSize([""], list.x, list.y, list.width, list.height, @viewport)
    @sprites["slots"].z  = 10
    @sprites["picker"].z = 10
    @sprites["picker"].visible = false
    @sprites["picker"].active  = false
    refresh_header
    refresh_preview
    pbFadeInAndShow(@sprites) { update }
  end

  # @brief Closes the editor's sprites.
  def pbEndScene
    pbFadeOutAndHide(@sprites) { update }
    pbDisposeSpriteHash(@sprites)
    @panels.each_value(&:dispose)
    @panels.clear
    @viewport.dispose
  end

  # @brief Updates windows and animates the preview. Call once per frame.
  def update
    pbUpdateSpriteHash(@sprites)
    @panels.each_value { |panel| panel.update if !panel.disposed? }
  end

  # @brief Waits one frame.
  def pbUpdate
    Graphics.update
    Input.update
    update
  end

  #----------------------------------------------------------------
  # Layout
  #----------------------------------------------------------------
  # @brief Works out where every panel goes.
  # @return [Hash{Symbol => Rect}] :list, :header, :preview and :info.
  def layout
    w = Graphics.width
    h = Graphics.height
    list_w   = CustomizationSettings::EDITOR_LAYOUT[:list_width]
    header_h = @config.show_header? ? CustomizationSettings::EDITOR_LAYOUT[:header_height] : 0
    info_h   = CustomizationSettings::EDITOR_LAYOUT[:info_height]
    return {
      list:    Rect.new(0, 0, list_w, h),
      header:  Rect.new(list_w, 0, w - list_w, header_h),
      preview: Rect.new(list_w, header_h, w - list_w, h - header_h - info_h),
      info:    Rect.new(list_w, h - info_h, w - list_w, info_h)
    }
  end

  #----------------------------------------------------------------
  # Command list
  #----------------------------------------------------------------
  # @return [Window_CommandPokemon]
  def slot_window
    return @sprites["slots"]
  end

  # @brief Rebuilds the command list's rows.
  # @param rows [Array<String>]
  def set_rows(rows)
    index = slot_window.index
    slot_window.commands = rows
    slot_window.index = index.clamp(0, [rows.length - 1, 0].max)
  end

  #----------------------------------------------------------------
  # Header
  #----------------------------------------------------------------
  # @brief Redraws the title and the player's money.
  def refresh_header
    @panels[:header]&.refresh(@config.title, @config.paid?)
  end

  #----------------------------------------------------------------
  # Preview
  #----------------------------------------------------------------
  # @return [Symbol] The context being previewed.
  def context
    return @panels[:preview].context
  end

  # @brief Turns the preview to face another direction.
  # @param step [Integer] 1 to turn clockwise, -1 anticlockwise.
  def turn(step)
    @panels[:preview].turn(step)
  end

  # @brief Switches the preview to another sprite context.
  # @param step [Integer] 1 for the next context, -1 for the previous.
  def cycle_context(step = 1)
    keys = PlayerCompositor.all_contexts
    @panels[:preview].context = keys[((keys.index(context) || 0) + step) % keys.length]
    refresh_preview(@last_preview || @appearance)
  end

  # @brief Redraws the preview, optionally showing an appearance that isn't saved yet.
  # Changing the view keeps showing the same appearance until the preview is redrawn again.
  # @param appearance [PlayerAppearance] Defaults to the appearance being edited.
  def refresh_preview(appearance = @appearance)
    @last_preview = appearance
    bmp = PlayerCompositor.bitmap_for(context, appearance)
    @panels[:preview].show(bmp, PlayerCompositor.art_context(context, appearance))
  end

  #----------------------------------------------------------------
  # Info panel
  #----------------------------------------------------------------
  # @brief Shows lines of text in the info panel.
  # @param lines [Array] See EditorInfoPanel#show_lines.
  def show_info(lines)
    @panels[:info].show_lines(lines)
  end

  #----------------------------------------------------------------
  # Pickers
  #----------------------------------------------------------------
  # @brief Lets the player choose from a list shown over the command list.
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
  # @param more [Boolean] Whether the Action button opens more options.
  # @yieldparam index [Integer] Called whenever the cursor moves (and once at the start).
  # @return [Array] [:use, index], [:action, index] or [:back, nil].
  def pick_swatch(swatches, index, title, more = true)
    info = @panels[:info]
    cols = info.swatch_columns
    last = nil
    slot_window.active = false
    loop do
      if index != last
        pbPlayCursorSE if last
        last = index
        info.draw_swatch_grid(swatches, index, title, more)
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
      elsif more && Input.trigger?(Input::ACTION)
        pbPlayDecisionSE
        slot_window.active = true
        return [:action, index]
      elsif Input.trigger?(Input::BACK)
        pbPlayCancelSE
        slot_window.active = true
        return [:back, nil]
      end
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
        @panels[:info].draw_sliders(current, row, title)
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

  # @return [Symbol] The context the preview opens on.
  def first_context
    wanted = @config.start_context
    return wanted if wanted && PlayerCompositor.all_contexts.include?(wanted)
    return CustomizationSettings::CONTEXTS.keys.first
  end
end
