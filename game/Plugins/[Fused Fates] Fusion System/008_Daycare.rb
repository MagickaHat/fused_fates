#================================================================================================
# Pokémon Fused Fates Fusion System - 008_Daycare.rb
#================================================================================================

#==================================================================
# class DayCare
#==================================================================
class DayCare
  alias_method :fusion_compatibility, :compatibility unless method_defined?(:fusion_compatibility)

  def compatibility
    # Retrieve the deposited Pokémon pair in the Day Care
    pkmn1, pkmn2 = pokemon_pair rescue nil
    
    if pkmn1 && pkmn2
      # Hard rejection: If either Pokémon is a FusedPokemon, they cannot breed
      if (pkmn1.respond_to?(:fused?) && pkmn1.fused?) || 
          (pkmn2.respond_to?(:fused?) && pkmn2.fused?)
        return 0
      end
    end
      
    # If neither are fusions, proceed with standard Day Care compatibility logic
    return fusion_compatibility
  end

  # Redefining this method, but keeping its contents blank, seemingly allows fusedpokemon
  # to have their names read by the daycare man
  def self.get_details(index, name_var, cost_var)
  end
end