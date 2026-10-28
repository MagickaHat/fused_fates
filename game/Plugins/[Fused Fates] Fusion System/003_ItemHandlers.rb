#================================================================================================
# Pokémon Fused Fates Fusion System - 003_ItemHandlers.rb
#================================================================================================

#==================================================================
# DNA Splicers
#==================================================================
ItemHandlers::UseOnPokemon.add(:DNASPLICERS, proc { |item, qty, pkmn, scene|
  # Safely resolve pkmn whether an index integer or a Pokemon object was passed
  if pkmn.is_a?(Numeric)
    pkmn1_index = pkmn
    pkmn = $player.party[pkmn1_index]
  else
    pkmn1_index = $player.party.index(pkmn)
    pkmn1_index ||= $player.party.index { |p| p && p.personalID == pkmn.personalID }
  end

  # Explicit Index Bounds Checking
  if !pkmn || pkmn1_index.nil? || pkmn1_index < 0 || pkmn1_index >= $player.party.length
    scene.pbDisplay(_INTL("The DNA Splicers couldn't be used."))
    next false
  end

  # Already fused: offer to unfuse or reverse
  if FusionHandlers.fused?(pkmn)
    cmd = scene.pbShowCommands(
      _INTL("This Pokémon is already fused. What would you like to do?"),
      [_INTL("Unfuse"), _INTL("Reverse Fusion"), _INTL("Cancel")],
      2 # Sets 'Cancel' as the default cursor position
    )
    case cmd
    when 0 # Unfuse
      if !scene.pbConfirmMessage(_INTL("Are you sure you want to separate them?"))
        scene.pbRefresh
        next false
      end
      if FusionHandlers.unfuse_party_pokemon(pkmn1_index)
        scene.pbHardRefresh
        scene.pbDisplay(_INTL("The Pokémon were successfully separated!"))
        next true
      end
      scene.pbDisplay(_INTL("This Pokémon cannot be unfused right now."))
      next false
    when 1 # Reverse Fusion
      if !scene.pbConfirmMessage(_INTL("Swap the Head and Body of this fusion?"))
        scene.pbRefresh
        next false
      end
      if FusionHandlers.reverse_party_pokemon(pkmn1_index)
        scene.pbHardRefresh
        scene.pbDisplay(_INTL("The fusion's components were successfully reversed!"))
        next true
      end
      scene.pbDisplay(_INTL("This fusion cannot be reversed right now."))
      next false
    else # Cancelled
      scene.pbRefresh
      next false
    end
  end

  # Choose the second Pokémon (Fuse branch)
  next false if !scene.respond_to?(:pbChoosePokemon)
  chosen_index = scene.pbChoosePokemon(_INTL("Fuse with which Pokémon?"))

  # Handle UI responses (nil, -1, or Array [action, index])
  chosen_index = chosen_index[1] if chosen_index.is_a?(Array)
  if !chosen_index.is_a?(Numeric) || chosen_index < 0
    scene.pbRefresh
    next false
  end

  # Validate and Execute Fusion
  if chosen_index == pkmn1_index
    scene.pbDisplay(_INTL("You can't fuse a Pokémon with itself!"))
    next false
  end
  chosen_pkmn = $player.party[chosen_index]
  if !chosen_pkmn || chosen_pkmn.egg? || FusionHandlers.fused?(chosen_pkmn)
    scene.pbDisplay(_INTL("That Pokémon cannot be fused!"))
    next false
  end
  if FusionHandlers.fuse_party_pokemon(pkmn1_index, chosen_index)
    scene.pbHardRefresh
    next true # Successful fusion
  end
  scene.pbDisplay(_INTL("Fusion failed!"))
  next false
})

#==================================================================
# Items with no effect on fused Pokémon
#==================================================================
# Wraps each item's existing handler instead of copying it, so engine fixes still apply
FusionSettings::BLOCKED_ITEMS.each do |item_id|
  original = ItemHandlers::UseOnPokemon[item_id]
  next if !original || original.instance_variable_get(:@fusion_blocked)
  wrapper = proc { |item, qty, pkmn, scene|
    if FusionHandlers.fused?(pkmn)
      scene.pbDisplay(_INTL("It can't be used on a fused Pokémon."))
      next false
    end
    next original.call(item, qty, pkmn, scene)
  }
  wrapper.instance_variable_set(:@fusion_blocked, true)
  ItemHandlers::UseOnPokemon.add(item_id, wrapper)
end
