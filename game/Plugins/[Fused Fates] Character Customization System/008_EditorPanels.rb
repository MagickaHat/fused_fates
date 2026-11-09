#================================================================================================
# Pokémon Fused Fates Character Customization System - 008_EditorPanels.rb
#================================================================================================

#==================================================================
# module EditorStyle
#==================================================================
# @brief Colors and helpers shared by the character editor's panels.
module EditorStyle
  BG_COLOR     = Color.new(48, 56, 72)
  PANEL_COLOR  = Color.new(232, 232, 240)
  BASE_COLOR   = Color.new(64, 64, 64)
  SHADOW_COLOR = Color.new(176, 176, 176)
  LIGHT_BASE   = Color.new(248, 248, 248)
  LIGHT_SHADOW = Color.new(40, 40, 48)
  CURSOR_COLOR = Color.new(232, 88, 64)
  BAR_COLOR    = Color.new(120, 144, 200)
  PRICE_COLOR  = Color.new(48, 128, 64)

  module_function

  # @brief Finds an editor graphic from CustomizationSettings::UI_GRAPHICS.
  # @param key [Symbol] e.g. :background, :info.
  # @return [String, nil] The resolved file, or nil if there is no art for it.
  def graphic(key)
    name = CustomizationSettings::UI_GRAPHICS[key]
    return nil if !name
    return pbResolveBitmap(CustomizationSettings::UI_FOLDER + name)
  end

  # @brief Stretches an editor graphic over a bitmap.
  # @param bitmap [Bitmap]
  # @param key [Symbol] e.g. :background, :info.
  # @return [Boolean] false if there is no art for it.
  def draw_graphic(bitmap, key)
    path = graphic(key)
    return false if !path
    src = Bitmap.new(path)
    bitmap.stretch_blt(Rect.new(0, 0, bitmap.width, bitmap.height), src, src.rect)
    src.dispose
    return true
  end
end

#==================================================================
# class EditorPanel
#==================================================================
# @brief One rectangular area of the character editor: a background layer (art from
# CustomizationSettings::UI_GRAPHICS, or a flat fill) and an overlay for text.
# Everything is drawn in panel coordinates, so panels can be moved by changing the layout only.
class EditorPanel
  attr_reader :rect

  # @brief Creates the panel's sprites.
  # @param rect [Rect] Area on screen.
  # @param viewport [Viewport]
  # @param graphic [Symbol] Key of CustomizationSettings::UI_GRAPHICS for the background.
  def initialize(rect, viewport, graphic)
    @rect = rect
    @bg = BitmapSprite.new([rect.width, 1].max, [rect.height, 1].max, viewport)
    @bg.x = rect.x
    @bg.y = rect.y
    @bg.z = 1
    @overlay = BitmapSprite.new([rect.width, 1].max, [rect.height, 1].max, viewport)
    @overlay.x = rect.x
    @overlay.y = rect.y
    @overlay.z = 3
    pbSetSystemFont(@overlay.bitmap)
    draw_background if !EditorStyle.draw_graphic(@bg.bitmap, graphic)
  end

  # @return [Bitmap] The overlay to draw text on.
  def bitmap
    return @overlay.bitmap
  end

  # @return [Integer]
  def width
    return @rect.width
  end

  # @return [Integer]
  def height
    return @rect.height
  end

  # @brief Erases the overlay.
  def clear
    bitmap.clear
  end

  # @param value [Boolean]
  def visible=(value)
    @bg.visible = value
    @overlay.visible = value
  end

  # @brief Updates the panel. Call once per frame.
  def update; end

  # @brief Frees the panel's sprites.
  def dispose
    @bg.dispose
    @overlay.dispose
  end

  # @return [Boolean]
  def disposed?
    return @overlay.disposed?
  end

  private

  # @brief Fills the background when there is no art. Subclasses draw their own boxes.
  def draw_background; end

  # @brief Draws a light rounded-looking box filling the panel, inset by a margin.
  def fill_box(margin = 4)
    @bg.bitmap.fill_rect(margin, 0, width - (margin * 2), height - margin, EditorStyle::PANEL_COLOR)
  end
end

#==================================================================
# class EditorHeaderPanel
#==================================================================
# @brief The header: the session's title on the left and, in paid sessions, the player's money.
class EditorHeaderPanel < EditorPanel
  # @brief Draws the header.
  # @param title [String, nil]
  # @param show_money [Boolean]
  def refresh(title, show_money)
    clear
    texts = []
    texts.push([title, 12, 6, :left, EditorStyle::LIGHT_BASE, EditorStyle::LIGHT_SHADOW]) if title
    if show_money
      texts.push([_INTL("Money: {1}", pbGetGoldString), width - 12, 6, :right,
                  EditorStyle::LIGHT_BASE, EditorStyle::LIGHT_SHADOW])
    end
    pbDrawTextPositions(bitmap, texts)
  end
end

