#================================================================================================
# Pokémon Fused Fates Fusion System - 012_Followers.rb
#================================================================================================

#==================================================================
# module FusionFollowers
#==================================================================
# Overworld (following Pokémon) sprites for fusions.
#
# A fusion follows the player using, in order of priority:
#   1. A custom charset in Graphics/Characters/Followers/Fusions/ (or "Followers shiny/Fusions/"),
#      named HEAD[_form]_BODY[_form].png
#   2. A charset spliced from the head's and body's own follower sprites
# FusionSettings::FOLLOWER_SPRITE_MODE chooses which of these are allowed.
#
# Spliced charsets use a virtual character name (see FusionSprites in 009_Sprites.rb), so
# nothing is written to disk and the name survives saving and loading.
module FusionFollowers
  CHARACTERS_FOLDER = "Graphics/Characters/"

  # @param pkmn [Pokemon, nil]
  # @return [String, nil] the character name (relative to Graphics/Characters/) to use for this
  #   Pokémon's follower, or nil to leave the follower plugin's own choice untouched
  def self.character_name_for(pkmn)
    return nil if !pkmn || pkmn.egg? || !FusionHandlers.fused?(pkmn)
    head, head_form, body, body_form, shiny = FusionSprites.pokemon_params(pkmn)
    mode = FusionSettings::FOLLOWER_SPRITE_MODE

    if mode != :splice
      custom = custom_character_name(head, head_form, body, body_form, shiny)
      return custom if custom
      # Custom-only mode falls back to the head's normal follower sprite
      return nil if mode == :custom
    end
    return FusionSprites.virtual_name(:follower, head, head_form, body, body_form, shiny)
  end

  # @return [String, nil] character name of a custom fusion follower sprite, if one exists
  def self.custom_character_name(head, head_form, body, body_form, shiny)
    folder = shiny ? FusionSettings::FOLLOWER_SHINY_FOLDER : FusionSettings::FOLLOWER_FOLDER
    path = FusionSprites.resolve_custom(CHARACTERS_FOLDER + folder + FusionSprites.pair_name(head, head_form, body, body_form))
    return nil if !path
    # Character names are relative to Graphics/Characters/ and have no extension
    return path.sub(CHARACTERS_FOLDER, "").sub(/\.(png|gif)\z/i, "")
  end

  # Loads a species' normal follower sprite
  # @return [Array(BitmapWrapper, Boolean), nil] the bitmap, and whether it is a real shiny sprite
  def self.load_species_follower(species, form, shiny)
    path = GameData::Species.check_graphic_file(CHARACTERS_FOLDER, species, form, 0, shiny, false,
                                                FusionSettings::FOLLOWER_BASE_FOLDER)
    # Ignore the "000" placeholder that check_graphic_file falls back to
    return nil if !path || File.basename(path, ".*") == "000"
    bmp = FusionSprites.load_source(path)
    return nil if !bmp
    return [bmp, shiny && path.include?(" shiny/")]
  end

  # Updates the active follower's graphic if it is a fusion
  # @param pkmn [Pokemon, nil] the following Pokémon (looked up from the follower plugin if nil)
  def self.apply_to_follower(pkmn = nil)
    return if !defined?(FollowingPkmn)
    pkmn ||= FollowingPkmn.get_pokemon if FollowingPkmn.respond_to?(:get_pokemon)
    name = character_name_for(pkmn)
    return if !name
    [:get_event, :get_data].each do |getter|
      next if !FollowingPkmn.respond_to?(getter)
      target = FollowingPkmn.send(getter)
      target.character_name = name if target.respond_to?(:character_name=)
    end
  end
end

#==================================================================
# Spliced follower generator
#==================================================================
# Splices every cell of the 4x4 charset: the top of the head's cell is drawn over the bottom of
# the body's cell, bottom-aligned so the feet stay on the tile. All four facing directions and
# walking frames line up because both source charsets share the same layout.
FusionSprites.register_generator(:follower) do |head, head_form, body, body_form, shiny, _back|
  head_data = FusionFollowers.load_species_follower(head, head_form, shiny)
  body_data = FusionFollowers.load_species_follower(body, body_form, shiny)
  if !head_data || !body_data
    head_data&.first&.dispose
    body_data&.first&.dispose
    next nil
  end
  head_bmp, head_real_shiny = head_data
  body_bmp, body_real_shiny = body_data

  # Cell sizes of each source and of the result (the larger of the two)
  head_cw, head_ch = head_bmp.width / 4, head_bmp.height / 4
  body_cw, body_ch = body_bmp.width / 4, body_bmp.height / 4
  cell_w, cell_h   = [head_cw, body_cw].max, [head_ch, body_ch].max

  ratio  = FusionSettings::FOLLOWER_HEAD_RATIO
  head_h = (head_ch * ratio).round
  body_h = body_ch - (body_ch * ratio).round

  canvas     = Compositor.new(cell_w * 4, cell_h * 4)
  head_layer = Bitmap.new(canvas.width, canvas.height)
  4.times do |row|
    4.times do |col|
      cell_x = col * cell_w
      cell_y = row * cell_h

      # Bottom of the body cell, bottom-aligned and centred in the result cell
      body_x = cell_x + ((cell_w - body_cw) / 2)
      body_y = cell_y + cell_h - body_h
      canvas.add_layer(body_bmp, body_x, body_y, src_rect: Rect.new(col * body_cw, (row * body_ch) + body_ch - body_h, body_cw, body_h))

      # Top of the head cell, resting directly on the body part
      head_x = cell_x + ((cell_w - head_cw) / 2)
      head_y = [body_y - head_h, cell_y].max
      head_layer.blt(head_x, head_y, head_bmp, Rect.new(col * head_cw, row * head_ch, head_cw, head_h))
    end
  end

  # Shift the head's colours towards the body's, sampling the first (down-facing) frame of each
  if FusionSettings::FOLLOWER_HUE_HARMONIZE
    FusionSprites.harmonize_hue(head_layer, Rect.new(0, 0, cell_w, cell_h),
                                body_bmp, Rect.new(0, body_ch - body_h, body_cw, body_h))
  end
  canvas.add_layer(head_layer)
  result = canvas.flatten
  head_layer.dispose

  # Generate shiny colours procedurally if either component has no shiny follower sprite
  if shiny && (!head_real_shiny || !body_real_shiny)
    result.hue_change(FusionSprites.procedural_shiny_offset(head, body))
  end

  head_bmp.dispose
  body_bmp.dispose
  next result
end

#==================================================================
# Following Pokémon EX compatibility
#==================================================================
# Only active when a follower plugin defining FollowingPkmn is installed (meta.txt lists it as
# an optional dependency so it loads first). Every call is guarded, so a different version of
# that plugin leaves fusion followers showing the head's sprite instead of crashing.
if defined?(FollowingPkmn)
  # class_eval on the singleton class works whether FollowingPkmn is a module or a class
  FollowingPkmn.singleton_class.class_eval do
    if method_defined?(:change_sprite) && !method_defined?(:fusion_change_sprite)
      alias_method :fusion_change_sprite, :change_sprite

      define_method(:change_sprite) do |pkmn = nil, *args|
        ret = fusion_change_sprite(pkmn, *args)
        FusionFollowers.apply_to_follower(pkmn)
        next ret
      end
    end
  end
end
