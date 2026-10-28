#================================================================================================
# Pokémon Fused Fates Fusion System - 002_FusionHandlers.rb
#================================================================================================

#==================================================================
# module FusionHandlers
#==================================================================
module FusionHandlers
  # Kept for compatibility with code referencing the old location
  RESTRICTED_ALT_FORMS = FusionSettings::RESTRICTED_ALT_FORMS

  #----------------------------------------------------------------
  # Shared helpers
  #----------------------------------------------------------------
  # @param head_name [String] display name of the head species
  # @param body_name [String] display name of the body species
  # @return [String] portmanteau name of the fusion
  def self.fusion_name(head_name, body_name)
    return "#{head_name[0..(head_name.length / 2)]}#{body_name[(body_name.length / 2)..-1]}"
  end

  # Plays the layered cry of a fusion (head louder than body)
  # @param head [Symbol] head species
  # @param head_form [Integer] head form
  # @param body [Symbol] body species
  # @param body_form [Integer] body form
  # @param volume [Integer] overall volume
  # @param pitch [Integer] pitch of both cries
  def self.play_fusion_cry(head, head_form, body, body_form, volume = 90, pitch = 100)
    GameData::Species.play_cry_from_species(head, head_form, (volume * FusionSettings::HEAD_CRY_VOLUME_RATIO).round, pitch)
    GameData::Species.play_cry_from_species(body, body_form, (volume * FusionSettings::BODY_CRY_VOLUME_RATIO).round, pitch)
  end

  # Registers a compound HEAD_BODY species symbol so engine lookups on it succeed
  # @param fusion_sym [Symbol] the compound fusion symbol
  # @param head [Symbol] head species, whose data the placeholder copies
  def self.ensure_fusion_species(fusion_sym, head)
    return if GameData::Species.exists?(fusion_sym)
    head_data = GameData::Species.get(head)
    GameData::Species.register({
      :id         => fusion_sym,
      :name       => "Fusion",
      :base_stats => head_data.base_stats,
      :types      => head_data.types
    })
  end

  # @param pkmn [Pokemon]
  # @return [Boolean] whether the Pokémon is a fusion
  def self.fused?(pkmn)
    return pkmn.respond_to?(:fused?) && pkmn.fused?
  end

  # Checks whether a Pokémon can be used as a fusion component, showing a message if not
  # @param pkmn [Pokemon]
  # @return [Boolean]
  def self.can_fuse?(pkmn)
    if pkmn.egg?
      pbMessage(_INTL("Eggs cannot be fused!"))
      return false
    end
    if pkmn.is_a?(FusedPokemon) || fused?(pkmn)
      pbMessage(_INTL("Already-fused Pokémon cannot be fused again!"))
      return false
    end
    if FusionSettings::RESTRICTED_ALT_FORMS.include?(pkmn.species) && pkmn.form > 0
      pbMessage(_INTL("Pokémon in special forms cannot be fused!"))
      return false
    end
    return true
  end

  #----------------------------------------------------------------
  # Fusing
  #----------------------------------------------------------------
  # Fuses two party Pokémon. The first becomes the head, the second the body.
  # @param index1 [Integer] party index of the head
  # @param index2 [Integer] party index of the body
  # @return [Boolean] whether the fusion happened
  def self.fuse_party_pokemon(index1, index2)
    return false if index1 == index2
    pkmn1 = $player.party[index1]
    pkmn2 = $player.party[index2]

    # Ensure both slots contain valid Pokémon
    unless pkmn1 && pkmn2
      pbMessage(_INTL("There aren't enough Pokémon to perform a fusion!"))
      return false
    end
    return false unless can_fuse?(pkmn1) && can_fuse?(pkmn2)

    # The fusion holds one item (head's first); the other one goes to the Bag.
    # Check the Bag before changing anything so a full Bag can't eat an item.
    kept_item     = pkmn1.item_id || pkmn2.item_id
    leftover_item = (pkmn1.item_id && pkmn2.item_id) ? pkmn2.item_id : nil
    if leftover_item && !$bag&.can_add?(leftover_item)
      pbMessage(_INTL("The Bag is full, so {1}'s held item can't be put away!", pkmn2.name))
      return false
    end
    pkmn1.item = nil
    pkmn2.item = nil

    # Create a new FusedPokemon instance (it stores both components for later restoration)
    fused_pkmn = FusedPokemon.new(pkmn1.species, pkmn1.level, pkmn1, pkmn2)

    # Shiny inheritance
    fused_pkmn.shiny = true if pkmn1.shiny? || pkmn2.shiny?

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
    calculated_exp = (weighted_exp * FusionSettings::FUSION_EXP_BONUS).round

    # Ensure the EXP fits the growth rate for the fused Pokémon's level
    growth_rate = fused_pkmn.growth_rate
    calculated_exp = [calculated_exp, growth_rate.minimum_exp_for_level(fused_pkmn.level)].max
    fused_pkmn.exp = [calculated_exp, growth_rate.maximum_exp].min

    # Remember the EXP values so unfusing can hand back exactly what was earned
    fused_pkmn.fusion_exp_record = {:head => pkmn1.exp, :body => pkmn2.exp, :fused => fused_pkmn.exp}

    # Transfer and combine IVs
    fused_pkmn.iv = {}
    VirtualSpeciesProxy::STAT_IDS.each do |stat|
      fused_pkmn.iv[stat] = (((pkmn1.iv[stat] || 0) + (pkmn2.iv[stat] || 0)) / 2.0).ceil
    end

    # Transfer and combine happiness
    fused_pkmn.happiness = (pkmn1.happiness + pkmn2.happiness) / 2

    # Transfer and combine Ribbons
    fused_pkmn.ribbons = (pkmn1.ribbons + pkmn2.ribbons).uniq

    # Held items
    fused_pkmn.item = kept_item
    $bag.add(leftover_item) if leftover_item

    # Nature inheritance and selection
    fused_pkmn.nature = select_fusion_nature(pkmn1, pkmn2, fused_pkmn.name)

    # Move inheritance: prompt the player to select up to 4 moves from the combined active moveset
    source_moves = {}
    [pkmn1, pkmn2].each do |source|
      source.moves.each { |move| source_moves[move.id] ||= move if move&.id }
    end
    selected_move_ids = select_fusion_moves(source_moves.keys, fused_pkmn.name)

    # Copy the selected moves, keeping their current PP and PP Ups
    fused_pkmn.moves.clear
    selected_move_ids.each do |move_id|
      fused_pkmn.moves.push(source_moves[move_id].clone) if move_id
    end

    # Recalculate stats and replace the components in the party
    fused_pkmn.calc_stats
    $player.party[index1] = fused_pkmn
    $player.party.delete_at(index2)

    pbMessage(_INTL("Successfully fused into {1}!", fused_pkmn.name))
    return true
  end

  # Method for determining the fusion's nature
  # @return [Symbol] the chosen nature ID
  def self.select_fusion_nature(pkmn1, pkmn2, pokemon_name)
    nature_options = [pkmn1.nature&.id, pkmn2.nature&.id].compact.uniq
    return :HARDY if nature_options.empty?
    return nature_options[0] if nature_options.length == 1

    # If there are multiple unique natures, prompt the player to choose
    pbMessage(_INTL("Please choose {1}'s Nature.", pokemon_name))
    nature_names = nature_options.map { |n| GameData::Nature.get(n).name }
    choice = pbShowCommands(nil, nature_names, -1)

    # Default to the first option if cancelled
    return (choice >= 0) ? nature_options[choice] : nature_options[0]
  end

  # Method for determining the fusion's movepool
  # @return [Array<Symbol>] up to 4 move IDs
  def self.select_fusion_moves(move_ids, pokemon_name)
    # If the total available pool is 4 or fewer, keep all of them automatically
    return move_ids if move_ids.length <= Pokemon::MAX_MOVES

    selected_moves = []
    pbMessage(_INTL("Please choose up to 4 moves for {1}'s moveset.", pokemon_name))
    move_list = move_ids.map { |m_id| GameData::Move.get(m_id).name }
    move_list.push(_INTL("Cancel / Done"))

    # Loop until 4 moves are selected, or player finishes selection
    loop do
      choice = pbShowCommands(nil, move_list, -1)

      if choice < 0 || choice == move_list.length - 1
        # If cancelled early, keep whatever was picked so far, or default to the first 4
        selected_moves = move_ids[0, Pokemon::MAX_MOVES] if selected_moves.empty?
        break
      end

      chosen_move = move_ids[choice]
      if selected_moves.include?(chosen_move)
        pbMessage(_INTL("That move is already selected!"))
      else
        selected_moves.push(chosen_move)
        pbMessage(_INTL("Added {1} to the fusion's moveset ({2}/4).", move_list[choice], selected_moves.length))
      end

      break if selected_moves.length >= Pokemon::MAX_MOVES
    end

    return selected_moves
  end

  #----------------------------------------------------------------
  # Reversing
  #----------------------------------------------------------------
  # Swaps the head and body of a fused party Pokémon
  # @param index [Integer] party index
  # @return [Boolean] whether the fusion was reversed
  def self.reverse_party_pokemon(index)
    pkmn = $player.party[index]
    return false if !fused?(pkmn)

    # Swap the underlying component data and the fusion symbol trackers
    pkmn.original_head_data, pkmn.original_body_data = pkmn.original_body_data, pkmn.original_head_data
    pkmn.fusion_head, pkmn.fusion_body = pkmn.fusion_body, pkmn.fusion_head
    if pkmn.fusion_exp_record
      record = pkmn.fusion_exp_record
      record[:head], record[:body] = record[:body], record[:head]
    end

    # Update the core species ID (this also clears the cached proxy and ability)
    pkmn.species = :"#{pkmn.fusion_head}_#{pkmn.fusion_body}"
    pkmn.invalidate_fusion_caches
    pkmn.calc_stats
    return true
  end

  #----------------------------------------------------------------
  # Unfusing
  #----------------------------------------------------------------
  # Splits a fused party Pokémon back into its components
  # @param index [Integer] party index
  # @return [Boolean] whether the fusion was separated
  def self.unfuse_party_pokemon(index)
    pkmn = $player.party[index]

    # Ensure slot contains a valid FusedPokemon
    unless pkmn.is_a?(FusedPokemon) && pkmn.fused?
      pbMessage(_INTL("This Pokémon is not a fusion and cannot be unfused!"))
      return false
    end

    # Ensure the player has room in the party for the separated body Pokémon
    if $player.party.length >= Settings::MAX_PARTY_SIZE
      pbMessage(_INTL("Your party is full! You cannot unfuse this Pokémon."))
      return false
    end

    # Retrieve stored components, otherwise fall back to creating new ones
    original_head = pkmn.component(:head)
    original_head = Pokemon.new(pkmn.fusion_head, pkmn.level) unless original_head.is_a?(Pokemon)
    original_body = pkmn.component(:body)
    original_body = Pokemon.new(pkmn.fusion_body, pkmn.level) unless original_body.is_a?(Pokemon)

    redistribute_exp(pkmn, original_head, original_body)

    # Give any ribbons earned during fusion to both components, keeping the ones they already had
    original_head.ribbons = (original_head.ribbons + pkmn.ribbons).uniq
    original_body.ribbons = (original_body.ribbons + pkmn.ribbons).uniq

    # The fusion's held item goes back to the head, or to the Bag if the head holds one already
    if pkmn.item_id
      if original_head.item_id
        $bag&.add(pkmn.item_id)
      else
        original_head.item = pkmn.item_id
      end
    end

    # Replace the fused slot with the restored head and add the body to the end of the party
    $player.party[index] = original_head
    $player.party.push(original_body)

    pbMessage(_INTL("Successfully unfused back into {1} and {2}!", original_head.name, original_body.name))
    return true
  end

  # Gives each component its share of the EXP the fusion earned. Never lowers a component's EXP.
  # @param fused [FusedPokemon] the fusion being separated
  # @param head [Pokemon] the restored head
  # @param body [Pokemon] the restored body
  def self.redistribute_exp(fused, head, body)
    if fused.level >= Settings::MAXIMUM_LEVEL
      # If the fusion hit the level cap, both components also hit the cap
      [head, body].each { |c| c.exp = c.growth_rate.minimum_exp_for_level(Settings::MAXIMUM_LEVEL) }
    else
      # Fusions made before EXP was recorded use the components' combined EXP as the baseline
      record   = fused.fusion_exp_record
      baseline = record ? record[:fused] : head.exp + body.exp
      gained   = [fused.exp - baseline, 0].max
      share    = (gained * FusionSettings::UNFUSE_EXP_SHARE).floor
      [head, body].each { |c| c.exp = [c.exp + share, c.growth_rate.maximum_exp].min }
    end

    # Refresh levels and stats based on corrected experience pools
    head.calc_stats
    body.calc_stats
  end
end