#==================================================================
# class EditorPreviewPanel
#==================================================================
# @brief The live preview of the player: the composited sprite for one context, which can be
# turned (overworld sprites) and switched to another context.
class EditorPreviewPanel < EditorPanel
  # Facing order used when turning the preview, and each facing's row in a charset
  FACINGS     = [2, 4, 8, 6].freeze
  FACING_ROWS = {2 => 0, 4 => 1, 6 => 2, 8 => 3}.freeze

  # @return [Symbol] The context being shown (a key of PlayerCompositor.all_contexts).
  attr_accessor :context

  # @param rect [Rect]
  # @param viewport [Viewport]
  # @param context [Symbol] Context shown first.
  def initialize(rect, viewport, context)
    super(rect, viewport, :preview)
    @context = context
    @facing  = 0
    @frame   = 0
    @sprite  = Sprite.new(viewport)
    @sprite.z = 2
  end

  # @brief Shows a composited bitmap. The panel owns it from now on.
  # @param bmp [Bitmap, nil]
  # @param art_context [Symbol, nil] Context whose art was used; nil if there was none.
  def show(bmp, art_context)
    old = @bitmap
    @bitmap = bmp
    @sprite.bitmap = bmp
    old&.dispose if !old.equal?(bmp)
    zoom = CustomizationSettings::PREVIEW_ZOOM[kind] || 1
    @sprite.zoom_x = zoom
    @sprite.zoom_y = zoom
    update_frame
    draw_labels(art_context)
  end

  # @brief Turns the preview to face another direction.
  # @param step [Integer] 1 to turn clockwise, -1 anticlockwise.
  def turn(step)
    @facing = (@facing + step) % FACINGS.length
    update_frame
  end

  # @brief Animates the preview. Call once per frame.
  def update
    @frame += 1
    update_frame
  end

  # @brief Frees the panel's sprites and the preview bitmap.
  def dispose
    @sprite.dispose
    @bitmap&.dispose
    @bitmap = nil
    super
  end

  private

  # @return [Symbol] :charset, :trainer or :derived.
  def kind
    return CustomizationSettings::CONTEXTS.dig(@context, :kind) || :derived
  end

  # @brief Picks the frame of the preview bitmap to show and centers it in the panel.
  def update_frame
    bmp = @bitmap
    return if @sprite.disposed? || !bmp || bmp.disposed?
    if kind == :charset
      fw = bmp.width / 4
      fh = bmp.height / 4
      pattern = (@frame / CustomizationSettings::PREVIEW_FRAME_TIME) % 4
      @sprite.src_rect.set(pattern * fw, FACING_ROWS[FACINGS[@facing]] * fh, fw, fh)
    else
      # Battle back sprites are 5-frame strips; trainer card sprites and derived graphics are whole
      frames = (bmp.width > bmp.height * 2) ? 5 : 1
      @sprite.src_rect.set(0, 0, bmp.width / frames, bmp.height)
    end
    @sprite.ox = @sprite.src_rect.width / 2
    @sprite.oy = @sprite.src_rect.height / 2
    @sprite.x  = rect.x + (width / 2)
    @sprite.y  = rect.y + (height / 2)
  end

  # @brief Draws the context name, the controls and a note when there is no art.
  # @param art_context [Symbol, nil]
  def draw_labels(art_context)
    clear
    center = width / 2
    base   = EditorStyle::LIGHT_BASE
    shadow = EditorStyle::LIGHT_SHADOW
    texts = [[_INTL("< {1} >", PlayerCompositor.context_name(@context)), center, 8, :center, base, shadow]]
    if !art_context
      texts.push([_INTL("No art for this view"), center, (height / 2) - 12, :center, base, shadow])
    elsif art_context != @context
      art_name = PlayerCompositor.context_name(art_context)
      texts.push([_INTL("(using {1} art)", art_name), center, 34, :center, base, shadow])
    end
    texts.push([_INTL("Action: change view"), center, height - 60, :center, base, shadow])
    texts.push([_INTL("Left/Right: turn"), center, height - 32, :center, base, shadow])
    pbDrawTextPositions(bitmap, texts)
  end
end

