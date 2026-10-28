#================================================================================================
# Pokémon Fused Fates Fusion System - 009_Sprites.rb
#================================================================================================

#==================================================================
# module FusionSprites
#==================================================================
# Fusion graphics are addressed by "virtual" paths containing VIRTUAL_TAG. They never exist
# on disk: RPG::Cache.load_bitmap is hooked so that loading one returns a generated bitmap.
# This lets every engine sprite class (party icons, PC icons, summary, battlers, overworld
# characters) display fusions with its own animation and disposal logic, and means each
# fusion graphic is generated once and then reused from a small LRU cache.
module FusionSprites
  VIRTUAL_TAG  = "__fusion__/"
  VIRTUAL_ROOT = "Graphics/" + VIRTUAL_TAG

  @cache         = {}   # Virtual path => BitmapWrapper (oldest first)
  @custom_lookup = {}   # Candidate file path => resolved path, or false if missing
  @generators    = {}   # Kind => proc { |params| BitmapWrapper or nil }

  #----------------------------------------------------------------
  # Virtual paths
  #----------------------------------------------------------------
  # @param kind [Symbol] :battler, :icon or :follower
  # @param head [Symbol] head species
  # @param head_form [Integer] head form
  # @param body [Symbol] body species
  # @param body_form [Integer] body form
  # @param shiny [Boolean]
  # @param back [Boolean]
  # @return [String] virtual path under VIRTUAL_TAG (relative to "Graphics/")
  def self.virtual_name(kind, head, head_form, body, body_form, shiny = false, back = false)
    return VIRTUAL_TAG + "#{kind}/" + [head, head_form.to_i, body, body_form.to_i, shiny ? 1 : 0, back ? 1 : 0].join(",")
  end

  # @param path [String]
  # @return [Boolean] whether the path refers to a generated fusion graphic
  def self.virtual?(path)
    return path.is_a?(String) && path.include?(VIRTUAL_TAG)
  end

  # @param path [String] a virtual path
  # @return [Array, nil] [kind, head, head_form, body, body_form, shiny, back]
  def self.parse(path)
    rest = path[(path.index(VIRTUAL_TAG) + VIRTUAL_TAG.length)..-1]
    kind, values = rest.split("/", 2)
    parts = values.to_s.split(",")
    return nil if parts.length < 6
    return [kind.to_sym, parts[0].to_sym, parts[1].to_i, parts[2].to_sym, parts[3].to_i,
            parts[4] == "1", parts[5] == "1"]
  end

  #----------------------------------------------------------------
  # Cache
  #----------------------------------------------------------------
  # Registers the proc that draws a kind of virtual graphic
  # @param kind [Symbol]
  def self.register_generator(kind, &block)
    @generators[kind] = block
  end

  # Returns the bitmap for a virtual path, generating it if needed.
  # A reference is added for the caller, who releases it with dispose.
  # @param path [String] a virtual path
  # @return [BitmapWrapper, nil]
  def self.load_virtual(path)
    bmp = @cache.delete(path)
    bmp = nil if bmp&.disposed?
    if !bmp
      params = parse(path)
      generator = params && @generators[params[0]]
      return nil if !generator
      begin
        bmp = generator.call(*params[1..-1])
      rescue StandardError => e
        Console.echo_warn("Fusion graphic #{path} could not be generated: #{e.message}") if $DEBUG
        bmp = nil
      end
      return nil if !bmp
    end
    @cache[path] = bmp   # Re-inserting marks it as the most recently used
    trim_cache
    bmp.addRef
    return bmp
  end

  # Releases the oldest cached bitmaps beyond FusionSettings::SPRITE_CACHE_SIZE
  def self.trim_cache
    while @cache.length > FusionSettings::SPRITE_CACHE_SIZE
      _path, old = @cache.shift
      old.dispose if old && !old.disposed?
    end
  end

  # Releases every generated bitmap and forgets which custom files exist
  # (e.g. after adding custom sprites while the game is running)
  def self.clear_cache
    @cache.each_value { |bmp| bmp.dispose if !bmp.disposed? }
    @cache.clear
    @custom_lookup.clear
  end

  # @param path [String] file path without extension
  # @return [String, nil] the resolved file path, remembered between calls
  def self.resolve_custom(path)
    @custom_lookup[path] = (pbResolveBitmap(path) || false) if !@custom_lookup.key?(path)
    return @custom_lookup[path] || nil
  end

  # @return [String] HEAD[_form]_BODY[_form]
  def self.pair_name(head, head_form, body, body_form)
    head_str = (head_form > 0) ? "#{head}_#{head_form}" : head.to_s
    body_str = (body_form > 0) ? "#{body}_#{body_form}" : body.to_s
    return "#{head_str}_#{body_str}"
  end

  # @param pkmn [FusedPokemon]
  # @return [Array] [head, head_form, body, body_form, shiny]
  def self.pokemon_params(pkmn)
    return [pkmn.fusion_head, pkmn.component_form(:head), pkmn.fusion_body, pkmn.component_form(:body), pkmn.shiny?]
  end

  #----------------------------------------------------------------
  # Battler and icon paths
  #----------------------------------------------------------------
  # @return [String] custom battle sprite path, or a virtual path for a stitched sprite
  def self.battler_path(head, head_form, body, body_form, shiny = false, back = false)
    filename = pair_name(head, head_form, body, body_form)
    filename += "_back" if back
    filename += "_shiny" if shiny
    custom = resolve_custom(FusionSettings::SPRITE_FOLDER + filename)
    return custom || ("Graphics/" + virtual_name(:battler, head, head_form, body, body_form, shiny, back))
  end

  # @return [String] custom icon path, or a virtual path for a stitched icon
  def self.icon_path(head, head_form, body, body_form, shiny = false)
    filename = pair_name(head, head_form, body, body_form)
    filename += "_shiny" if shiny
    custom = resolve_custom(FusionSettings::ICON_FOLDER + filename)
    return custom || ("Graphics/" + virtual_name(:icon, head, head_form, body, body_form, shiny))
  end

  # Loads a real graphic, bypassing the virtual path hook
  # @return [BitmapWrapper, nil]
  def self.load_source(path)
    return nil if !path || !pbResolveBitmap(path)
    return RPG::Cache.load_bitmap("", path)
  end

  #----------------------------------------------------------------
  # Colour helpers
  #----------------------------------------------------------------
  # Converts a Color object (RGB) into a Hue angle (0-360)
  def self.rgb_to_hue(color)
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

  # Samples a 10x10 grid of a bitmap region to find the median hue
  # @return [Integer] hue angle (0-360)
  def self.get_dominant_hue(bitmap, rect)
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

        hues << rgb_to_hue(color)
      end
    end

    return 0 if hues.empty?
    hues.sort!
    return hues[hues.size / 2] # Return median hue to avoid stray pixel outliers
  end

  # Shifts the colours of the head region towards the body region's dominant hue
  # @param bitmap [Bitmap] bitmap holding the head region (modified in place)
  # @param head_rect [Rect] region of bitmap to sample for the head's hue
  # @param body_bmp [Bitmap] source of the body's hue
  # @param body_rect [Rect] region of body_bmp to sample
  def self.harmonize_hue(bitmap, head_rect, body_bmp, body_rect)
    hue_offset = (get_dominant_hue(body_bmp, body_rect) - get_dominant_hue(bitmap, head_rect)) % 360
    bitmap.hue_change(hue_offset) if hue_offset != 0
  end

  # Deterministic hue shift for procedural shinies, so a fusion pair always gets the same colours
  # @return [Integer] hue angle (0-360)
  def self.procedural_shiny_offset(head, body)
    offset = (head.to_s.sum + body.to_s.sum) % 360
    # If the hue is too close to the original colour, push it outward so it looks distinct
    offset = (offset + 120) % 360 if offset < 45 || offset > 315
    return offset
  end
