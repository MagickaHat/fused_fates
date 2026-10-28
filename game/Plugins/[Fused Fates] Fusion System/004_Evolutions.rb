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

  # Checks the head first, then the body, for an evolution allowed by the given block.
  # @return [Symbol, nil] the compound HEAD_BODY symbol of the evolved fusion
  def check_evolution_internal(&block)
    return nil if @__evaluating_fusion_evo
    @__evaluating_fusion_evo = true
    begin
      if fused? && block
        [:head, :body].each do |side|
          result = check_component_evolution(side, &block)
          return result if result
        end
      end

      # Vanilla Fallback
      return fusion_check_evolution_internal(&block)
    ensure
      @__evaluating_fusion_evo = false
    end
  end

  # @param side [Symbol] :head or :body
  # @return [Symbol, nil] the compound fusion symbol if this component can evolve
  def check_component_evolution(side)
    species_data = component_species_data(side)
    return nil unless species_data && species_data.evolutions
    previous_species = species_data.get_previous_species
    species_data.evolutions.each do |evo|
      new_species, evo_method, evo_parameter = evo[0], evo[1], evo[2]
      next if new_species == previous_species
      new_head = (side == :head) ? new_species : @fusion_head
      new_body = (side == :body) ? new_species : @fusion_body
      next unless GameData::Species.exists?(new_head) && GameData::Species.exists?(new_body)
      new_fusion_sym = :"#{new_head}_#{new_body}"
      next unless yield(self, new_fusion_sym, evo_method, evo_parameter)
      FusionHandlers.ensure_fusion_species(new_fusion_sym, new_head)
      return new_fusion_sym
    end
    return nil
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
    next false if other_pkmn.hasItem?(:EVERSTONE)

    # Check if the other Pokemon matches the required species, or contains it as a component
    next true if other_pkmn.species == parameter
    next true if other_pkmn.respond_to?(:fusion_head) && other_pkmn.fusion_head == parameter
    next other_pkmn.respond_to?(:fusion_body) && other_pkmn.fusion_body == parameter
  }
})

#==================================================================
# class PokemonEvolutionScene
#==================================================================
class PokemonEvolutionScene
  def pbEvolutionSuccess
    $stats.evolution_count += 1

    if @newspecies.to_s.include?('_') && FusionHandlers.fused?(@pokemon)
      # Extract Head and Body components
      head_sym, body_sym = @newspecies.to_s.split('_', 2).map(&:to_sym)
      head_form = @pokemon.component_form(:head)
      body_form = @pokemon.component_form(:body)

      # Layered Cries
      cry_time = GameData::Species.cry_length(head_sym, head_form)
      Pokemon.play_cry(head_sym, head_form, 100, 100)
      Pokemon.play_cry(body_sym, body_form, 70, 100)

      # Portmanteau Name Generation
      newspeciesname = FusionHandlers.fusion_name(GameData::Species.get(head_sym).name,
                                                  GameData::Species.get(body_sym).name)
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
