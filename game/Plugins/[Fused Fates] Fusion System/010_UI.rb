#================================================================================================
# Pokémon Fused Fates Fusion System - 010_UI.rb
#================================================================================================

#==================================================================
# class PokemonSummary_Scene
#==================================================================
class PokemonSummary_Scene
  alias_method :fusion_pbUpdate, :pbUpdate unless method_defined?(:fusion_pbUpdate)

  def pbUpdate
    fusion_pbUpdate if respond_to?(:fusion_pbUpdate)

    # Update fusion sprite bitmap only when switching party members (Up/Down)
    update_fusion_sprite

    # Enforce strict, bulletproof mutual exclusivity EVERY FRAME (60 FPS)
    if @pokemon && @pokemon.respond_to?(:fused?) && @pokemon.fused?
      if @sprites["pokemon"]
        @sprites["pokemon"].visible = false
        @sprites["pokemon"].bitmap = nil
      end
    else
      if @sprites["fusedpokemon"]
        @sprites["fusedpokemon"].visible = false
        @sprites["fusedpokemon"].bitmap = nil
      end
    end
  end

  alias_method :fusion_drawPage, :drawPage unless method_defined?(:fusion_drawPage)

  def drawPage(page)
    if @sprites && !@sprites["fusedpokemon"] && @viewport
      @sprites["fusedpokemon"] = PokemonSprite.new(@viewport)
    end

    # Draw the standard UI page
    fusion_drawPage(page)

    # Instantly load the fusion bitmap and lock coordinates before the screen fades in
    update_fusion_sprite if respond_to?(:update_fusion_sprite)

    # Safely restore the active sprite's visibility whenever the page is drawn 
    if @pokemon && @pokemon.respond_to?(:fused?) && @pokemon.fused?
      @sprites["fusedpokemon"].visible = true if @sprites["fusedpokemon"]
    else
      @sprites["pokemon"].visible = true if @sprites["pokemon"]
    end
  end

  def update_fusion_sprite
    return if !@sprites["fusedpokemon"]

    current_pkmn = @pokemon
    return unless current_pkmn

    # Only reload bitmap when changing party members, avoiding page-turn lag
    if @last_summary_pokemon != current_pkmn
      @last_summary_pokemon = current_pkmn

      if current_pkmn.respond_to?(:fused?) && current_pkmn.fused?
        head_form = @pokemon.original_head_data ? @pokemon.original_head_data.form : 0
        body_form = @pokemon.original_body_data ? @pokemon.original_body_data.form : 0

        # Generate and assign the fusion bitmap for the summary screen
        bitmap = GameData::Species.fusion_sprite_bitmap(
          current_pkmn.fusion_head, current_pkmn.fusion_body, 
          head_form, body_form, 
          current_pkmn.shiny?
        ) rescue nil

        @sprites["fusedpokemon"].bitmap = bitmap
        @sprites["fusedpokemon"].setOffset(PictureOrigin::CENTER)
        @sprites["fusedpokemon"].x = 104
        @sprites["fusedpokemon"].y = 206
      else
        @sprites["fusedpokemon"].bitmap = nil
      end
    end
  end

  alias_method :fusion_drawPageOne, :drawPageOne unless method_defined?(:fusion_drawPageOne)

  def drawPageOne
    fusion_drawPageOne

    # Specific text overlay handling for Page 1 (Head/Body names)
    if @pokemon.respond_to?(:fused?) && @pokemon.fused?
      head_id = @pokemon.fusion_head
      body_id = @pokemon.fusion_body

      head_name = GameData::Species.get(head_id).name
      body_name = GameData::Species.get(body_id).name

      overlay = @sprites["overlay"].bitmap
      base   = Color.new(248, 248, 248)
      shadow = Color.new(104, 104, 104)

      overlay.clear_rect(224, 70, 280, 75)
      text_pos = [
        [_INTL("Head"), 238, 86, :left, base, shadow],
        [head_name, 435, 86, :center, Color.new(64, 64, 64), Color.new(176, 176, 176)],
        [_INTL("Body"), 238, 118, :left, base, shadow],
        [body_name, 435, 118, :center, Color.new(64, 64, 64), Color.new(176, 176, 176)]
      ]
      pbDrawTextPositions(overlay, text_pos)
    end
  end

  alias_method :fusion_drawSelectedMove, :drawSelectedMove unless method_defined?(:fusion_drawSelectedMove)

  def drawSelectedMove(move_to_learn, selected_move)
    fusion_drawSelectedMove(move_to_learn, selected_move)

    if @pokemon.respond_to?(:fused?) && @pokemon.fused?
      @sprites["fusedpokemon"].visible = false if @sprites["fusedpokemon"]
    else
      @sprites["pokemon"].visible = false if @sprites["pokemon"]
    end
  end
end