end

#==================================================================
# Generators
#==================================================================
# Stitched battle sprite: top half of the head over the bottom half of the body
FusionSprites.register_generator(:battler) do |head, head_form, body, body_form, shiny, back|
  head_path = GameData::Species.sprite_filename(head, head_form, 0, shiny, false, back)
  body_path = GameData::Species.sprite_filename(body, body_form, 0, shiny, false, back)

  # If a shiny was requested but the normal sprites were found, generate the shiny colours procedurally
  is_procedural_shiny = shiny &&
                        (head_path == GameData::Species.sprite_filename(head, head_form, 0, false, false, back) ||
                         body_path == GameData::Species.sprite_filename(body, body_form, 0, false, false, back))

  head_bmp = FusionSprites.load_source(head_path)
  body_bmp = FusionSprites.load_source(body_path)
  if !head_bmp || !body_bmp
    head_bmp&.dispose
    body_bmp&.dispose
    next nil
  end

  # Create a unified canvas matching the max dimensions
  width  = [head_bmp.width, body_bmp.width].max
  height = [head_bmp.height, body_bmp.height].max
  result = BitmapWrapper.new(width, height)

  # Draw the bottom half of the body sprite
  body_slice_height = body_bmp.height / 2
  body_rect = Rect.new(0, body_slice_height, body_bmp.width, body_bmp.height - body_slice_height)
  body_x = (width - body_bmp.width) / 2
  body_y = ((height - body_bmp.height) / 2) + body_slice_height
  result.blt(body_x, body_y, body_bmp, body_rect)

  # Copy the top half of the head sprite and harmonize it with the body's colours
  head_slice = Bitmap.new(head_bmp.width, head_bmp.height / 2)
  head_slice.blt(0, 0, head_bmp, Rect.new(0, 0, head_bmp.width, head_slice.height))
  FusionSprites.harmonize_hue(head_slice, head_slice.rect, body_bmp, body_rect)
  result.blt((width - head_slice.width) / 2, (height - body_bmp.height) / 2, head_slice, head_slice.rect)
  head_slice.dispose

  # Procedural Shiny Harmonization
  result.hue_change(FusionSprites.procedural_shiny_offset(head, body)) if is_procedural_shiny

  # Release the source sprites (they are reference counted by RPG::Cache)
  head_bmp.dispose
  body_bmp.dispose
  next result
