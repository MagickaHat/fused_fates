#================================================================================================
# Pokémon Fused Fates Utilities - 001_Core.rb
#================================================================================================

#==================================================================
# module ColorMath
#==================================================================
# @brief Color space conversions and color arithmetic shared by every graphics utility.
# Colors are passed as separate 0-255 channels, [r, g, b] arrays or Color objects.
module ColorMath
  module_function

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

  # @brief Moves a 0-1 channel proportionally toward 1 (positive) or 0 (negative).
  # @param channel [Float] Current value, 0.0-1.0.
  # @param amount [Float] -1.0 to 1.0.
  # @return [Float]
  def shift(channel, amount)
    return amount >= 0 ? channel + (amount * (1 - channel)) : channel + (amount * channel)
  end

  # @brief Rotates a hue toward a target hue along the shorter way round the color wheel.
  # @param hue [Float] Current hue in degrees.
  # @param target [Float] Hue to move toward.
  # @param degrees [Float] Largest rotation allowed.
  # @return [Float] The new hue (0-360).
  def hue_toward(hue, target, degrees)
    diff = ((target - hue + 540) % 360) - 180
    step = diff.clamp(-degrees.abs, degrees.abs)
    return (hue + step) % 360
  end

  # @brief Hue angle of a Color, ignoring saturation and value.
  # @param color [Color]
  # @return [Integer] Hue angle (0-360); 0 for grays.
  def hue_of(color)
    r, g, b = color.red, color.green, color.blue
    max, min = [r, g, b].max, [r, g, b].min
    delta = max - min
    return 0 if delta == 0 # It's a shade of gray

    hue = if max == r
            60.0 * (((g - b) / delta) % 6)
          elsif max == g
            60.0 * (((b - r) / delta) + 2)
          else
            60.0 * (((r - g) / delta) + 4)
          end
    return (hue < 0 ? hue + 360 : hue).round
  end

  # @brief Perceived brightness of a color (Rec. 601 weights).
  # @return [Float] 0.0-255.0
  def luminance(r, g, b)
    return (0.299 * r) + (0.587 * g) + (0.114 * b)
  end

  # @brief Squared RGB distance between two colors (compare against tolerance ** 2).
  # @param a [Array<Integer>] [r, g, b]
  # @param b [Array<Integer>] [r, g, b]
  # @return [Integer]
  def distance_sq(a, b)
    dr = a[0] - b[0]
    dg = a[1] - b[1]
    db = a[2] - b[2]
    return (dr * dr) + (dg * dg) + (db * db)
  end

  # @brief Linearly interpolates between two colors.
  # @param a [Array<Integer>] [r, g, b] at t = 0
  # @param b [Array<Integer>] [r, g, b] at t = 1
  # @param t [Float] 0.0-1.0
  # @return [Array<Integer>] [r, g, b]
  def lerp(a, b, t)
    return [0, 1, 2].map { |i| (a[i] + ((b[i] - a[i]) * t)).round }
  end

  # @brief Normalizes a color given in any supported form to [r, g, b].
  # @param color [Color, Array<Integer>, Integer] A Color, an [r, g, b(, a)] array or a packed 0xRRGGBB key.
  # @return [Array<Integer>]
  def to_rgb(color)
    case color
    when Array   then return [color[0].to_i, color[1].to_i, color[2].to_i]
    when Integer then return Pixels.key_to_rgb(color)
    end
    return [color.red.to_i, color.green.to_i, color.blue.to_i]
  end

  # @brief Builds a Color from [r, g, b].
  # @param rgb [Array<Integer>]
  # @param alpha [Integer]
  # @return [Color]
  def to_color(rgb, alpha = 255)
    return Color.new(rgb[0], rgb[1], rgb[2], alpha)
  end
end

