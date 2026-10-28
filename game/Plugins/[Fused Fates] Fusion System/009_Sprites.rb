#================================================================================================
# Pokémon Fused Fates Fusion System - 009_Sprites.rb
#================================================================================================

#==================================================================
# module GameData class Species
#==================================================================
module GameData
  class Species
    # Converts an RGSS3 Color object (RGB) into a Hue angle (0-360)
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

    # Samples a bitmap region to find the median hue
    def self.get_dominant_hue(bitmap, rect)
      hues = []
      # Sample a 10x10 grid to maintain 60 FPS performance
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

    # Resolves or generates a fusion sprite bitmap 
    def self.fusion_sprite_bitmap(head_id, body_id, head_form = 0, body_form = 0, shiny = false, back = false)
      head_str = head_form > 0 ? "#{head_id}_#{head_form}" : "#{head_id}"
      body_str = body_form > 0 ? "#{body_id}_#{body_form}" : "#{body_id}"

      folder = "Graphics/Pokemon/Fusions/"
      filename = "#{head_str}_#{body_str}"
      filename += "_back" if back
      filename += "_shiny" if shiny
      
      # Check for custom asprite
      path = pbResolveBitmap(folder + filename)
      return RPG::Cache.load_bitmap(folder, filename) if path
      
      # Procedural Stitched Fallback with Hue Harmonization
      return generate_procedural_fusion_bitmap(head_id, head_form, body_id, body_form, shiny, back)    
    end

    def self.generate_procedural_fusion_bitmap(head_id, head_form, body_id, body_form, shiny, back)
      # Retrieve base species file paths
      head_path = GameData::Species.sprite_filename(head_id, head_form, 0, shiny, false, back)
      body_path = GameData::Species.sprite_filename(body_id, body_form, 0, shiny, false, back)
      
      normal_head_path = GameData::Species.sprite_filename(head_id, 0, 0, false, false, back)
      normal_body_path = GameData::Species.sprite_filename(body_id, 0, 0, false, false, back)
      
      # If the game requested a shiny, but loaded the normal paths, generate the shiny colors procedurally
      is_procedural_shiny = shiny && (head_path == normal_head_path || body_path == normal_body_path)
      
      head_bmp = pbResolveBitmap(head_path) ? RPG::Cache.load_bitmap("", head_path) : nil
      body_bmp = pbResolveBitmap(body_path) ? RPG::Cache.load_bitmap("", body_path) : nil
      
      return nil unless head_bmp && body_bmp

      # Create a unified canvas matching the max dimensions
      width = [head_bmp.width, body_bmp.width].max
      height = [head_bmp.height, body_bmp.height].max
      result_bmp = Bitmap.new(width, height)

      # Isolate and draw the bottom region of the body sprite
      body_slice_height = body_bmp.height / 2
      body_rect = Rect.new(0, body_slice_height, body_bmp.width, body_bmp.height - body_slice_height)
      
      body_x = (width - body_bmp.width) / 2
      body_y = ((height - body_bmp.height) / 2) + body_slice_height
      
      result_bmp.blt(body_x, body_y, body_bmp, body_rect)

      # Isolate the upper region of the head sprite
      head_slice_height = head_bmp.height / 2
      head_rect = Rect.new(0, 0, head_bmp.width, head_slice_height)
      
      head_clone = Bitmap.new(head_bmp.width, head_slice_height)
      head_clone.blt(0, 0, head_bmp, head_rect)
      
      # Apply a procedural hue shift to harmonize the head with the body's color profile
      head_hue = get_dominant_hue(head_clone, Rect.new(0, 0, head_clone.width, head_clone.height))
      body_hue = get_dominant_hue(body_bmp, body_rect)
      
      hue_offset = (body_hue - head_hue) % 360
      head_clone.hue_change(hue_offset) if hue_offset != 0

      # Add the modified head onto the upper portion of the canvas
      head_x = (width - head_clone.width) / 2
      head_y = (height - body_bmp.height) / 2
      result_bmp.blt(head_x, head_y, head_clone, head_clone.rect)

      # Procedural Shiny Harmonization
      if is_procedural_shiny
        # Calculate a deterministic shift based on the species' internal symbol strings (e.g., :PIKACHU)
        # This ensures that this exact fusion pair always generates the exact same shiny color
        shiny_offset = (head_id.to_s.sum + body_id.to_s.sum) % 360
        
        # If the math results in a hue too close to the original color, push it outward to ensure it looks distinct
        if shiny_offset < 45 || shiny_offset > 315
          shiny_offset = (shiny_offset + 120) % 360 
        end
        
        # Apply the final shiny shift to the completed, harmonized sprite
        result_bmp.hue_change(shiny_offset)
      end

      # Clean up temporary memory allocations to prevent memory leaks
      head_clone.dispose
      head_bmp.dispose unless head_bmp == body_bmp
      body_bmp.dispose

      return result_bmp
    end
  
    # Resolves or generates a procedural fusion party icon bitmap
    def self.fusion_icon_bitmap(head_id, head_form, body_id, body_form, shiny = false)
      head_str = head_form > 0 ? "#{head_id}_#{head_form}" : "#{head_id}"
      body_str = body_form > 0 ? "#{body_id}_#{body_form}" : "#{body_id}"

      folder = "Graphics/Pokemon/Fusion Icons/"
      filename = "#{head_str}_#{body_str}"
      filename += "_shiny" if shiny
      
      path = pbResolveBitmap(folder + filename)
      return RPG::Cache.load_bitmap(folder, filename) if path
      
      head_path = GameData::Species.icon_filename(head_id, head_form, 0, shiny)
      body_path = GameData::Species.icon_filename(body_id, body_form, 0, shiny)
      
      head_bmp = pbResolveBitmap(head_path) ? RPG::Cache.load_bitmap("", head_path) : nil
      body_bmp = pbResolveBitmap(body_path) ? RPG::Cache.load_bitmap("", body_path) : nil
      
      return nil unless head_bmp && body_bmp

      frame_size = [head_bmp.height, body_bmp.height].min
      head_frames = [head_bmp.width / frame_size, 1].max
      body_frames = [body_bmp.width / frame_size, 1].max
      num_frames = [head_frames, body_frames, 2].max

      result_bmp = Bitmap.new(frame_size * num_frames, frame_size)

      num_frames.times do |i|
        h_frame_idx = i % head_frames
        b_frame_idx = i % body_frames

        head_single = Bitmap.new(frame_size, frame_size)
        head_single.blt(0, 0, head_bmp, Rect.new(h_frame_idx * frame_size, 0, frame_size, frame_size))
        
        body_single = Bitmap.new(frame_size, frame_size)
        body_single.blt(0, 0, body_bmp, Rect.new(b_frame_idx * frame_size, 0, frame_size, frame_size))

        frame_result = Bitmap.new(frame_size, frame_size)

        body_slice_height = frame_size / 2
        body_rect = Rect.new(0, body_slice_height, frame_size, frame_size - body_slice_height)
        frame_result.blt(0, body_slice_height, body_single, body_rect)

        head_slice_height = frame_size / 2
        head_rect = Rect.new(0, 0, frame_size, head_slice_height)
        head_clone = Bitmap.new(frame_size, head_slice_height)
        head_clone.blt(0, 0, head_single, head_rect)

        frame_result.blt(0, 0, head_clone, head_clone.rect)

        result_bmp.blt(i * frame_size, 0, frame_result, frame_result.rect)

        head_clone.dispose
        head_single.dispose
        body_single.dispose
        frame_result.dispose
      end

      head_bmp.dispose unless head_bmp == body_bmp
      body_bmp.dispose

      return result_bmp
    end
  end
