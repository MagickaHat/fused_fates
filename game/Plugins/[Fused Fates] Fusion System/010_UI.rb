#================================================================================================
# Pokémon Fused Fates Fusion System - 010_UI.rb
#================================================================================================

#==================================================================
# class PokemonSummary_Scene
#==================================================================
# The fusion's sprite itself is drawn by the normal summary sprite, because
# GameData::Species.sprite_bitmap_from_pokemon returns fusion graphics (see 009_Sprites.rb).
class PokemonSummary_Scene
  alias_method :fusion_drawPageOne, :drawPageOne unless method_defined?(:fusion_drawPageOne)

  def drawPageOne
    fusion_drawPageOne
    return unless FusionHandlers.fused?(@pokemon)

    # Specific text overlay handling for Page 1 (Head/Body names)
    head_name = GameData::Species.get(@pokemon.fusion_head).name
    body_name = GameData::Species.get(@pokemon.fusion_body).name

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