#==================================================================
# module Pixels
#==================================================================
# @brief Fast whole-bitmap pixel access.
# Uses mkxp-z's Bitmap#raw_data (one RGBA byte string, rows top to bottom) when available and
# falls back to get_pixel/set_pixel otherwise, so every utility works on either engine.
module Pixels
  module_function

  # @brief Packs a color into a single Integer hash key.
  # @return [Integer] 0xRRGGBB
  def color_key(r, g, b)
    return (r << 16) | (g << 8) | b
  end

  # @brief Unpacks a key made by color_key.
  # @return [Array<Integer>] [r, g, b]
  def key_to_rgb(key)
    return [(key >> 16) & 0xFF, (key >> 8) & 0xFF, key & 0xFF]
  end

  # @brief Checks whether raw_data can be used on a bitmap.
  # @return [Boolean]
  def raw?(bitmap)
    return bitmap.respond_to?(:raw_data) && bitmap.respond_to?(:raw_data=)
  end

  # @brief Reads every pixel of a bitmap.
  # @param bitmap [Bitmap]
  # @return [Array<Integer>] Flat RGBA byte array, 4 entries per pixel, rows top to bottom.
  def read(bitmap)
    return bitmap.raw_data.unpack("C*") if raw?(bitmap)
    bytes = Array.new(bitmap.width * bitmap.height * 4, 0)
    i = 0
    bitmap.height.times do |y|
      bitmap.width.times do |x|
        c = bitmap.get_pixel(x, y)
        bytes[i]     = c.red.to_i
        bytes[i + 1] = c.green.to_i
        bytes[i + 2] = c.blue.to_i
        bytes[i + 3] = c.alpha.to_i
        i += 4
      end
    end
    return bytes
  end

  # @brief Writes a flat RGBA byte array (as returned by read) back into a bitmap.
  # @param bitmap [Bitmap]
  # @param bytes [Array<Integer>]
  def write(bitmap, bytes)
    if raw?(bitmap)
      bitmap.raw_data = bytes.pack("C*")
      return
    end
    i = 0
    bitmap.height.times do |y|
      bitmap.width.times do |x|
        bitmap.set_pixel(x, y, Color.new(bytes[i], bytes[i + 1], bytes[i + 2], bytes[i + 3]))
        i += 4
      end
    end
  end

  # @brief Clamps an optional rect to a bitmap.
  # @param bitmap [Bitmap]
  # @param rect [Rect, nil] nil means the whole bitmap.
  # @return [Array<Integer>] [x0, y0, x1, y1] with x1/y1 exclusive.
  def bounds(bitmap, rect = nil)
    return [0, 0, bitmap.width, bitmap.height] if !rect
    x0 = rect.x.clamp(0, bitmap.width)
    y0 = rect.y.clamp(0, bitmap.height)
    x1 = (rect.x + rect.width).clamp(x0, bitmap.width)
    y1 = (rect.y + rect.height).clamp(y0, bitmap.height)
    return [x0, y0, x1, y1]
  end

  # @brief Yields every pixel with alpha > 0.
  # @param bitmap [Bitmap]
  # @param rect [Rect, nil] Area to visit; nil for the whole bitmap.
  # @yieldparam x [Integer]
  # @yieldparam y [Integer]
  # @yieldparam r [Integer]
  # @yieldparam g [Integer]
  # @yieldparam b [Integer]
  # @yieldparam a [Integer]
  def each_opaque(bitmap, rect = nil)
    x0, y0, x1, y1 = bounds(bitmap, rect)
    bytes = read(bitmap)
    w = bitmap.width
    (y0...y1).each do |y|
      i = ((y * w) + x0) * 4
      (x0...x1).each do |x|
        yield(x, y, bytes[i], bytes[i + 1], bytes[i + 2], bytes[i + 3]) if bytes[i + 3] > 0
        i += 4
      end
    end
  end

  # @brief Replaces the RGB of every opaque pixel, leaving alpha untouched.
  # The block runs once per distinct color (results are memoized), so it can be expensive.
  # @param bitmap [Bitmap] Modified in place.
  # @param rect [Rect, nil] Area to change; nil for the whole bitmap.
  # @yieldparam r [Integer]
  # @yieldparam g [Integer]
  # @yieldparam b [Integer]
  # @yieldreturn [Array<Integer>, nil] The new [r, g, b], or nil to keep the color.
  def map_colors!(bitmap, rect = nil)
    memo = {}
    x0, y0, x1, y1 = bounds(bitmap, rect)
    if raw?(bitmap)
      bytes = read(bitmap)
      w = bitmap.width
      changed = false
      (y0...y1).each do |y|
        i = ((y * w) + x0) * 4
        (x1 - x0).times do
          if bytes[i + 3] != 0
            key = color_key(bytes[i], bytes[i + 1], bytes[i + 2])
            rgb = memo.key?(key) ? memo[key] : (memo[key] = yield(bytes[i], bytes[i + 1], bytes[i + 2]))
            if rgb
              bytes[i], bytes[i + 1], bytes[i + 2] = rgb
              changed = true
            end
          end
          i += 4
        end
      end
      write(bitmap, bytes) if changed
    else
      (y0...y1).each do |y|
        (x0...x1).each do |x|
          c = bitmap.get_pixel(x, y)
          next if c.alpha == 0
          r, g, b = c.red.to_i, c.green.to_i, c.blue.to_i
          key = color_key(r, g, b)
          rgb = memo.key?(key) ? memo[key] : (memo[key] = yield(r, g, b))
          bitmap.set_pixel(x, y, Color.new(rgb[0], rgb[1], rgb[2], c.alpha)) if rgb
        end
      end
    end
  end
end