end

class FusionBitmapWrapper
  attr_reader :bitmap

  def initialize(custom_bitmap)
    @bitmap = custom_bitmap
  end

  # These dimensional methods are crucial for pbSetPosition to work
  def width; return @bitmap ? @bitmap.width : 0; end
  def height; return @bitmap ? @bitmap.height : 0; end
  
  # Dummy methods to prevent update loops from panicking
  def update; end
  def dispose
    @bitmap.dispose if @bitmap && !@bitmap.disposed?
  end
  def disposed?; return @bitmap ? @bitmap.disposed? : true; end
  def totalFrames; return 1; end
  def currentIndex; return 0; end
  def length; return 1; end
end

#==================================================================
# class Battle::Scene::BattlerSprite < RPG::Sprite
#==================================================================
class Battle::Scene::BattlerSprite < RPG::Sprite
  alias_method :fusion_setPokemonBitmap, :setPokemonBitmap unless method_defined?(:fusion_setPokemonBitmap)

  def setPokemonBitmap(pkmn, back = false)
    @pkmn = pkmn

    if pkmn.respond_to?(:fused?) && pkmn.fused?
      # Clear standard animated bitmaps to prevent visual tearing
      @_iconBitmap&.dispose if @_iconBitmap

      # Extract forms safely
      head_form = pkmn.original_head_data ? pkmn.original_head_data.form : 0
      body_form = pkmn.original_body_data ? pkmn.original_body_data.form : 0
      
      custom_bitmap = GameData::Species.fusion_sprite_bitmap(pkmn.fusion_head, pkmn.fusion_body, head_form, body_form, pkmn.shiny?, back)

      @_iconBitmap = FusionBitmapWrapper.new(custom_bitmap)

      self.bitmap = @_iconBitmap.bitmap
      self.visible = true
      self.opacity = 255

      pbSetPosition
    else
      # Fallback to standard rendering for normal Pokémon
      fusion_setPokemonBitmap(pkmn, back)
    end
  end
