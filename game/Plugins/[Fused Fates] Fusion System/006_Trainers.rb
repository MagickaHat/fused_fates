#================================================================================================
# Pokémon Fused Fates Fusion System - 006_Trainers.rb
#================================================================================================

#==================================================================
# module GameData class Trainer
#==================================================================
module GameData
  class Trainer
    if const_defined?(:SUB_SCHEMA) && !SUB_SCHEMA.key?("FusionBody")
      SUB_SCHEMA["FusionBody"] = [:fusion_body, "e", :Species]
    end

    alias_method :fusion_to_trainer, :to_trainer unless method_defined?(:fusion_to_trainer)

    def to_trainer
      # Generate the standard trainer and standard Pokémon party
      trainer = fusion_to_trainer
      
      # Iterate through the generated party to apply any defined fusions
      trainer.party.each_with_index do |pkmn, i|
        pkmn_data = @pokemon[i]
        
        # Extract the fusion body property from the trainer data hash
        fusion_body = nil
        if pkmn_data.is_a?(Hash)
          fusion_body = pkmn_data[:fusion_body] || pkmn_data["fusion_body"] || pkmn_data[:FusionBody]
        elsif pkmn_data.respond_to?(:fusion_body)
          fusion_body = pkmn_data.fusion_body
        end
        
        if fusion_body
          head_species = pkmn.species
          body_species = fusion_body.to_s.upcase.to_sym
          
          # Create a FusedPokemon instance preserving all custom configurations
          # (moves, IVs, EVs, item, shiny, gender, ball, etc.)
          fused_pkmn = FusedPokemon.new(head_species, pkmn.level, head_species, body_species)
          
          # Copy all instance variables from the generated base Pokemon
          pkmn.instance_variables.each do |var|
            fused_pkmn.instance_variable_set(var, pkmn.instance_variable_get(var))
          end
          
          # Assign fusion-specific attributes and species data
          fused_pkmn.fusion_head = head_species
          fused_pkmn.fusion_body = body_species
          fused_pkmn.original_head_data = GameData::Species.try_get(head_species)
          fused_pkmn.original_body_data = GameData::Species.try_get(body_species)
          
          # Recalculate blended stats and restore full HP
          fused_pkmn.calc_stats
          fused_pkmn.hp = fused_pkmn.totalhp
          
          # Replace the standard Pokemon with the fully configured FusedPokemon
          trainer.party[i] = fused_pkmn
        end
      end
      
      return trainer
    end
  end
end
