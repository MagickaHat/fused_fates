#================================================================================================
# Pokémon Fused Fates Utilities/Graphics - 002_Ramp.rb
#================================================================================================

#==================================================================
# module Ramp
#==================================================================
# @brief Builds and extracts shading ramps: lists of colors ordered from darkest to lightest.
module Ramp
  # Hue that shadows drift toward (blue-violet)
  SHADOW_HUE    = 250
  # Hue that highlights drift toward (yellow)
  HIGHLIGHT_HUE = 55
  # Hue bucket width in degrees used by extract
  BUCKET_DEGREES = 30

  module_function

  # @brief Generates a pixel-art style ramp around a base color.
  # Darker steps gain saturation and rotate toward cool hues, lighter steps lose saturation
  # and rotate toward warm hues, so the ramp reads as lit rather than just tinted.
  # @param base [Color, Array<Integer>] Middle color of the ramp.
  # @param steps [Integer] Number of colors (at least 2); the base sits in the middle.
  # @param hue_shift [Numeric] Degrees the end colors rotate toward SHADOW_HUE/HIGHLIGHT_HUE.
  # @param contrast [Float] 0.0-1.0; how far the end colors move toward black/white.
  # @return [Array<Color>] Darkest first.
  def generate(base, steps = 5, hue_shift: UtilitySettings::RAMP_HUE_SHIFT, contrast: 0.7)
    steps = [steps.to_i, 2].max
    h, s, v = ColorMath.rgb_to_hsv(*ColorMath.to_rgb(base))
    gray = (s == 0)   # Grays have no hue to shift, so they stay neutral
    mid = (steps - 1) / 2.0
    return Array.new(steps) do |i|
      t = (i - mid) / mid   # -1.0 (darkest) to 1.0 (lightest)
      step_v = ColorMath.shift(v, t * contrast)
      step_s = gray ? s : ColorMath.shift(s, -t * contrast * 0.5)
      step_h = gray ? h : ColorMath.hue_toward(h, t < 0 ? SHADOW_HUE : HIGHLIGHT_HUE, hue_shift * t.abs)
      next ColorMath.to_color(ColorMath.hsv_to_rgb(step_h, step_s.clamp(0.0, 1.0), step_v.clamp(0.0, 1.0)))
    end
  end

  # @brief Builds a straight RGB gradient between two colors.
  # @param from [Color, Array<Integer>]
  # @param to [Color, Array<Integer>]
  # @param steps [Integer] Number of colors (at least 2), including both ends.
  # @return [Array<Color>]
  def between(from, to, steps)
    steps = [steps.to_i, 2].max
    a = ColorMath.to_rgb(from)
    b = ColorMath.to_rgb(to)
    return Array.new(steps) { |i| ColorMath.to_color(ColorMath.lerp(a, b, i / (steps - 1).to_f)) }
  end

  # @brief Sorts colors from darkest to lightest.
  # @param colors [Array<Color, Array<Integer>>]
  # @return [Array] The same objects, sorted.
  def sort(colors)
    return colors.sort_by { |c| ColorMath.luminance(*ColorMath.to_rgb(c)) }
  end

  # @brief Finds the shading ramps used in a bitmap by grouping its colors by hue.
  # @param bitmap [Bitmap]
  # @param rect [Rect, nil] Area to sample; nil for the whole bitmap.
  # @param min_saturation [Float] Colors less saturated than this are grouped as grays.
  # @param ignore_outline [Boolean] Skip near-black colors (outlines).
  # @return [Array<Array<Color>>] Ramps (darkest first), the most used ramp first.
  def extract(bitmap, rect = nil, min_saturation: 0.12, ignore_outline: true)
    return Palette.from_bitmap(bitmap, rect, ignore_outline: ignore_outline).ramps(min_saturation: min_saturation)
  end

  # @brief Groups packed colors into hue ramps.
  # @param counts [Hash{Integer => Integer}] Packed 0xRRGGBB key => number of pixels.
  # @param min_saturation [Float] Colors less saturated than this are grouped as grays.
  # @return [Array<Array<Color>>] Ramps (darkest first), the most used ramp first.
  def group(counts, min_saturation = 0.12)
    buckets = {}
    counts.each do |key, count|
      rgb = Pixels.key_to_rgb(key)
      h, s, = ColorMath.rgb_to_hsv(*rgb)
      bucket = (s < min_saturation) ? :gray : ((h + (BUCKET_DEGREES / 2)) / BUCKET_DEGREES).floor % (360 / BUCKET_DEGREES)
      (buckets[bucket] ||= [0, []])[0] += count
      buckets[bucket][1].push(rgb)
    end
    ramps = buckets.values.sort_by { |total, _| -total }
    return ramps.map { |_total, colors| sort(colors).map { |rgb| ColorMath.to_color(rgb) } }
  end
end
