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
  def apply(bitmap, adjust)
    return if adjust.identity?
    memo = {}
    if bitmap.respond_to?(:raw_data)
      bytes = bitmap.raw_data.unpack("C*")
      (0...bytes.length).step(4) do |i|
        next if bytes[i + 3] == 0
        key = (bytes[i] << 16) | (bytes[i + 1] << 8) | bytes[i + 2]
        rgb = (memo[key] ||= transform(bytes[i], bytes[i + 1], bytes[i + 2], adjust))
        bytes[i], bytes[i + 1], bytes[i + 2] = rgb
      end
      bitmap.raw_data = bytes.pack("C*")
    else
      bitmap.height.times do |y|
        bitmap.width.times do |x|
          c = bitmap.get_pixel(x, y)
          next if c.alpha == 0
          key = (c.red.to_i << 16) | (c.green.to_i << 8) | c.blue.to_i
          r, g, b = (memo[key] ||= transform(c.red.to_i, c.green.to_i, c.blue.to_i, adjust))
          bitmap.set_pixel(x, y, Color.new(r, g, b, c.alpha))
        end
      end
    end
  end

  # @brief Transforms a single RGB color.
  # @return [Array<Integer>] The new [r, g, b].
  def transform(r, g, b, adjust)
    h, s, v = rgb_to_hsv(r, g, b)
    h = (h + adjust.hue) % 360
    s = shift(s, adjust.saturation / 100.0)
    v = shift(v, adjust.value / 100.0)
    return hsv_to_rgb(h, s, v)
  end

  # @brief Moves a 0-1 channel proportionally toward 1 (positive) or 0 (negative).
  # @param channel [Float] Current value, 0.0-1.0.
  # @param amount [Float] -1.0 to 1.0.
  # @return [Float]
  def shift(channel, amount)
    return amount >= 0 ? channel + (amount * (1 - channel)) : channel + (amount * channel)
  end

  # @brief Converts RGB (0-255) to HSV (h: 0-360, s/v: 0-1).
  # @return [Array<Float>]
  def rgb_to_hsv(r, g, b)
    r /= 255.0
    g /= 255.0
    b /= 255.0
    max = [r, g, b].max
    min = [r, g, b].min
    d = max - min
    h = if d == 0      then 0.0
        elsif max == r then 60 * (((g - b) / d) % 6)
        elsif max == g then 60 * (((b - r) / d) + 2)
        else                60 * (((r - g) / d) + 4)
        end
    s = (max == 0) ? 0.0 : d / max
    return [h, s, max]
  end

  # @brief Converts HSV back to RGB (0-255).
  # @return [Array<Integer>]
  def hsv_to_rgb(h, s, v)
    c = v * s
    x = c * (1 - (((h / 60.0) % 2) - 1).abs)
    m = v - c
    r, g, b = case (h / 60).floor % 6
              when 0 then [c, x, 0]
              when 1 then [x, c, 0]
              when 2 then [0, c, x]
              when 3 then [0, x, c]
              when 4 then [x, 0, c]
              else        [c, 0, x]
              end
    return [((r + m) * 255).round, ((g + m) * 255).round, ((b + m) * 255).round]
  end
end