#================================================================================================
# Pokémon Fused Fates Utilities/Graphics - 006_RecolorCache.rb
#================================================================================================

#==================================================================
# module RecolorCache
#==================================================================
# @brief Loads recolored copies of graphics, recoloring each graphic/recolor pair only once.
# Works with any path RPG::Cache can load, including generated fusion graphics.
module RecolorCache
  @cache = BitmapLRU.new { UtilitySettings::RECOLOR_CACHE_SIZE }

  module_function

  # @brief Returns a recolored copy of a graphic.
  # A reference is added for the caller, who releases it with dispose.
  # @param path [String] Graphic path, e.g. "Graphics/Pokemon/Front/PIKACHU".
  # @param recolor [ColorAdjust, Hash] An HSV adjustment, or a color map for PaletteSwap.apply.
  # @return [BitmapWrapper, nil] nil if the graphic can't be loaded.
  def load(path, recolor)
    return @cache.fetch("#{path}|#{key_for(recolor)}") do
      next DevLog.guard("RecolorCache could not load #{path}") do
        src = RPG::Cache.load_bitmap("", path)
        bmp = BitmapWrapper.new(src.width, src.height)
        bmp.blt(0, 0, src, src.rect)
        src.dispose
        apply(bmp, recolor)
        next bmp
      end
    end
  end

  # @brief Recolors a bitmap in place with either kind of recolor.
  # @param bitmap [Bitmap]
  # @param recolor [ColorAdjust, Hash]
  def apply(bitmap, recolor)
    case recolor
    when ColorAdjust then Recolor.apply(bitmap, recolor)
    when Hash        then PaletteSwap.apply(bitmap, recolor)
    else                  raise ArgumentError, "unsupported recolor: #{recolor.class}"
    end
  end

  # @brief A stable string identifying a recolor.
  # @param recolor [ColorAdjust, Hash]
  # @return [String]
  def key_for(recolor)
    return recolor.key if recolor.is_a?(ColorAdjust)
    pairs = PaletteSwap.normalize(recolor).sort.map { |from, to| [from, Pixels.color_key(*to)] }
    return "map:" + Hex.crc32(pairs.flatten.pack("N*")).to_s(16)
  end

  # @brief Drops every cached bitmap.
  def clear
    @cache.clear
  end

  # @see BitmapLRU#stats
  # @return [Hash]
  def stats
    return @cache.stats
  end
end
