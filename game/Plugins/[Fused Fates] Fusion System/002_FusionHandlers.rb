#================================================================================================
# Pokémon Fused Fates Fusion System - 002_FusionHandlers.rb
#================================================================================================

#==================================================================
# module FusionHandlers
#==================================================================
module FusionHandlers
  # Array of species that should NOT be allowed to fuse if they are in an alternate form (form > 0)
  # Permanent forms (like Wormadam, Regional variants, Gastrodon) are omitted from this list so they can still fuse
  RESTRICTED_ALT_FORMS = [
    :ROTOM, :DIALGA, :PALKIA, :GIRATINA, :SHAYMIN, :TORNADUS, :THUNDURUS, :LANDORUS,
    :KYUREM, :KELDEO, :MELOETTA, :HOOPA, :DEOXYS, :NECROZMA, :CALYREX,
    :ZACIAN, :ZAMAZENTA, :CASTFORM, :CHERRIM, :WISHIWASHI, :MINIOR,
    :MIMIKYU, :CRAMORANT, :MORPEKO, :EISCUE, :PALAFIN, :TERAPAGOS
  ]

  # Fuses two party Pokémon
  def self.fuse_party_pokemon(index1, index2)
    return false if index1 == index2
    pkmn1 = $player.party[index1]
    pkmn2 = $player.party[index2]

    # Ensure both slots contain valid Pokémon
    unless pkmn1 && pkmn2
      pbMessage(_INTL("There aren't enough Pokémon to perform a fusion!"))
      return false
    end

    # Check if either Pokémon is an egg
    if pkmn1.egg? || pkmn2.egg?
      pbMessage(_INTL("Eggs cannot be fused!"))
      return false
    end

    # Check if either Pokémon is already a FusedPokemon (preventing multi-fusions)
    if pkmn1.is_a?(FusedPokemon) || pkmn2.is_a?(FusedPokemon) || (pkmn1.respond_to?(:fusion_head) && pkmn1.fusion_head) || (pkmn2.respond_to?(:fusion_head) && pkmn2.fusion_head)
     pbMessage(_INTL("Already-fused Pokémon cannot be fused again!"))
     return false
    end

    # Prevent specific alternate forms from being fused
    if (RESTRICTED_ALT_FORMS.include?(pkmn1.species) && pkmn1.form > 0) ||
      (RESTRICTED_ALT_FORMS.include?(pkmn2.species) && pkmn2.form > 0)
     pbMessage(_INTL("Pokémon in special forms cannot be fused!"))
     return false
    end

    # Create deep copies of both original Pokémon for later restoration
    original_head_clone = pkmn1.clone
    original_body_clone = pkmn2.clone

    # Create a new FusedPokemon instance
    fused_pkmn = FusedPokemon.new(pkmn1.species, pkmn1.level, pkmn1, pkmn2)

    # Store the actual original data clones inside the correct accessor variables
    fused_pkmn.original_head_data = original_head_clone
    fused_pkmn.original_body_data = original_body_clone

    # Shiny inheritance
    pkmn1_shiny = pkmn1.respond_to?(:shiny?) ? pkmn1.shiny? : pkmn1.shiny
    pkmn2_shiny = pkmn2.respond_to?(:shiny?) ? pkmn2.shiny? : pkmn2.shiny

    if pkmn1_shiny || pkmn2_shiny
      if fused_pkmn.respond_to?(:shiny=)
        fused_pkmn.shiny = true
      end
    end

    # Trainer inheritance
    if fused_pkmn.respond_to?(:owner=) && pkmn1.respond_to?(:owner)
      fused_pkmn.owner = pkmn1.owner.clone
    else
      fused_pkmn.owner.name = pkmn1.owner.name
      fused_pkmn.owner.id = pkmn1.owner.id
      fused_pkmn.owner.gender = pkmn1.owner.gender
      fused_pkmn.personalID = pkmn1.personalID
    end

    # Pokéball inheritance
    fused_pkmn.poke_ball = pkmn1.poke_ball

    # Transfer and combine experience
    # Calculate level-based weight factor to ensure the higher-level component has a fair impact
    avg_level = (pkmn1.level + pkmn2.level) / 2.0
    weight1 = pkmn1.level.to_f / avg_level
    weight2 = pkmn2.level.to_f / avg_level

    weighted_exp = (pkmn1.exp * weight1 + pkmn2.exp * weight2) / 2.0

    # Apply a Fusion Synergy multiplier
    fusion_bonus = 1.05
    calculated_exp = (weighted_exp * fusion_bonus).round

    # Ensure the EXP matches the growth rate minimum for the fused Pokémon's level
    min_exp_for_level = fused_pkmn.growth_rate.minimum_exp_for_level(fused_pkmn.level)
    fused_pkmn.exp = [calculated_exp, min_exp_for_level].max

    # Transfer and combine IVs
    fused_pkmn.iv = {}
    [:HP, :ATTACK, :DEFENSE, :SPECIAL_ATTACK, :SPECIAL_DEFENSE, :SPEED].each do |stat|
      value1 = pkmn1.iv[stat] || 0
      value2 = pkmn2.iv[stat] || 0
      fused_pkmn.iv[stat] = ((value1 + value2) / 2.0).ceil
    end

    # Transfer and combine happiness
    fused_pkmn.happiness = [pkmn1.happiness, pkmn2.happiness].sum / 2

    # Transfer and combine Ribbons
    if pkmn1.respond_to?(:ribbons) && pkmn2.respond_to?(:ribbons) && fused_pkmn.respond_to?(:ribbons=)
      fused_pkmn.ribbons = (pkmn1.ribbons + pkmn2.ribbons).uniq
    end

    # Handle Held Items (Transfer unequipped items to bag)
    [pkmn1, pkmn2].each do |source_pkmn|
      next unless source_pkmn.respond_to?(:item) && source_pkmn.item
      held_item = source_pkmn.item
      source_pkmn.item = nil

      # Try adding the item back to the player's bag, otherwise place it onto the fused Pokémon if empty
      if $bag && $bag.add(held_item)
        if !fused_pkmn.hasItem?
          fused_pkmn.item = held_item
        else
          $bag.add(held_item)
        end
      end
    end

    # Nature inheritance and selection
    if fused_pkmn.respond_to?(:nature=)
      chosen_nature = FusionHandlers.select_fusion_nature(pkmn1, pkmn2, fused_pkmn.name)
      fused_pkmn.nature = chosen_nature
    end

    # Move inheritance
    if pkmn1.respond_to?(:moves) && pkmn2.respond_to?(:moves) && fused_pkmn.respond_to?(:moves)
      available_moves = []
      
      # Collect currently learned active moves from both component Pokémon
      [pkmn1, pkmn2].each do |source|
        next unless source.respond_to?(:moves) && source.moves
        source.moves.each do |move|
          next unless move && move.id
          available_moves.push(move.id) unless available_moves.include?(move.id)
        end
      end

      # Prompt player to select up to 4 moves from the combined active moveset
      selected_move_ids = FusionHandlers.select_fusion_moves(available_moves, fused_pkmn.name)
      
      # Assign selected moves to the fused Pokémon
      fused_pkmn.moves.clear
      selected_move_ids.each do |move_id|
        next unless move_id
        fused_pkmn.moves.push(Pokemon::Move.new(move_id))
      end
    end

    $player.party[index1] = fused_pkmn
    pkmn1 = fused_pkmn

    # Recalculate stats
    fused_pkmn.calc_stats

    # Remove the second Pokémon from the party
    $player.party.delete_at(index2)

    pbMessage(_INTL("Successfully fused into {1}!", pkmn1.name))
    return true
  end

  # Method for determining the fusion's nature
  def self.select_fusion_nature(pkmn1, pkmn2, pokemon_name)
    nature_options = []

    # Collect unique natures from both component Pokémon
    [pkmn1, pkmn2].each do |pkmn|
      next unless pkmn.respond_to?(:nature)
      nature_options.push(pkmn.nature) unless nature_options.include?(pkmn.nature)
    end

    # Fallback to Hardy or random if natures aren't present
    if nature_options.empty?
      nature_options = [:HARDY]
    end

    # If there are multiple unique natures, prompt the player to choose
    if nature_options.length > 1
      pbMessage(_INTL("Please choose {1}'s Nature.", pokemon_name))
      
      nature_names = nature_options.map { |n| GameData::Nature.get(n).name }
      choice = pbShowCommands(nil, nature_names, -1)
      
      # Default to the first option if cancelled
      selected_nature = (choice >= 0) ? nature_options[choice] : nature_options[0]
    else
      selected_nature = nature_options[0]
    end

    return selected_nature
  end

  # Method for determining the fusion's movepool
  def self.select_fusion_moves(move_ids, pokemon_name)
    selected_moves = []

    # If the total available pool is 4 or fewer, keep all of them automatically
    if move_ids.length <= 4
      return move_ids
    end

    pbMessage(_INTL("Please choose up to 4 moves for {1}'s moveset.", pokemon_name))

    # Loop until 4 moves are selected, or player finishes selection
    loop do
      move_list = move_ids.map { |m_id| GameData::Move.get(m_id).name}
      move_list.push(_INTL("Cancel / Done"))

      choice = pbShowCommands(nil, move_list, -1)

      if choice < 0 || choice == move_list.length - 1
        # If cancelled early, there is at least whatever they picked so far, or default to first 4
        break if selected_moves.length > 0
        selected_moves = move_ids[0, 4]
        break
      end

      chosen_move = move_ids[choice]

      if selected_moves.include?(chosen_move)
        pbMessage(_INTL("That move is already selected!"))
      else
        selected_moves.push(chosen_move)
        pbMessage(_INTL("Added {1} to the fusion's moveset ({2}/4).", GameData::Move.get(chosen_move).name, selected_moves.length))
      end

      break if selected_moves.length >= 4
    end

    return selected_moves
  end

  def self.reverse_party_pokemon(index)
    pkmn = $player.party[index]
    return false if !pkmn || !pkmn.respond_to?(:fused?) || !pkmn.fused?

    # Swap the underlying original data clones
    temp_data = pkmn.original_head_data
    pkmn.original_head_data = pkmn.original_body_data
    pkmn.original_body_data = temp_data

    # Swap the active fusion symbol trackers
    temp_head_sym = pkmn.fusion_head
    pkmn.fusion_head = pkmn.fusion_body
    pkmn.fusion_body = temp_head_sym

    # Update the core species ID 
    pkmn.species = :"#{pkmn.fusion_head}_#{pkmn.fusion_body}"

    # Clear the cached virtual species proxy
    # (This forces the game to rebuild the sprite, types, and base stats upon the next check)
    if pkmn.instance_variable_defined?(:@_virtual_species_data)
      pkmn.remove_instance_variable(:@_virtual_species_data)
    end

    # Recalculate stats after reversal
    pkmn.calc_stats

    return true
  end

  def self.unfuse_party_pokemon(index)
    pkmn = $player.party[index]

    # Ensure slot contains a valid FusedPokemon
    unless pkmn.is_a?(FusedPokemon) && pkmn.respond_to?(:fusion_head) && pkmn.respond_to?(:fusion_body)
      pbMessage(_INTL("This Pokémon is not a fusion and cannot be unfused!"))
      return false
    end

    # Ensure the player has room in the party for the separated body Pokémon
    if $player.party.length >= Settings::MAX_PARTY_SIZE
      pbMessage(_INTL("Your party is full! You cannot unfuse this Pokémon."))
      return false
    end

    # Retrieve stored original clones if available and valid (Pokemon instance), otherwise fallback to creating new ones
    if pkmn.respond_to?(:original_head_data) && pkmn.original_head_data.is_a?(Pokemon)
      original_head = pkmn.original_head_data
    else
      original_head = Pokemon.new(pkmn.fusion_head, pkmn.level)
    end

    if pkmn.respond_to?(:original_body_data) && pkmn.original_body_data.is_a?(Pokemon)
      original_body = pkmn.original_body_data
    else
      original_body = Pokemon.new(pkmn.fusion_body, pkmn.level)
    end

    # Balanced EXP Redistribution 
    if pkmn.respond_to?(:exp) && original_head.respond_to?(:exp=) && original_body.respond_to?(:exp=)
      # Max Level Bypass
      if pkmn.level >= Settings::MAXIMUM_LEVEL
        # If the fusion hit the level cap, ensure both components receive enough EXP to also hit the cap
        original_head.exp = original_head.growth_rate.minimum_exp_for_level(Settings::MAXIMUM_LEVEL)
        original_body.exp = original_body.growth_rate.minimum_exp_for_level(Settings::MAXIMUM_LEVEL)
      end

      # Determine baseline starting EXP of both components before fusion
      base_head_exp = original_head.exp || 0
      base_body_exp = original_body.exp || 0
      initial_combined_exp = base_head_exp + base_body_exp

      # Calculate total net EXP earned during the fusion period safely
      total_fused_exp = pkmn.exp
      net_gained_exp = [0, total_fused_exp - initial_combined_exp].max

      # If the fused pokemon has less exp than the combined starting pool (edge case),
      # fallback to distributing current total relative to their original proportions
      if total_fused_exp < initial_combined_exp
        original_head.exp = total_fused_exp / 2
        original_body.exp = total_fused_exp / 2
      else
        # Split the newly earned EXP evenly between the two components
        shared_exp_boost = net_gained_exp / 2

        original_head.exp = base_head_exp + shared_exp_boost
        original_body.exp = base_body_exp + shared_exp_boost
      end
      
      # Refresh levels and stats based on corrected experience pools
      original_head.calc_stats if original_head.respond_to?(:calc_stats)
      original_body.calc_stats if original_body.respond_to?(:calc_stats)
    end

    # Ribbon Redistribution
    if pkmn.respond_to?(:ribbons) && original_head.respond_to?(:ribbons=) && original_body.respond_to?(:ribbons=)
      # Give any ribbons earned during fusion to both components, 
      # keeping the ones they already had prior to fusing
      original_head.ribbons = (original_head.ribbons + pkmn.ribbons).uniq
      original_body.ribbons = (original_body.ribbons + pkmn.ribbons).uniq
    end

    head_name = original_head.name
    body_name = original_body.name

    # Replace the fused slot with the restored head Pokémon
    $player.party[index] = original_head

    # Push the restored body Pokémon to the end of the party
    $player.party.push(original_body)

    pbMessage(_INTL("Successfully unfused back into {1} and {2}!", head_name, body_name))
    return true
  end
end