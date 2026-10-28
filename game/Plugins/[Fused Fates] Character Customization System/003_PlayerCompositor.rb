#================================================================================================
# Pokémon Fused Fates Character Customization System - 003_PlayerCompositor.rb
#================================================================================================

#==================================================================
# module PlayerCompositor
#==================================================================
# @brief Builds the player's sprites by stacking and coloring the worn parts.
#
# Composited sprites are addressed by "virtual" paths containing VIRTUAL_TAG, the same way the
# Fusion System serves fusion graphics: RPG::Cache.load_bitmap is hooked (see 006_EngineHooks.rb)
# so that loading one returns the composited bitmap. Each path names a context and a digest of
# the appearance, so changing clothes gives a new path and the engine's sprites reload on their own.
#
# Part art lives in CustomizationSettings::ROOT/<context>/<graphic>_<region>[_back].png. A context
# only counts as having art when every part in CustomizationSettings::REQUIRED_SLOTS has its first
# region there; otherwise its fallback context is tried, and then the stock sprite is used.
module PlayerCompositor
  VIRTUAL_TAG = "__custom__/"

  # Largest number of appearances remembered for virtual paths (the current one, the load
  # screen's, the editor's preview...)
  REGISTRY_SIZE = 8

  @cache    = BitmapLRU.new { CustomizationSettings::CACHE_SIZE }   # "context|signature" => BitmapWrapper
  @registry = {}   # Appearance digest => PlayerAppearance snapshot (oldest first)
  @resolved = {}   # Layer path => resolved file, or false if missing
  @generation = 0   # Bumped by clear_cache so sprites showing old bitmaps get new paths

  #----------------------------------------------------------------
  # Art lookup
  #----------------------------------------------------------------
  # @brief File path of one layer of a part, without extension.
  # @param context [Symbol]
  # @param part [GameData::PlayerPart]
  # @param region [Integer] 1-based region number.
  # @param suffix [String] "" for the front layer, "_back" for the layer drawn behind everything.
  # @return [String]
  def self.layer_path(context, part, region, suffix = "")
    return CustomizationSettings::ROOT + "#{context}/#{part.graphic}_#{region}#{suffix}"
  end

  # @brief Finds a layer file, remembering the answer between calls.
  # @param path [String] As returned by layer_path.
  # @return [String, nil] The resolved file, or nil if it doesn't exist.
  def self.resolve(path)
    @resolved[path] = (pbResolveBitmap(path) || false) if !@resolved.key?(path)
    return @resolved[path] || nil
  end

  # @brief Checks whether an appearance can be drawn in a context with that context's own art.
  # @param context [Symbol]
  # @param appearance [PlayerAppearance]
  # @return [Boolean]
  def self.has_art?(context, appearance)
    base = CustomizationSettings::REQUIRED_SLOTS.filter_map { |slot| appearance.part_for(slot) }
    base = appearance.worn_parts if base.empty?
    return false if base.empty?
    return base.all? { |part| part.supports?(context) && resolve(layer_path(context, part, 1)) }
  end

  # @brief The context whose art an appearance is drawn with, following fallbacks.
  # @param context [Symbol] A key of CustomizationSettings::CONTEXTS.
  # @param appearance [PlayerAppearance]
  # @return [Symbol, nil] nil if no art exists and the stock sprite should be used.
  def self.art_context(context, appearance)
    seen = []
    while context && !seen.include?(context)
      return context if has_art?(context, appearance)
      seen.push(context)
      context = CustomizationSettings::CONTEXTS.dig(context, :fallback)
    end
    return nil
  end

  #----------------------------------------------------------------
  # Virtual paths
  #----------------------------------------------------------------
  # @brief The virtual graphic name for an appearance in a context.
  # @param context [Symbol]
  # @param appearance [PlayerAppearance]
  # @return [String, nil] e.g. "__custom__/walk/1a2b3c4d-0" (relative to a Graphics folder), or
  #   nil if there is no art and the stock sprite should be used.
  def self.virtual_name(context, appearance)
    art = art_context(context, appearance)
    return nil if !art
    return VIRTUAL_TAG + "#{art}/#{register(appearance)}-#{@generation}"
  end

  # @param path [String]
  # @return [Boolean] Whether the path refers to a composited player graphic.
  def self.virtual?(path)
    return path.is_a?(String) && path.include?(VIRTUAL_TAG)
  end

  # @brief Remembers an appearance so its virtual paths can be loaded later.
  # @param appearance [PlayerAppearance]
  # @return [String] The appearance's digest.
  def self.register(appearance)
    digest = appearance.digest
    old = @registry.delete(digest)
    @registry[digest] = (old && old.signature == appearance.signature) ? old : appearance.snapshot
    @registry.shift while @registry.length > REGISTRY_SIZE
    return digest
  end

  # @brief Returns the bitmap for a virtual path. A reference is added for the caller.
  # @param path [String]
  # @return [BitmapWrapper, nil]
  def self.load_virtual(path)
    context, name = path[(path.index(VIRTUAL_TAG) + VIRTUAL_TAG.length)..-1].split("/", 2)
    digest = name.to_s.split("-", 2)[0]
    appearance = @registry[digest]
    appearance ||= $player.appearance if $player && $player.appearance.digest == digest
    return nil if !appearance || !CustomizationSettings::CONTEXTS.key?(context.to_sym)
    return bitmap_for(context.to_sym, appearance)
  end

  #----------------------------------------------------------------
  # Cache
  #----------------------------------------------------------------
  # @brief Returns the composited bitmap for a context, building it if needed.
  # A reference is added for the caller, who releases it with dispose.
  # @param context [Symbol]
  # @param appearance [PlayerAppearance]
  # @return [BitmapWrapper, nil] nil if there is no art for the context or its fallbacks.
  def self.bitmap_for(context, appearance)
    art = art_context(context, appearance)
    return nil if !art
    return @cache.fetch("#{art}|#{appearance.signature}") do
      next DevLog.guard("Could not composite the player's #{art} sprite") { compose(art, appearance) }
    end
  end

  # @brief Forgets every composited bitmap and which layer files exist
  # (e.g. after adding art while the game is running).
  def self.clear_cache
    @cache.clear
    @resolved.clear
    @generation += 1
  end

  # @see BitmapLRU#stats
  # @return [Hash]
  def self.cache_stats
    return @cache.stats
  end

  #----------------------------------------------------------------
  # Compositing
  #----------------------------------------------------------------
  # @brief Stacks every worn part into one bitmap.
  # Parts in hidden slots and parts without art for the context are skipped; every "_back"
  # layer is drawn before any front layer.
  # @param context [Symbol] Sprite context (the art subfolder).
  # @param appearance [PlayerAppearance] The choices to render.
  # @return [BitmapWrapper, nil] nil if no layer could be loaded.
  def self.compose(context, appearance)
    hidden = appearance.hidden_slots
    parts = appearance.worn_parts.select { |part| part.supports?(context) && !hidden.include?(part.slot) }
    layers = []
    begin
      ["_back", ""].each do |suffix|
        parts.each { |part| draw_part(layers, context, part, appearance, suffix) }
      end
      return nil if layers.empty?
      canvas = Compositor.new(layers.map(&:width).max, layers.map(&:height).max)
      layers.each { |bmp| canvas.add_layer(bmp) }
      return canvas.flatten
    ensure
      layers.each(&:dispose)
    end
  end

  # @brief Loads and colors every region layer of a part.
  # @param layers [Array<Bitmap>] Receives the colored layers (the caller disposes them).
  # @param context [Symbol]
  # @param part [GameData::PlayerPart]
  # @param appearance [PlayerAppearance]
  # @param suffix [String] "" or "_back".
  def self.draw_part(layers, context, part, appearance, suffix)
    (1..part.color_slots).each do |region|
      file = resolve(layer_path(context, part, region, suffix))
      next if !file
      src = RPG::Cache.load_bitmap("", file)
      bmp = Bitmap.new(src.width, src.height)
      bmp.blt(0, 0, src, src.rect)
      src.dispose
      colorize(bmp, appearance.color_for(part.slot, region))
      layers.push(bmp)
    end
  end

  # @brief Colors a grayscale layer in place: each shade takes the swatch ramp color at its
  # brightness, then the fine-tune adjustment is applied.
  # Near-black outlines keep their color so the sprite stays crisp.
  # @param bitmap [Bitmap]
  # @param color [RegionColor]
  def self.colorize(bitmap, color)
    swatch = color.swatch_data
    if swatch
      ramp = swatch.ramp.map { |c| ColorMath.to_rgb(c) }
      last = ramp.length - 1
      Pixels.map_colors!(bitmap) do |r, g, b|
        lum = ColorMath.luminance(r, g, b)
        next nil if lum < CustomizationSettings::OUTLINE_LUMINANCE
        pos = lum / 255.0 * last
        lo = pos.floor.clamp(0, last)
        hi = [lo + 1, last].min
        next ColorMath.lerp(ramp[lo], ramp[hi], pos - lo)
      end
    end
    Recolor.apply(bitmap, color.adjust)
  end
end