end

# Stitched party icon, keeping every animation frame of both components
FusionSprites.register_generator(:icon) do |head, head_form, body, body_form, shiny, _back|
  head_bmp = FusionSprites.load_source(GameData::Species.icon_filename(head, head_form, 0, shiny))
  body_bmp = FusionSprites.load_source(GameData::Species.icon_filename(body, body_form, 0, shiny))
  if !head_bmp || !body_bmp
    head_bmp&.dispose
    body_bmp&.dispose
    next nil
  end

  frame_size  = [head_bmp.height, body_bmp.height].min
  head_frames = [head_bmp.width / frame_size, 1].max
  body_frames = [body_bmp.width / frame_size, 1].max
  num_frames  = [head_frames, body_frames, 2].max
  half        = frame_size / 2

  result = BitmapWrapper.new(frame_size * num_frames, frame_size)
  num_frames.times do |i|
    x = i * frame_size
    # Bottom half from the body, top half from the head, straight from the source frames
    result.blt(x, half, body_bmp, Rect.new((i % body_frames) * frame_size, half, frame_size, frame_size - half))
    result.blt(x, 0, head_bmp, Rect.new((i % head_frames) * frame_size, 0, frame_size, half))
  end

  head_bmp.dispose
  body_bmp.dispose
  next result
end

#==================================================================
# module RPG::Cache
#==================================================================
module RPG
  module Cache
    class << self
      alias_method :fusion_load_bitmap, :load_bitmap unless method_defined?(:fusion_load_bitmap)

      # Serves generated fusion graphics for virtual paths; everything else loads normally
      def load_bitmap(folder_name, filename, hue = 0)
        path = "#{folder_name}#{filename}"
        if FusionSprites.virtual?(path)
          bmp = FusionSprites.load_virtual(path)
          return bmp if bmp
          return fusion_load_bitmap("", "")   # Blank placeholder if the graphic can't be made
        end
        return fusion_load_bitmap(folder_name, filename, hue)
      end
    end
  end
end

#==================================================================
# module GameData class Species
#==================================================================
module GameData
  class Species
    class << self
      alias_method :fusion_sprite_bitmap_from_pokemon, :sprite_bitmap_from_pokemon unless method_defined?(:fusion_sprite_bitmap_from_pokemon)
      alias_method :fusion_icon_filename_from_pokemon, :icon_filename_from_pokemon unless method_defined?(:fusion_icon_filename_from_pokemon)
      alias_method :fusion_icon_bitmap_from_pokemon, :icon_bitmap_from_pokemon unless method_defined?(:fusion_icon_bitmap_from_pokemon)

      # Used by battlers, the summary screen and every other PokemonSprite
      def sprite_bitmap_from_pokemon(pkmn, back = false, species = nil)
        return fusion_sprite_bitmap_from_pokemon(pkmn, back, species) if pkmn.egg? || !FusionHandlers.fused?(pkmn)
        head, head_form, body, body_form, shiny = FusionSprites.pokemon_params(pkmn)
        if species
          # A specific species was requested (e.g. the evolution scene showing the evolved form)
          parts = species.to_s.split("_", 2)
          return fusion_sprite_bitmap_from_pokemon(pkmn, back, species) unless parts.length == 2 &&
                                                                              GameData::Species.exists?(parts[1].to_sym)
          head, body = parts[0].to_sym, parts[1].to_sym
        end
        return AnimatedBitmap.new(FusionSprites.battler_path(head, head_form, body, body_form, shiny, back))
      end

      # Used by party icons (PokemonIconSprite) and PC box icons (PokemonBoxIcon)
      def icon_filename_from_pokemon(pkmn)
        return fusion_icon_filename_from_pokemon(pkmn) if pkmn.egg? || !FusionHandlers.fused?(pkmn)
        return FusionSprites.icon_path(*FusionSprites.pokemon_params(pkmn))
      end

      def icon_bitmap_from_pokemon(pkmn)
        return fusion_icon_bitmap_from_pokemon(pkmn) if pkmn.egg? || !FusionHandlers.fused?(pkmn)
        return AnimatedBitmap.new(icon_filename_from_pokemon(pkmn)).deanimate
      end
    end

    # Kept for compatibility: returns a bitmap the caller must dispose
    def self.fusion_sprite_bitmap(head_id, body_id, head_form = 0, body_form = 0, shiny = false, back = false)
      path = FusionSprites.battler_path(head_id, head_form, body_id, body_form, shiny, back)
      return RPG::Cache.load_bitmap("", path)
    end

    # Kept for compatibility: returns a bitmap the caller must dispose
    def self.fusion_icon_bitmap(head_id, head_form, body_id, body_form, shiny = false)
      return RPG::Cache.load_bitmap("", FusionSprites.icon_path(head_id, head_form, body_id, body_form, shiny))
    end
  end
end
