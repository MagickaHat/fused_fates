#================================================================================================
# Pokémon Fused Fates Utilities/Debug - 002_DebugMenu.rb
#================================================================================================

#==================================================================
# module UtilityDebug
#==================================================================
# @brief Shared helpers for the Utilities debug menu commands.
module UtilityDebug
  module_function

  # @brief Asks for a graphic path and loads it.
  # @return [Array] [path, BitmapWrapper] (the caller disposes the bitmap), or nil if cancelled or missing.
  def choose_graphic
    path = pbMessageFreeText(_INTL("Enter a graphic path (e.g. Graphics/Pokemon/Front/PIKACHU)."), "", false, 250, Graphics.width)
    return nil if !path || path.strip.empty?
    path = path.strip
    bitmap = DevLog.guard("Could not load #{path}") { RPG::Cache.load_bitmap("", path) }
    if !bitmap
      pbMessage(_INTL("Couldn't load {1}.", path))
      return nil
    end
    return [path, bitmap]
  end

  # @brief Describes a cache's statistics on one line.
  # @param name [String]
  # @param stats [Hash] As returned by BitmapLRU#stats.
  # @return [String]
  def stats_line(name, stats)
    return _INTL("{1}: {2}/{3} cached, {4} hits, {5} misses.", name, stats[:size], stats[:capacity],
                 stats[:hits], stats[:misses])
  end
end

#==================================================================
# Debug menu
#==================================================================
MenuHandlers.add(:debug_menu, :utilities_menu, {
  "name"        => _INTL("Utilities..."),
  "parent"      => :main,
  "description" => _INTL("Inspect and clear graphics caches, dump graphics and palettes."),
  "always_show" => false
})

MenuHandlers.add(:debug_menu, :utilities_cache_stats, {
  "name"        => _INTL("Show cache statistics"),
  "parent"      => :utilities_menu,
  "description" => _INTL("Show how many recolored and fusion graphics are cached."),
  "effect"      => proc {
    pbMessage(UtilityDebug.stats_line(_INTL("Recolor cache"), RecolorCache.stats))
    if defined?(FusionSprites) && FusionSprites.respond_to?(:cache_stats)
      pbMessage(UtilityDebug.stats_line(_INTL("Fusion sprite cache"), FusionSprites.cache_stats))
    end
  }
})

MenuHandlers.add(:debug_menu, :utilities_clear_caches, {
  "name"        => _INTL("Clear graphics caches"),
  "parent"      => :utilities_menu,
  "description" => _INTL("Forget recolored and generated fusion graphics (e.g. after editing sprites)."),
  "effect"      => proc {
    RecolorCache.clear
    FusionSprites.clear_cache if defined?(FusionSprites) && FusionSprites.respond_to?(:clear_cache)
    pbMessage(_INTL("Graphics caches cleared."))
  }
})

MenuHandlers.add(:debug_menu, :utilities_dump_graphic, {
  "name"        => _INTL("Dump graphic to PNG"),
  "parent"      => :utilities_menu,
  "description" => _INTL("Save any graphic, including generated fusion graphics, as a PNG file."),
  "effect"      => proc {
    path, bitmap = UtilityDebug.choose_graphic
    next if !bitmap
    file = SpriteUtils.dump(bitmap, File.basename(path))
    bitmap.dispose
    pbMessage(file ? _INTL("Saved {1}.", file) : _INTL("The graphic couldn't be saved."))
  }
})

MenuHandlers.add(:debug_menu, :utilities_palette, {
  "name"        => _INTL("Print graphic palette"),
  "parent"      => :utilities_menu,
  "description" => _INTL("List a graphic's colors and shading ramps in the console."),
  "effect"      => proc {
    path, bitmap = UtilityDebug.choose_graphic
    next if !bitmap
    palette = Palette.from_bitmap(bitmap)
    bitmap.dispose
    Console.echo_h2("Palette of #{path}", text: :white)
    palette.counts.sort_by { |_key, count| -count }.each do |key, count|
      Console.echoln("#{ColorMath.to_color(Pixels.key_to_rgb(key)).to_hex}  #{count}")
    end
    palette.ramps.each_with_index do |ramp, i|
      Console.echoln("Ramp #{i + 1}: " + ramp.map(&:to_hex).join(" "))
    end
    pbMessage(_INTL("{1} colors in {2} ramps. See the console for the list.", palette.size, palette.ramps.length))
  }
})
