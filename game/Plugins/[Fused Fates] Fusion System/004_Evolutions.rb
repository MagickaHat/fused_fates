#================================================================================================
# Pokémon Fused Fates Fusion System - 004_Evolutions.rb
#================================================================================================

#==================================================================
# class FusedPokemon
#==================================================================
class FusedPokemon
  # alias_method check_evolution_internal
  unless method_defined?(:fusion_check_evolution_internal)
    alias_method :fusion_check_evolution_internal, :check_evolution_internal
  end
  
  # check_evolution_internal
  def check_evolution_internal(&block)
    return nil if @__evaluating_fusion_evo
    @__evaluating_fusion_evo = true

    current_head = respond_to?(:fusion_head) ? self.fusion_head : @fusion_head
    current_body = respond_to?(:fusion_body) ? self.fusion_body : @fusion_body

    begin
      if respond_to?(:fused?) && fused?
        
        # Check Head component evolution first
        if current_head
          head_data = GameData::Species.try_get(current_head)
          if head_data && head_data.evolutions
            head_data.evolutions.each do |evo|
              new_head, evo_method, evo_parameter = evo[0], evo[1], evo[2]
              new_fusion_sym = :"#{new_head}_#{current_body}"

              next if new_head == head_data.get_previous_species
              
              next unless GameData::Species.exists?(new_head) && GameData::Species.exists?(current_body)

              if block && block.call(self, new_fusion_sym, evo_method, evo_parameter)
                unless GameData::Species.exists?(new_fusion_sym)
                  GameData::Species.register({
                    :id         => new_fusion_sym,
                    :name       => "Fusion",
                    :base_stats => GameData::Species.get(new_head).base_stats,
                    :types      => GameData::Species.get(new_head).types
                  })
                end
                return new_fusion_sym
              end
            end
          end
        end
      
        # Check Body component evolution
        if current_body
          body_data = GameData::Species.try_get(current_body)
          if body_data && body_data.evolutions
            body_data.evolutions.each do |evo|
              new_body, evo_method, evo_parameter = evo[0], evo[1], evo[2]
              new_fusion_sym = :"#{current_head}_#{new_body}"

              next if new_body == body_data.get_previous_species
                      
              next unless GameData::Species.exists?(current_head) && GameData::Species.exists?(new_body)

              if block && block.call(self, new_fusion_sym, evo_method, evo_parameter)
                unless GameData::Species.exists?(new_fusion_sym)
                  GameData::Species.register({
                    :id         => new_fusion_sym,
                    :name       => "Fusion",
                    :base_stats => GameData::Species.get(current_head).base_stats,
                    :types      => GameData::Species.get(current_head).types
                  })
                end
                return new_fusion_sym
              end
            end
          end
        end
      end

      # Vanilla Fallback
      return fusion_check_evolution_internal(&block)

    ensure
      @__evaluating_fusion_evo = false
    end
  end

  # alias_method species=
  unless method_defined?(:fusion_species)
    alias_method :fusion_species, :species=
  end

  def species=(value)
    if value.to_s.include?('_') && respond_to?(:fused?) && fused?
      parts = value.to_s.split('_', 2)

      @fusion_head = parts[0].upcase.to_sym
      @fusion_body = parts[1].upcase.to_sym
      @_virtual_species_data = nil # Clear proxy cache so stats update

      # If the symbol doesn't exist natively, register it dynamically 
      unless GameData::Species.exists?(value)
        GameData::Species.register({
          :id           => value,
          :name          => "Fusion",
          :base_stats   => GameData::Species.get(@fusion_head).base_stats, 
          :types        => GameData::Species.get(@fusion_head).types
        })
      end

      fusion_species(value)
      return
    end

    # Pass-through for normal species changes
    fusion_species(value)
  end
end