#==================================================================
# class EditorInfoPanel
#==================================================================
# @brief The info panel under the preview: describes the selected row, or shows the swatch
# grid or the fine-tune sliders while a color is being picked.
class EditorInfoPanel < EditorPanel
  SWATCH_SIZE = 20
  SWATCH_GAP  = 4
  LINE_HEIGHT = 26

  # @param rect [Rect]
  # @param viewport [Viewport]
  def initialize(rect, viewport)
    super(rect, viewport, :info)
  end

  # @brief Shows lines of text, each optionally led by a color swatch.
  # @param lines [Array] Each a String, [String, RegionColor] to draw the color in front, or
  #   [String, nil, Color] to draw the text in another color (e.g. prices).
  def show_lines(lines)
    clear
    texts = []
    lines.first(height / LINE_HEIGHT).each_with_index do |line, i|
      text, swatch, color = line.is_a?(Array) ? line : [line, nil, nil]
      y = 8 + (i * LINE_HEIGHT)
      x = 12
      if swatch
        draw_region_color(x, y + 4, swatch)
        x += SWATCH_SIZE + 8
      end
      texts.push([text, x, y, :left, color || EditorStyle::BASE_COLOR, EditorStyle::SHADOW_COLOR])
    end
    pbDrawTextPositions(bitmap, texts)
  end

  # @brief Draws the swatch grid with a cursor and the selected swatch's name.
  # @param swatches [Array<GameData::PlayerColor, nil>] nil is the "no color" choice.
  # @param index [Integer] Selected entry.
  # @param title [String] Shown above the grid.
  # @param more [Boolean] Whether to show the "Action: more" hint.
  def draw_swatch_grid(swatches, index, title, more = true)
    clear
    cell = SWATCH_SIZE + SWATCH_GAP
    cols = swatch_columns
    rows = 2
    top_row = [(index / cols) - rows + 1, 0].max
    swatches.each_with_index do |swatch, i|
      row = (i / cols) - top_row
      next if row < 0 || row >= rows
      x = 12 + ((i % cols) * cell)
      y = 32 + (row * cell)
      bitmap.fill_rect(x - 2, y - 2, SWATCH_SIZE + 4, SWATCH_SIZE + 4, EditorStyle::CURSOR_COLOR) if i == index
      draw_region_color(x, y, swatch)
    end
    label = swatches[index] ? swatches[index].name : _INTL("No color")
    texts = [
      [title, 12, 4, :left, EditorStyle::BASE_COLOR, EditorStyle::SHADOW_COLOR],
      [label, 12, 32 + (rows * cell), :left, EditorStyle::CURSOR_COLOR, EditorStyle::SHADOW_COLOR]
    ]
    if more
      texts.push([_INTL("Action: more"), width - 12, 32 + (rows * cell), :right,
                  EditorStyle::BASE_COLOR, EditorStyle::SHADOW_COLOR])
    end
    pbDrawTextPositions(bitmap, texts)
  end

  # @return [Integer] Number of swatches per row of the grid.
  def swatch_columns
    return [(width - 24) / (SWATCH_SIZE + SWATCH_GAP), 1].max
  end

  # @brief Draws the hue/saturation/value sliders.
  # @param adjust [ColorAdjust]
  # @param row [Integer] Selected slider (0-2).
  # @param title [String]
  def draw_sliders(adjust, row, title)
    clear
    bar_x = 112
    bar_w = width - 124
    sliders = [
      [_INTL("Hue"),        adjust.hue % 360,  0,    359],
      [_INTL("Saturation"), adjust.saturation, -100, 100],
      [_INTL("Value"),      adjust.value,      -100, 100]
    ]
    texts = [[title, 12, 4, :left, EditorStyle::BASE_COLOR, EditorStyle::SHADOW_COLOR]]
    sliders.each_with_index do |(name, value, min, max), i|
      y = 30 + (i * LINE_HEIGHT)
      selected = (i == row)
      texts.push([name, 12, y, :left, selected ? EditorStyle::CURSOR_COLOR : EditorStyle::BASE_COLOR,
                  EditorStyle::SHADOW_COLOR])
      bitmap.fill_rect(bar_x, y + 10, bar_w, 6, EditorStyle::SHADOW_COLOR)
      fill = ((value - min) * bar_w / (max - min).to_f).round
      bitmap.fill_rect(bar_x, y + 10, fill, 6, EditorStyle::BAR_COLOR)
      bitmap.fill_rect(bar_x + fill - 2, y + 6, 4, 14, selected ? EditorStyle::CURSOR_COLOR : EditorStyle::BASE_COLOR)
    end
    pbDrawTextPositions(bitmap, texts)
  end

  private

  def draw_background
    fill_box
  end

  # @brief Draws a small box filled with a region's color.
  # @param x [Integer]
  # @param y [Integer]
  # @param color [RegionColor, GameData::PlayerColor, nil] nil draws the "no color" box.
  def draw_region_color(x, y, color)
    swatch = color.is_a?(RegionColor) ? color.swatch_data : color
    bitmap.fill_rect(x, y, SWATCH_SIZE, SWATCH_SIZE, EditorStyle::BASE_COLOR)
    if swatch
      rgb = ColorMath.to_rgb(swatch.color)
      rgb = Recolor.transform(*rgb, color.adjust) if color.is_a?(RegionColor)
      bitmap.fill_rect(x + 2, y + 2, SWATCH_SIZE - 4, SWATCH_SIZE - 4, ColorMath.to_color(rgb))
    else
      # No swatch: the art keeps its own shades, shown as a struck-out box
      bitmap.fill_rect(x + 2, y + 2, SWATCH_SIZE - 4, SWATCH_SIZE - 4, EditorStyle::PANEL_COLOR)
      (SWATCH_SIZE - 4).times { |i| bitmap.fill_rect(x + 2 + i, y + 2 + i, 1, 1, EditorStyle::CURSOR_COLOR) }
    end
  end
end
