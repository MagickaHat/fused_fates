#================================================================================================
# Pokémon Fused Fates Utilities/Graphics - 004_Compositor.rb
#================================================================================================

#==================================================================
# class Layer
#==================================================================
# @brief One bitmap (or part of one) placed on a Compositor canvas.
class Layer
  attr_accessor :bitmap, :x, :y, :src_rect, :opacity, :blend, :mask, :visible

  # @brief Creates a layer.
  # @param bitmap [Bitmap] Source graphic; not disposed by the layer.
  # @param x [Integer] Canvas position of the source rect's top left corner.
  # @param y [Integer]
  # @param src_rect [Rect, nil] Part of the bitmap to draw; nil for all of it.
  # @param opacity [Integer] 0-255.
  # @param blend [Symbol] One of Compositor::BLEND_MODES.
  # @param mask [Bitmap, nil] Alpha mask the size of src_rect; its alpha scales this layer's alpha.
  def initialize(bitmap, x = 0, y = 0, src_rect: nil, opacity: 255, blend: :normal, mask: nil)
    @bitmap   = bitmap
    @x        = x
    @y        = y
    @src_rect = src_rect || Rect.new(0, 0, bitmap.width, bitmap.height)
    @opacity  = opacity
    @blend    = blend
    @mask     = mask
    @visible  = true
  end

  # @brief Checks whether the layer can be drawn with the engine's fast Bitmap#blt.
  # @return [Boolean]
  def simple?
    return @blend == :normal && !@mask
  end
end

#==================================================================
# class Compositor
#==================================================================
# @brief Stacks layers, bottom first, and flattens them into a single bitmap.
# :normal layers without masks use Bitmap#blt (fast). Other blend modes and masks are
# blended per pixel, so keep them to small graphics or cache the result.
class Compositor
  BLEND_MODES = [:normal, :multiply, :screen, :add, :overlay].freeze

  attr_reader :width, :height, :layers

  # @brief Creates an empty canvas.
  # @param width [Integer]
  # @param height [Integer]
  def initialize(width, height)
    @width  = width
    @height = height
    @layers = []
  end

  # @brief Adds a layer on top of the existing ones.
  # @see Layer#initialize for the parameters.
  # @return [Layer]
  def add_layer(bitmap, x = 0, y = 0, **options)
    layer = Layer.new(bitmap, x, y, **options)
    raise ArgumentError, "unknown blend mode #{layer.blend}" if !BLEND_MODES.include?(layer.blend)
    @layers.push(layer)
    return layer
  end

  # @brief Draws every visible layer onto a new bitmap.
  # @param klass [Class] Bitmap class to create (BitmapWrapper for use with RPG::Cache-style ref counting).
  # @return [Bitmap]
  def flatten(klass = BitmapWrapper)
    result = klass.new(@width, @height)
    draw_onto(result)
    return result
  end

  # @brief Draws every visible layer onto an existing bitmap.
  # @param dest [Bitmap]
  def draw_onto(dest)
    @layers.each do |layer|
      next if !layer.visible || layer.opacity <= 0
      if layer.simple?
        dest.blt(layer.x, layer.y, layer.bitmap, layer.src_rect, layer.opacity)
      else
        blend_layer(dest, layer)
      end
    end
  end

  # @brief Blends one channel of a source pixel over a destination pixel.
  # @param mode [Symbol] One of BLEND_MODES.
  # @param d [Integer] Destination channel, 0-255.
  # @param s [Integer] Source channel, 0-255.
  # @return [Integer]
  def self.blend_channel(mode, d, s)
    case mode
    when :multiply then return (d * s) / 255
    when :screen   then return 255 - (((255 - d) * (255 - s)) / 255)
    when :add      then return [d + s, 255].min
    when :overlay
      return (d < 128) ? (2 * d * s) / 255 : 255 - ((2 * (255 - d) * (255 - s)) / 255)
    end
    return s
  end

  private

  # @brief Blends a layer per pixel (any blend mode, optional mask).
  def blend_layer(dest, layer)
    rect = layer.src_rect
    dst  = Pixels.read(dest)
    src  = Pixels.read(layer.bitmap)
    mask = layer.mask ? Pixels.read(layer.mask) : nil
    src_w  = layer.bitmap.width
    mask_w = layer.mask ? layer.mask.width : 0
    mask_h = layer.mask ? layer.mask.height : 0
    rect.height.times do |row|
      sy = rect.y + row
      dy = layer.y + row
      next if sy < 0 || sy >= layer.bitmap.height || dy < 0 || dy >= @height
      rect.width.times do |col|
        sx = rect.x + col
        dx = layer.x + col
        next if sx < 0 || sx >= src_w || dx < 0 || dx >= @width
        si = ((sy * src_w) + sx) * 4
        sa = src[si + 3] * layer.opacity / 255
        if mask
          sa = (col < mask_w && row < mask_h) ? sa * mask[(((row * mask_w) + col) * 4) + 3] / 255 : 0
        end
        next if sa <= 0
        di = ((dy * @width) + dx) * 4
        da = dst[di + 3]
        under = (da * (255 - sa)) / 255   # How much of the destination shows through
        out_a = sa + under
        3.times do |c|
          d = dst[di + c]
          s = src[si + c]
          # Over transparent canvas there is nothing to blend with, so fade toward the plain source
          blended = ((s * (255 - da)) + (Compositor.blend_channel(layer.blend, d, s) * da)) / 255
          dst[di + c] = ((blended * sa) + (d * under)) / out_a
        end
        dst[di + 3] = out_a
      end
    end
    Pixels.write(dest, dst)
  end
end