end

#==================================================================
# class PokemonSprite < Sprite
#==================================================================
class PokemonSprite < Sprite
  alias_method :fusion_setPokemonBitmap, :setPokemonBitmap unless method_defined?(:fusion_setPokemonBitmap)

  def setPokemonBitmap(pokemon, back = false)
    # Aggressive State Reset
    @_iconbitmap&.dispose if defined?(@_iconbitmap)
    @_iconbitmap = nil
    
    # Catch nil slots (empty PC slots) explicitly
    if !pokemon
      self.bitmap = nil
      return
    end

    # Render Fused Pokémon
    if pokemon.respond_to?(:fused?) && pokemon.fused?
      begin        
        # ID Fallbacks
        head_id = (pokemon.respond_to?(:fusion_head) && pokemon.fusion_head) ? pokemon.fusion_head : pokemon.species
        body_id = (pokemon.respond_to?(:fusion_body) && pokemon.fusion_body) ? pokemon.fusion_body : pokemon.species
        
        # Form extraction 
        head_form = (pokemon.respond_to?(:original_head_data) && pokemon.original_head_data) ? pokemon.original_head_data.form : 0
        body_form = (pokemon.respond_to?(:original_body_data) && pokemon.original_body_data) ? pokemon.original_body_data.form : 0
        
        shiny = pokemon.respond_to?(:shiny?) ? pokemon.shiny? : false
        
        # Generate the fusion bitmap
        bmp = GameData::Species.fusion_sprite_bitmap(head_id, body_id, head_form, body_form, shiny, back)
        
        # Unconditional canvas assignment
        self.bitmap = bmp || nil
        
        # Safe Origin Adjustment
        changeOrigin if self.bitmap && respond_to?(:changeOrigin)
        
      rescue => error
        # If the fusion data throws an error, wipe the canvas instead of ghosting
        self.bitmap = nil
      end
      return
    end

    # Fallback to the original method for standard Pokémon
    fusion_setPokemonBitmap(pokemon, back)
  end
end