#================================================================
# GameData::Evolution
#================================================================
GameData::Evolution.register({
  :id            => :TradeSpecies,
  :parameter     => :Species,
  :on_trade_proc => proc { |pkmn, parameter, other_pkmn|
    next false if !other_pkmn
    
    # Check if the other Pokemon is holding an everstone
    has_everstone = other_pkmn.hasItem?(:EVERSTONE)
    
    # Check if the other Pokemon matches the required species, or contains it as a component
    match = (other_pkmn.species == parameter)
    match ||= (other_pkmn.respond_to?(:fusion_head) && other_pkmn.fusion_head == parameter)
    match ||= (other_pkmn.respond_to?(:fusion_body) && other_pkmn.fusion_body == parameter)

    next match && !has_everstone
  }
})

#==================================================================
# class PokemonEvolutionScene
#==================================================================
class PokemonEvolutionScene
  def pbEvolutionSuccess
    $stats.evolution_count += 1
    
    is_fusion = @newspecies.to_s.include?('_')
    
    if is_fusion
      # Extract Head and Body components
      head_sym, body_sym = @newspecies.to_s.split('_').map(&:to_sym)
      
      # Layered Cries
      cry_time = GameData::Species.cry_length(head_sym, @pokemon.form)
      Pokemon.play_cry(head_sym, @pokemon.form, 100, 100)
      Pokemon.play_cry(body_sym, @pokemon.form, 70, 100) 
      
      # Portmanteau Name Generation
      head_name = GameData::Species.get(head_sym).name
      body_name = GameData::Species.get(body_sym).name
      
      newspeciesname = "#{head_name[0..(head_name.length / 2)]}#{body_name[(body_name.length / 2)..-1]}"
    else
      # Vanilla Fallback for standard Pokémon
      cry_time = GameData::Species.cry_length(@newspecies, @pokemon.form)
      Pokemon.play_cry(@newspecies, @pokemon.form)
      newspeciesname = GameData::Species.get(@newspecies).name
    end

    timer_start = System.uptime
    loop do
      Graphics.update
      pbUpdate
      break if System.uptime - timer_start >= (cry_time || 0.5)
    end
    pbBGMStop
    
    # Success jingle & message
    pbMEPlay("Evolution success")
    pbMessageDisplay(@sprites["msgwindow"],
                     "\\se[]" + _INTL("Congratulations! Your {1} evolved into {2}!",
                                      @pokemon.name, newspeciesname) + "\\wt[80]") { pbUpdate }
    @sprites["msgwindow"].text = ""
    
    # Check for consumed item and check if Pokémon should be duplicated
    pbEvolutionMethodAfterEvolution
    
    # Modify Pokémon to make it evolved
    was_fainted = @pokemon.fainted?
    @pokemon.species = @newspecies
    @pokemon.hp = 0 if was_fainted
    @pokemon.calc_stats
    @pokemon.ready_to_evolve = false
    
    # See and own evolved species
    was_owned = $player.owned?(@newspecies)
    $player.pokedex.register(@pokemon)
    $player.pokedex.set_owned(@newspecies)
    
    moves_to_learn = []
    movelist = @pokemon.getMoveList
    movelist.each do |i|
      next if i[0] != 0 && i[0] != @pokemon.level   # 0 is "learn upon evolution"
      moves_to_learn.push(i[1])
    end
    
    # Show Pokédex entry for new species if it hasn't been owned before
    if Settings::SHOW_NEW_SPECIES_POKEDEX_ENTRY_MORE_OFTEN && !was_owned &&
       $player.has_pokedex && $player.pokedex.species_in_unlocked_dex?(@pokemon.species)
      pbMessageDisplay(@sprites["msgwindow"],
                       _INTL("{1}'s data was added to the Pokédex.", newspeciesname)) { pbUpdate }
      $player.pokedex.register_last_seen(@pokemon)
      pbFadeOutIn do
        scene = PokemonPokedexInfo_Scene.new
        screen = PokemonPokedexInfoScreen.new(scene)
        screen.pbDexEntry(@pokemon.species)
        @sprites["msgwindow"].text = "" if moves_to_learn.length > 0
        pbEndScreen(false) if moves_to_learn.length == 0
      end
    end
    
    # Learn moves upon evolution for evolved species
    moves_to_learn.each do |move|
      pbLearnMove(@pokemon, move, true) { pbUpdate }
    end
  end
end