#================================================================================================
# Pokémon Fused Fates Fusion System - 007_MoveRelearner.rb
#================================================================================================

#==================================================================
# class MoveRelearnerScreen
#==================================================================
class MoveRelearnerScreen
  alias_method :pbGetRelearnableMoves_fusion, :pbGetRelearnableMoves
  
  def pbGetRelearnableMoves(pkmn)
    moves = pbGetRelearnableMoves_fusion(pkmn)
    return moves if !pkmn.is_a?(FusedPokemon) || !Settings::MOVE_RELEARNER_CAN_TEACH_MORE_MOVES
    
    # Grab first/egg moves from both original components if they exist
    head_moves = pkmn.original_head_data&.first_moves || []
    body_moves = pkmn.original_body_data&.first_moves || []
    fusion_moves = pkmn.first_moves || []
    
    # Merge them safely and avoid duplicates
    all_first_moves = (head_moves + body_moves + fusion_moves).uniq
    
    all_first_moves.each do |i|
      next if moves.include?(i) || pkmn.hasMove?(i)
      moves.unshift(i) # Place egg/first moves at the top of the list
    end
    
    return moves | []
  end
end