#==================================================================
# class PokemonIconSprite < Sprite
#==================================================================
class PokemonIconSprite < Sprite
  alias_method :fusion_pokemon_equals, :pokemon= unless method_defined?(:fusion_pokemon_equals)
  
  def pokemon=(pkmn)
    @anim_frames = nil
    @frames_count = nil
    @anim_ticker = 0
    @current_frame = 0

    if pkmn.respond_to?(:fused?) && pkmn.fused?
      @pokemon = pkmn
      @animBitmap&.dispose
      @animBitmap = nil

      head_form = @pokemon.original_head_data ? @pokemon.original_head_data.form : 0
      body_form = @pokemon.original_body_data ? @pokemon.original_body_data.form : 0

      bitmap = GameData::Species.fusion_icon_bitmap(
        @pokemon.fusion_head, head_form, 
        @pokemon.fusion_body, body_form, 
        @pokemon.shiny?
      )
      
      if bitmap
        self.bitmap = bitmap
        
        # Constrain the viewable area to a single frame
        self.src_rect = Rect.new(0, 0, bitmap.height, bitmap.height)
        
        # Initialize animation variables
        @anim_frames = bitmap.width / bitmap.height
        @frames_count = @anim_frames
        @anim_ticker = 0
        @current_frame = 0
      end
      return
    end
    fusion_pokemon_equals(pkmn)
  end

  alias_method :fusion_update_frame, :update_frame unless method_defined?(:fusion_update_frame)

  def update_frame
    fusion_update_frame if respond_to?(:fusion_update_frame)

    # Prevent crashes when the sprite updates before a Pokemon is assigned
    return if !@pokemon

    if @pokemon.fainted?
      @current_frame = 0
      return
    end
    
    duration = ANIMATION_DURATION
    if @pokemon.hp <= @pokemon.totalhp / 4      # Red HP - 1 second
      duration *= 4
    elsif @pokemon.hp <= @pokemon.totalhp / 2   # Yellow HP - 0.5 seconds
      duration *= 2
    end
    
    # Safe fallback to prevent secondary crashes
    frames = @frames_count || @anim_frames || 2
    @current_frame = (frames * (System.uptime % duration) / duration).floor
  end

  alias_method :fusion_update, :update unless method_defined?(:fusion_update)

  def update
    # Call the original update method
    fusion_update if respond_to?(:fusion_update)
    
    # Only cycle frames if a multi-frame fusion bitmap is actively loaded
    if self.bitmap && @anim_frames && @anim_frames > 1
      @anim_ticker += 1
      
      if @anim_ticker >= 5 && !@selected
        @anim_ticker = 0
        @current_frame = (@current_frame + 1) % @anim_frames
        
        # Shift the viewable window to the next frame
        self.src_rect.x = @current_frame * self.bitmap.height
      end

      update_frame
      
      if @selected
        @adjusted_x = 4
        # Safe fallback for frame counting in the bounce math
        frames_total = @frames_count || @anim_frames || 2
        @adjusted_y = (@current_frame >= frames_total / 2) ? -2 : 6
      else
        @adjusted_x = 0
        @adjusted_y = 0
      end
      self.x = self.x
      self.y = self.y
    end
  end
end

#==================================================================
# class PokemonBoxIcon < IconSprite
#==================================================================
class PokemonBoxIcon < IconSprite
  alias_method :fusion_refresh, :refresh unless method_defined?(:fusion_refresh)

  def refresh
    return if !@pokemon
    
    # Intercept if the Pokémon is a fusion
    if @pokemon.respond_to?(:fused?) && @pokemon.fused?
      @_iconBitmap&.dispose
      @_iconBitmap = nil
      
      # Grab the correct forms from the stored clones (safely defaulting to 0)
      head_form = @pokemon.original_head_data ? @pokemon.original_head_data.form : 0
      body_form = @pokemon.original_body_data ? @pokemon.original_body_data.form : 0
      
      # Pass the forms into the bitmap generator
      bitmap = GameData::Species.fusion_icon_bitmap(
        @pokemon.fusion_head, head_form, 
        @pokemon.fusion_body, body_form, 
        @pokemon.shiny?
      )
      
      if bitmap
        self.bitmap = bitmap
        
        # Constrain the viewable area to a single square frame
        self.src_rect = Rect.new(0, 0, bitmap.height, bitmap.height)
        
        # Initialize animation variables for the PC UI
        @anim_frames = bitmap.width / bitmap.height
        @anim_ticker = 0
        @current_frame = 0
      end
      return
    end
    
    # Fallback to the original method for standard Pokémon
    fusion_refresh
  end

  alias_method :fusion_update, :update unless method_defined?(:fusion_update)

  def update
    # Call the original update
    fusion_update if respond_to?(:fusion_update)
    
    if releasing?
      self.zoom_x = lerp(1.0, 0.0, 1.5, @release_timer_start, System.uptime)
      self.zoom_y = self.zoom_x
      self.opacity = lerp(255, 0, 1.5, @release_timer_start, System.uptime)
      if self.opacity == 0
        @release_timer_start = nil
        dispose
      end
    end
  end
end