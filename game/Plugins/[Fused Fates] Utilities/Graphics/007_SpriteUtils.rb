#================================================================================================
# Pokémon Fused Fates Utilities/Graphics - 007_SpriteUtils.rb
#================================================================================================

#==================================================================
# module SpriteUtils
#==================================================================
# @brief Helpers for slicing, measuring and transforming sprite graphics.
# Methods that return a bitmap always return a new one (the caller disposes it) and never
# modify their input, unless their name ends in "!".
module SpriteUtils
  module_function

  #----------------------------------------------------------------
  # Sheets and frames
  #----------------------------------------------------------------
  # @brief Splits a sheet into frames of a fixed size, left to right then top to bottom.
  # @param bitmap [Bitmap]
  # @param frame_width [Integer]
  # @param frame_height [Integer] Defaults to the bitmap's height (a single row).
  # @return [Array<Rect>]
  def frames(bitmap, frame_width, frame_height = bitmap.height)
    cols = [bitmap.width / frame_width, 1].max
    rows = [bitmap.height / frame_height, 1].max
    return Array.new(cols * rows) { |i| Rect.new((i % cols) * frame_width, (i / cols) * frame_height, frame_width, frame_height) }
  end

  # @brief Splits a sheet into a grid of equally sized cells (e.g. 4x4 for overworld characters).
  # @param bitmap [Bitmap]
  # @param cols [Integer]
  # @param rows [Integer]
  # @return [Array<Rect>] Row by row.
  def grid(bitmap, cols, rows)
    return frames(bitmap, bitmap.width / cols, bitmap.height / rows)
  end

  # @brief Number of square frames in a horizontal strip (party icons, animated battlers).
  # @param bitmap [Bitmap]
  # @return [Integer]
  def frame_count(bitmap)
    return [bitmap.width / [bitmap.height, 1].max, 1].max
  end

  # @brief Copies part of a bitmap into a new bitmap of exactly that size.
  # @param bitmap [Bitmap]
  # @param rect [Rect]
  # @param klass [Class] Bitmap class to create.
  # @return [Bitmap]
  def slice(bitmap, rect, klass = Bitmap)
    ret = klass.new([rect.width, 1].max, [rect.height, 1].max)
    ret.blt(0, 0, bitmap, rect)
    return ret
  end

  #----------------------------------------------------------------
  # Measuring
  #----------------------------------------------------------------
  # @brief Smallest rect containing every visible pixel.
  # @param bitmap [Bitmap]
  # @param threshold [Integer] Pixels with alpha at or below this count as empty.
  # @return [Rect, nil] nil if the bitmap is fully transparent.
  def opaque_bounds(bitmap, threshold = 0)
    bytes = Pixels.read(bitmap)
    w = bitmap.width
    min_x, min_y, max_x, max_y = w, bitmap.height, -1, -1
    (3...bytes.length).step(4) do |i|
      next if bytes[i] <= threshold
      pixel = i / 4
      x = pixel % w
      y = pixel / w
      min_x = x if x < min_x
      max_x = x if x > max_x
      min_y = y if y < min_y
      max_y = y if y > max_y
    end
    return nil if max_x < 0
    return Rect.new(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)
  end

  # @brief Copies a bitmap without its transparent border.
  # @param bitmap [Bitmap]
  # @return [Bitmap, nil] nil if the bitmap is fully transparent.
  def trim(bitmap)
    rect = opaque_bounds(bitmap)
    return rect ? slice(bitmap, rect) : nil
  end

  # @brief Median hue of the colorful pixels in a region, sampled on a 10x10 grid.
  # Transparent, near-black (outline), near-white (highlight) and gray pixels are ignored.
  # @param bitmap [Bitmap]
  # @param rect [Rect]
  # @return [Integer] Hue angle (0-360), or 0 if no colorful pixel was found.
  def dominant_hue(bitmap, rect)
    hues = []
    step_x = [rect.width / 10, 1].max
    step_y = [rect.height / 10, 1].max

    (rect.y...(rect.y + rect.height)).step(step_y) do |y|
      (rect.x...(rect.x + rect.width)).step(step_x) do |x|
        color = bitmap.get_pixel(x, y)
        next if color.alpha < 255 # Ignore transparent background

        max, min = [color.red, color.green, color.blue].max, [color.red, color.green, color.blue].min
        # Ignore outlines (blacks), highlights (whites), and neutral grays
        next if (max - min) < 20 || max < 40 || max > 240

        hues << ColorMath.hue_of(color)
      end
    end

    return 0 if hues.empty?
    hues.sort!
    return hues[hues.size / 2] # Return median hue to avoid stray pixel outliers
  end

  #----------------------------------------------------------------
  # Transforming
  #----------------------------------------------------------------
  # @brief Mirrors a bitmap left to right.
  # @param bitmap [Bitmap]
  # @return [Bitmap]
  def flip_h(bitmap)
    ret = Bitmap.new(bitmap.width, bitmap.height)
    bitmap.width.times { |x| ret.blt(bitmap.width - 1 - x, 0, bitmap, Rect.new(x, 0, 1, bitmap.height)) }
    return ret
  end

  # @brief Mirrors a bitmap top to bottom.
  # @param bitmap [Bitmap]
  # @return [Bitmap]
  def flip_v(bitmap)
    ret = Bitmap.new(bitmap.width, bitmap.height)
    bitmap.height.times { |y| ret.blt(0, bitmap.height - 1 - y, bitmap, Rect.new(0, y, bitmap.width, 1)) }
    return ret
  end

  # @brief Scales a bitmap by a whole number factor without blurring.
  # @param bitmap [Bitmap]
  # @param factor [Integer]
  # @return [Bitmap]
  def scale_nearest(bitmap, factor)
    factor = [factor.to_i, 1].max
    ret = Bitmap.new(bitmap.width * factor, bitmap.height * factor)
    Pixels.each_opaque(bitmap) do |x, y, r, g, b, a|
      ret.fill_rect(x * factor, y * factor, factor, factor, Color.new(r, g, b, a))
    end
    return ret
  end

  # @brief Fills every visible pixel with one color, keeping the alpha (in place).
  # @param bitmap [Bitmap]
  # @param color [Color, Array<Integer>]
  # @return [Bitmap] The same bitmap.
  def silhouette!(bitmap, color)
    rgb = ColorMath.to_rgb(color)
    Pixels.map_colors!(bitmap) { |_r, _g, _b| rgb }
    return bitmap
  end

  # @brief A one-color copy of a bitmap (shadows, "Who's that Pokémon?" reveals).
  # @param bitmap [Bitmap]
  # @param color [Color, Array<Integer>]
  # @return [Bitmap]
  def silhouette(bitmap, color = Color.new(0, 0, 0))
    return silhouette!(slice(bitmap, bitmap.rect), color)
  end

  # @brief Draws an outline around the visible pixels.
  # The result is 2 * thickness larger in each direction so the outline is never clipped.
  # @param bitmap [Bitmap]
  # @param color [Color]
  # @param thickness [Integer]
  # @param diagonal [Boolean] Also grow diagonally (rounder, heavier corners).
  # @return [Bitmap]
  def outline(bitmap, color = Color.new(0, 0, 0), thickness = 1, diagonal = false)
    t = [thickness.to_i, 1].max
    w = bitmap.width + (2 * t)
    h = bitmap.height + (2 * t)
    ret = Bitmap.new(w, h)
    ret.blt(t, t, bitmap, bitmap.rect)
    bytes = Pixels.read(ret)
    filled = Array.new(w * h) { |i| bytes[(i * 4) + 3] > 0 }
    rgba = ColorMath.to_rgb(color) + [color.is_a?(Color) ? color.alpha.to_i : 255]
    offsets = [[-1, 0], [1, 0], [0, -1], [0, 1]]
    offsets += [[-1, -1], [1, -1], [-1, 1], [1, 1]] if diagonal
    t.times do
      grow = []
      h.times do |y|
        w.times do |x|
          next if filled[(y * w) + x]
          touching = offsets.any? do |dx, dy|
            nx = x + dx
            ny = y + dy
            nx >= 0 && ny >= 0 && nx < w && ny < h && filled[(ny * w) + nx]
          end
          grow.push((y * w) + x) if touching
        end
      end
      grow.each do |i|
        filled[i] = true
        bytes[i * 4, 4] = rgba
      end
    end
    Pixels.write(ret, bytes)
    return ret
  end

  # @brief Adds a flat drop shadow behind a sprite.
  # The result grows by the offset so the shadow is never clipped.
  # @param bitmap [Bitmap]
  # @param offset_x [Integer]
  # @param offset_y [Integer]
  # @param color [Color] Shadow color; its alpha is the shadow's opacity.
  # @return [Bitmap]
  def drop_shadow(bitmap, offset_x = 2, offset_y = 2, color = Color.new(0, 0, 0, 96))
    shadow = silhouette(bitmap, color)
    canvas = Compositor.new(bitmap.width + offset_x.abs, bitmap.height + offset_y.abs)
    canvas.add_layer(shadow, [offset_x, 0].max, [offset_y, 0].max, opacity: color.alpha.to_i)
    canvas.add_layer(bitmap, [-offset_x, 0].max, [-offset_y, 0].max)
    ret = canvas.flatten(Bitmap)
    shadow.dispose
    return ret
  end

  #----------------------------------------------------------------
  # Debugging
  #----------------------------------------------------------------
  # @brief Saves a bitmap as a PNG in UtilitySettings::DUMP_FOLDER (needs mkxp-z's Bitmap#to_file).
  # @param bitmap [Bitmap]
  # @param name [String, nil] File name without extension; defaults to a timestamp.
  # @return [String, nil] The file written, or nil if it couldn't be saved.
  def dump(bitmap, name = nil)
    if !bitmap.respond_to?(:to_file)
      DevLog.warn("SpriteUtils.dump needs Bitmap#to_file (mkxp-z)")
      return nil
    end
    name ||= Time.now.strftime("%Y%m%d_%H%M%S_%L")
    path = UtilitySettings::DUMP_FOLDER + name.to_s.gsub(/[^\w\-]+/, "_") + ".png"
    return DevLog.guard("SpriteUtils.dump could not write #{path}") do
      DevLog.ensure_dir(UtilitySettings::DUMP_FOLDER)
      bitmap.to_file(path)
      DevLog.info("Saved #{path}")
      next path
    end
  end
end
