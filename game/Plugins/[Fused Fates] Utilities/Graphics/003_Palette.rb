#================================================================================================
# Pokémon Fused Fates Utilities/Graphics - 003_Palette.rb
#================================================================================================

#==================================================================
# class Palette
#==================================================================
# @brief The distinct opaque colors of a bitmap and how often each is used.
class Palette
  include Enumerable

  # @brief Creates a palette from a list of colors (each counted once).
  # @param colors [Array<Color, Array<Integer>>]
  def initialize(colors = [])
    @counts = Hash.new(0)
    colors.each { |c| @counts[Pixels.color_key(*ColorMath.to_rgb(c))] += 1 }
  end

  # @brief Reads the palette of a bitmap.
  # @param bitmap [Bitmap]
  # @param rect [Rect, nil] Area to sample; nil for the whole bitmap.
  # @param ignore_outline [Boolean] Skip near-black colors (outlines).
  # @return [Palette]
  def self.from_bitmap(bitmap, rect = nil, ignore_outline: false)
    palette = Palette.new
    counts = palette.counts
    Pixels.each_opaque(bitmap, rect) do |_x, _y, r, g, b, _a|
      next if ignore_outline && [r, g, b].max < 40
      counts[Pixels.color_key(r, g, b)] += 1
    end
    return palette
  end

  # @return [Hash{Integer => Integer}] Packed 0xRRGGBB key => number of pixels.
  def counts
    return @counts
  end

  # @return [Integer] Number of distinct colors.
  def size
    return @counts.length
  end

  # @param color [Color, Array<Integer>]
  # @return [Integer] Number of pixels using exactly this color.
  def count_of(color)
    return @counts[Pixels.color_key(*ColorMath.to_rgb(color))]
  end

  # @param color [Color, Array<Integer>]
  # @return [Boolean]
  def include?(color)
    return @counts.key?(Pixels.color_key(*ColorMath.to_rgb(color)))
  end

  # @brief Yields each color as a Color, the most used first.
  def each(&block)
    to_a.each(&block)
  end

  # @return [Array<Color>] The most used first.
  def to_a
    return @counts.sort_by { |key, count| [-count, key] }.map { |key, _| ColorMath.to_color(Pixels.key_to_rgb(key)) }
  end

  # @brief Finds the palette color closest to a color.
  # @param color [Color, Array<Integer>]
  # @return [Array] [Color, squared distance], or nil if the palette is empty.
  def nearest(color)
    rgb = ColorMath.to_rgb(color)
    best_key = @counts.keys.min_by { |key| ColorMath.distance_sq(rgb, Pixels.key_to_rgb(key)) }
    return nil if !best_key
    best = Pixels.key_to_rgb(best_key)
    return [ColorMath.to_color(best), ColorMath.distance_sq(rgb, best)]
  end

  # @brief Groups the palette into shading ramps.
  # @param min_saturation [Float] Colors less saturated than this are grouped as grays.
  # @return [Array<Array<Color>>] Ramps (darkest first), the most used ramp first.
  def ramps(min_saturation: 0.12)
    return Ramp.group(@counts, min_saturation)
  end

  # @return [String]
  def inspect
    return "#<Palette #{size} colors>"
  end
end

#==================================================================
# module PaletteSwap
#==================================================================
# @brief Recolors bitmaps by replacing colors, rather than by rotating hues.
# Unlike Recolor, the result can use any colors at all, so a sprite can take on another
# species' exact palette.
module PaletteSwap
  module_function

  # @brief Normalizes a color map to packed source key => [r, g, b].
  # @param map [Hash] Source color => replacement color (Color, [r, g, b] or packed key).
  # @return [Hash{Integer => Array<Integer>}]
  def normalize(map)
    table = {}
    map.each { |from, to| table[Pixels.color_key(*ColorMath.to_rgb(from))] = ColorMath.to_rgb(to) }
    return table
  end

  # @brief Replaces exact colors in place; colors not in the map are left alone.
  # @param bitmap [Bitmap]
  # @param map [Hash] Source color => replacement color.
  # @param rect [Rect, nil] Area to change; nil for the whole bitmap.
  def apply(bitmap, map, rect = nil)
    table = normalize(map)
    return if table.empty?
    Pixels.map_colors!(bitmap, rect) { |r, g, b| table[Pixels.color_key(r, g, b)] }
  end

  # @brief Builds a color map that moves each source ramp onto a destination ramp.
  # Colors are matched by their position from dark to light, interpolating when the ramps
  # have different lengths, so a 3-color ramp can be mapped onto a 5-color one.
  # @param src_ramps [Array<Array>] Ramps found in the sprite (e.g. from Ramp.extract).
  # @param dst_ramps [Array<Array>] Replacement ramps, paired with src_ramps by index.
  # @return [Hash{Integer => Array<Integer>}] Ready for apply.
  def map_ramps(src_ramps, dst_ramps)
    table = {}
    src_ramps.each_with_index do |src, n|
      dst = dst_ramps[n]
      next if !dst || dst.empty?
      src = Ramp.sort(src)
      dst = Ramp.sort(dst).map { |c| ColorMath.to_rgb(c) }
      src.each_with_index do |color, i|
        pos = (src.length > 1) ? i * (dst.length - 1) / (src.length - 1).to_f : (dst.length - 1) / 2.0
        lo = pos.floor
        hi = [lo + 1, dst.length - 1].min
        table[Pixels.color_key(*ColorMath.to_rgb(color))] = ColorMath.lerp(dst[lo], dst[hi], pos - lo)
      end
    end
    return table
  end

  # @brief Moves each source ramp onto a destination ramp in place.
  # @see map_ramps
  def swap_ramps(bitmap, src_ramps, dst_ramps, rect = nil)
    apply(bitmap, map_ramps(src_ramps, dst_ramps), rect)
  end

  # @brief Snaps every color to the nearest color of a palette, in place.
  # @param bitmap [Bitmap]
  # @param palette [Palette, Array<Color>] Target colors.
  # @param tolerance [Numeric, nil] Colors further than this (RGB distance) are left alone; nil snaps everything.
  # @param rect [Rect, nil] Area to change; nil for the whole bitmap.
  def apply_nearest(bitmap, palette, tolerance = UtilitySettings::PALETTE_MATCH_TOLERANCE, rect = nil)
    targets = (palette.is_a?(Palette) ? palette.to_a : palette).map { |c| ColorMath.to_rgb(c) }
    return if targets.empty?
    limit = tolerance ? tolerance * tolerance : nil
    Pixels.map_colors!(bitmap, rect) do |r, g, b|
      rgb = [r, g, b]
      best = targets.min_by { |t| ColorMath.distance_sq(rgb, t) }
      next nil if limit && ColorMath.distance_sq(rgb, best) > limit
      next best
    end
  end

  # @brief Recolors by brightness: each pixel takes the ramp color at its luminance (a gradient map).
  # Good for tinting a grayscale sprite or forcing a sprite into one ramp.
  # @param bitmap [Bitmap]
  # @param ramp [Array<Color, Array<Integer>>] Darkest first.
  # @param rect [Rect, nil] Area to change; nil for the whole bitmap.
  def gradient_map(bitmap, ramp, rect = nil)
    colors = ramp.map { |c| ColorMath.to_rgb(c) }
    return if colors.empty?
    last = colors.length - 1
    Pixels.map_colors!(bitmap, rect) do |r, g, b|
      pos = ColorMath.luminance(r, g, b) / 255.0 * last
      lo = pos.floor.clamp(0, last)
      hi = [lo + 1, last].min
      next ColorMath.lerp(colors[lo], colors[hi], pos - lo)
    end
  end
end
