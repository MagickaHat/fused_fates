#================================================================================================
# Pokémon Fused Fates Utilities/Graphics - 001_ColorAdjust.rb
#================================================================================================

#==================================================================
# class ColorAdjust
#==================================================================
# @brief A hue/saturation/value adjustment for one color region.
class ColorAdjust
  attr_accessor :hue, :saturation, :value

  # @brief Creates an adjustment.
  # @param hue [Integer] Rotation in degrees (0-359).
  # @param saturation [Integer] -100 to 100.
  # @param value [Integer] -100 to 100.
  def initialize(hue = 0, saturation = 0, value = 0)
    @hue = hue
    @saturation = saturation
    @value = value
  end

  # @brief Checks whether this adjustment changes nothing.
  # @return [Boolean]
  def identity?
    return @hue % 360 == 0 && @saturation == 0 && @value == 0
  end

  # @brief A stable string identifying this adjustment (used as a cache key).
  # @return [String]
  def key
    return "hsv:#{@hue % 360},#{@saturation},#{@value}"
  end

  # @brief Checks whether two adjustments have the same effect.
  # @return [Boolean]
  def ==(other)
    return other.is_a?(ColorAdjust) && key == other.key
  end
  alias eql? ==

  # @return [Integer]
  def hash
    return key.hash
  end

  # @brief Packs this adjustment into a short code players can share.
  # @return [String]
  def to_code
    return Serializer.pack_code([@hue % 360, @saturation, @value])
  end

  # @brief Rebuilds an adjustment from a code made by to_code.
  # @param code [String]
  # @return [ColorAdjust, nil] nil if the code is invalid.
  def self.from_code(code)
    values = Serializer.unpack_code(code)
    return nil if !values || values.length != 3
    return ColorAdjust.new(values[0] % 360, values[1].clamp(-100, 100), values[2].clamp(-100, 100))
  end

  # @return [String]
  def inspect
    return "#<ColorAdjust #{key}>"
  end
end

#==================================================================
# module Recolor
#==================================================================
# @brief Recolors bitmaps in HSV space while preserving shading ramps.
module Recolor
  module_function

  # @brief Applies an adjustment to a bitmap in place.
  # @param bitmap [Bitmap] The layer to recolor.
  # @param adjust [ColorAdjust] The adjustment to apply.
  # @param rect [Rect, nil] Only recolor this area (e.g. a fusion's head); nil for the whole bitmap.
  def apply(bitmap, adjust, rect = nil)
    return if adjust.identity?
    Pixels.map_colors!(bitmap, rect) { |r, g, b| transform(r, g, b, adjust) }
  end

  # @brief Applies an adjustment to one area of a bitmap in place.
  # @param bitmap [Bitmap]
  # @param rect [Rect]
  # @param adjust [ColorAdjust]
  def apply_rect(bitmap, rect, adjust)
    apply(bitmap, adjust, rect)
  end

  # @brief Transforms a single RGB color.
  # @return [Array<Integer>] The new [r, g, b].
  def transform(r, g, b, adjust)
    h, s, v = ColorMath.rgb_to_hsv(r, g, b)
    h = (h + adjust.hue) % 360
    s = ColorMath.shift(s, adjust.saturation / 100.0)
    v = ColorMath.shift(v, adjust.value / 100.0)
    return ColorMath.hsv_to_rgb(h, s, v)
  end

  # @brief Moves a 0-1 channel proportionally toward 1 (positive) or 0 (negative).
  # @see ColorMath.shift
  def shift(channel, amount)
    return ColorMath.shift(channel, amount)
  end

  # @brief Converts RGB (0-255) to HSV (h: 0-360, s/v: 0-1).
  # @see ColorMath.rgb_to_hsv
  def rgb_to_hsv(r, g, b)
    return ColorMath.rgb_to_hsv(r, g, b)
  end

  # @brief Converts HSV back to RGB (0-255).
  # @see ColorMath.hsv_to_rgb
  def hsv_to_rgb(h, s, v)
    return ColorMath.hsv_to_rgb(h, s, v)
  end
end
