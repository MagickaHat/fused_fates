#================================================================================================
# Pokémon Fused Fates Fusion System - 003_ItemHandlers.rb
#================================================================================================

#==================================================================
# ItemHandlers
#==================================================================
ItemHandlers::UseOnPokemon.add(:DNASPLICERS, proc { |item, qty, pkmn, scene|
  # Safely resolve pkmn whether an index integer or a Pokemon object was passed
  pkmn1_index = -1
  if pkmn.is_a?(Numeric)
    pkmn1_index = pkmn
    pkmn = $player.party[pkmn1_index]
  else
    pkmn1_index = $player.party.index(pkmn)
    if pkmn1_index.nil?
      $player.party.each_with_index do |p, i|
        if p && p.personalID == pkmn.personalID
          pkmn1_index = i
          break
        end
      end
    end
  end

  # Explicit Index Bounds Checking
  if !pkmn || pkmn1_index < 0 || pkmn1_index >= $player.party.length
    scene.pbDisplay(_INTL("The DNA Splicers couldn't be used."))
    next false
  end

  # Check if already fused (Unfuse branch)
  if pkmn.respond_to?(:fused?) && pkmn.fused?
    # Initial command prompt
    cmd = scene.pbShowCommands(
      _INTL("This Pokémon is already fused. What would you like to do?"),
      [_INTL("Unfuse"), _INTL("Reverse Fusion"), _INTL("Cancel")],
      2 # Sets 'Cancel' as the default cursor position
    )

    if cmd == 0 # Unfuse
      if scene.pbConfirmMessage(_INTL("Are you sure you want to separate them?"))
        if FusionHandlers.respond_to?(:unfuse_party_pokemon) && FusionHandlers.unfuse_party_pokemon(pkmn1_index)
          scene.pbHardRefresh
          scene.pbDisplay(_INTL("The Pokémon were successfully separated!"))
          next true 
        else
          scene.pbDisplay(_INTL("This Pokémon cannot be unfused right now."))
          next false
        end
      else
        scene.pbRefresh
        next false
      end

    elsif cmd == 1 # Reverse Fusion
      if scene.pbConfirmMessage(_INTL("Swap the Head and Body of this fusion?"))
        if FusionHandlers.respond_to?(:reverse_party_pokemon) && FusionHandlers.reverse_party_pokemon(pkmn1_index)
          scene.pbHardRefresh
          scene.pbDisplay(_INTL("The fusion's components were successfully reversed!"))
          next true
        else
          scene.pbDisplay(_INTL("This fusion cannot be reversed right now."))
          next false
        end
      else
        scene.pbRefresh
        next false
      end

    else # Cancelled 
      scene.pbRefresh
      next false
    end
  end

  # Choose the second Pokémon (Fuse branch)
  if !scene.respond_to?(:pbChoosePokemon)
    next false
  end

  # Prompt the scene for the second Pokémon
  chosen_index = scene.pbChoosePokemon(_INTL("Fuse with which Pokémon?"))
  
  # Handle UI responses (nil, -1, or Array [action, index])
  if chosen_index.nil? || (chosen_index.is_a?(Numeric) && chosen_index < 0) || (chosen_index.is_a?(Array) && chosen_index[1] < 0)
    scene.pbRefresh
    next false
  end

  # Extract actual index if an array was returned by the party screen
  chosen_index = chosen_index[1] if chosen_index.is_a?(Array)

  # Validate and Execute Fusion
  if chosen_index != pkmn1_index
    chosen_pkmn = $player.party[chosen_index]
    
    if chosen_pkmn && !chosen_pkmn.egg? && (!chosen_pkmn.respond_to?(:fused?) || !chosen_pkmn.fused?)
      if FusionHandlers.respond_to?(:fuse_party_pokemon) && FusionHandlers.fuse_party_pokemon(pkmn1_index, chosen_index)
        scene.pbHardRefresh
        next true # Successful fusion
      else
        scene.pbDisplay(_INTL("Fusion failed!"))
        next false
      end
    else
      scene.pbDisplay(_INTL("That Pokémon cannot be fused!"))
      next false
    end
  else
    scene.pbDisplay(_INTL("You can't fuse a Pokémon with itself!"))
    next false
  end
})

ItemHandlers::UseOnPokemon.add(:ABILITYCAPSULE, proc { |item, qty, pkmn, scene|
  if pkmn.respond_to?(:fused?) && pkmn.fused?
    scene.pbDisplay(_INTL("It can't be used on a fused Pokémon."))
    next false
  end

  if scene.pbConfirm(_INTL("Do you want to change {1}'s Ability?", pkmn.name))
    abils = pkmn.getAbilityList
    abil1 = nil
    abil2 = nil
    abils.each do |i|
      abil1 = i[0] if i[1] == 0
      abil2 = i[0] if i[1] == 1
    end
    if abil1.nil? || abil2.nil? || pkmn.hasHiddenAbility? || pkmn.isSpecies?(:ZYGARDE)
      scene.pbDisplay(_INTL("It won't have any effect."))
      next false
    end
    newabil = (pkmn.ability_index + 1) % 2
    newabilname = GameData::Ability.get((newabil == 0) ? abil1 : abil2).name
    pkmn.ability_index = newabil
    pkmn.ability = nil
    scene.pbRefresh
    scene.pbDisplay(_INTL("{1}'s Ability changed! Its Ability is now {2}!", pkmn.name, newabilname))
    next true
  end
  next false
})

ItemHandlers::UseOnPokemon.add(:ABILITYPATCH, proc { |item, qty, pkmn, scene|
  if pkmn.respond_to?(:fused?) && pkmn.fused?
    scene.pbDisplay(_INTL("It can't be used on a fused Pokémon."))
    next false
  end

  if scene.pbConfirm(_INTL("Do you want to change {1}'s Ability?", pkmn.name))
    abils = pkmn.getAbilityList
    new_ability_id = nil
    abils.each { |a| new_ability_id = a[0] if a[1] == 2 }
    if !new_ability_id || pkmn.hasHiddenAbility? || pkmn.isSpecies?(:ZYGARDE)
      scene.pbDisplay(_INTL("It won't have any effect."))
      next false
    end
    new_ability_name = GameData::Ability.get(new_ability_id).name
    pkmn.ability_index = 2
    pkmn.ability = nil
    scene.pbRefresh
    scene.pbDisplay(_INTL("{1}'s Ability changed! Its Ability is now {2}!", pkmn.name, new_ability_name))
    next true
  end
  next false
})

ItemHandlers::UseOnPokemon.add(:LONELYMINT, proc { |item, qty, pkmn, scene|
  if pkmn.respond_to?(:fused?) && pkmn.fused?
    scene.pbDisplay(_INTL("It can't be used on a fused Pokémon."))
    next false
  end
  pbNatureChangingMint(:LONELY, item, pkmn, scene)
})

ItemHandlers::UseOnPokemon.add(:ADAMANTMINT, proc { |item, qty, pkmn, scene|
  if pkmn.respond_to?(:fused?) && pkmn.fused?
    scene.pbDisplay(_INTL("It can't be used on a fused Pokémon."))
    next false
  end
  pbNatureChangingMint(:ADAMANT, item, pkmn, scene)
})

ItemHandlers::UseOnPokemon.add(:NAUGHTYMINT, proc { |item, qty, pkmn, scene|
  if pkmn.respond_to?(:fused?) && pkmn.fused?
    scene.pbDisplay(_INTL("It can't be used on a fused Pokémon."))
    next false
  end
  pbNatureChangingMint(:NAUGHTY, item, pkmn, scene)
})

ItemHandlers::UseOnPokemon.add(:BRAVEMINT, proc { |item, qty, pkmn, scene|
  if pkmn.respond_to?(:fused?) && pkmn.fused?
    scene.pbDisplay(_INTL("It can't be used on a fused Pokémon."))
    next false
  end
  pbNatureChangingMint(:BRAVE, item, pkmn, scene)
})

ItemHandlers::UseOnPokemon.add(:BOLDMINT, proc { |item, qty, pkmn, scene|
  if pkmn.respond_to?(:fused?) && pkmn.fused?
    scene.pbDisplay(_INTL("It can't be used on a fused Pokémon."))
    next false
  end
  pbNatureChangingMint(:BOLD, item, pkmn, scene)
})

ItemHandlers::UseOnPokemon.add(:IMPISHMINT, proc { |item, qty, pkmn, scene|
  if pkmn.respond_to?(:fused?) && pkmn.fused?
    scene.pbDisplay(_INTL("It can't be used on a fused Pokémon."))
    next false
  end
  pbNatureChangingMint(:IMPISH, item, pkmn, scene)
})

ItemHandlers::UseOnPokemon.add(:LAXMINT, proc { |item, qty, pkmn, scene|
  if pkmn.respond_to?(:fused?) && pkmn.fused?
    scene.pbDisplay(_INTL("It can't be used on a fused Pokémon."))
    next false
  end
  pbNatureChangingMint(:LAX, item, pkmn, scene)
})

ItemHandlers::UseOnPokemon.add(:RELAXEDMINT, proc { |item, qty, pkmn, scene|
  if pkmn.respond_to?(:fused?) && pkmn.fused?
    scene.pbDisplay(_INTL("It can't be used on a fused Pokémon."))
    next false
  end
  pbNatureChangingMint(:RELAXED, item, pkmn, scene)
})

ItemHandlers::UseOnPokemon.add(:MODESTMINT, proc { |item, qty, pkmn, scene|
  if pkmn.respond_to?(:fused?) && pkmn.fused?
    scene.pbDisplay(_INTL("It can't be used on a fused Pokémon."))
    next false
  end
  pbNatureChangingMint(:MODEST, item, pkmn, scene)
})

ItemHandlers::UseOnPokemon.add(:MILDMINT, proc { |item, qty, pkmn, scene|
  if pkmn.respond_to?(:fused?) && pkmn.fused?
    scene.pbDisplay(_INTL("It can't be used on a fused Pokémon."))
    next false
  end
  pbNatureChangingMint(:MILD, item, pkmn, scene)
})

ItemHandlers::UseOnPokemon.add(:RASHMINT, proc { |item, qty, pkmn, scene|
  if pkmn.respond_to?(:fused?) && pkmn.fused?
    scene.pbDisplay(_INTL("It can't be used on a fused Pokémon."))
    next false
  end
  pbNatureChangingMint(:RASH, item, pkmn, scene)
})

ItemHandlers::UseOnPokemon.add(:QUIETMINT, proc { |item, qty, pkmn, scene|
  if pkmn.respond_to?(:fused?) && pkmn.fused?
    scene.pbDisplay(_INTL("It can't be used on a fused Pokémon."))
    next false
  end
  pbNatureChangingMint(:QUIET, item, pkmn, scene)
})

ItemHandlers::UseOnPokemon.add(:CALMMINT, proc { |item, qty, pkmn, scene|
  if pkmn.respond_to?(:fused?) && pkmn.fused?
    scene.pbDisplay(_INTL("It can't be used on a fused Pokémon."))
    next false
  end
  pbNatureChangingMint(:CALM, item, pkmn, scene)
})

ItemHandlers::UseOnPokemon.add(:GENTLEMINT, proc { |item, qty, pkmn, scene|
  if pkmn.respond_to?(:fused?) && pkmn.fused?
    scene.pbDisplay(_INTL("It can't be used on a fused Pokémon."))
    next false
  end
  pbNatureChangingMint(:GENTLE, item, pkmn, scene)
})

ItemHandlers::UseOnPokemon.add(:CAREFULMINT, proc { |item, qty, pkmn, scene|
  if pkmn.respond_to?(:fused?) && pkmn.fused?
    scene.pbDisplay(_INTL("It can't be used on a fused Pokémon."))
    next false
  end
  pbNatureChangingMint(:CAREFUL, item, pkmn, scene)
})

ItemHandlers::UseOnPokemon.add(:SASSYMINT, proc { |item, qty, pkmn, scene|
  if pkmn.respond_to?(:fused?) && pkmn.fused?
    scene.pbDisplay(_INTL("It can't be used on a fused Pokémon."))
    next false
  end
  pbNatureChangingMint(:SASSY, item, pkmn, scene)
})

ItemHandlers::UseOnPokemon.add(:TIMIDMINT, proc { |item, qty, pkmn, scene|
  if pkmn.respond_to?(:fused?) && pkmn.fused?
    scene.pbDisplay(_INTL("It can't be used on a fused Pokémon."))
    next false
  end
  pbNatureChangingMint(:TIMID, item, pkmn, scene)
})

ItemHandlers::UseOnPokemon.add(:HASTYMINT, proc { |item, qty, pkmn, scene|
  if pkmn.respond_to?(:fused?) && pkmn.fused?
    scene.pbDisplay(_INTL("It can't be used on a fused Pokémon."))
    next false
  end
  pbNatureChangingMint(:HASTY, item, pkmn, scene)
})

ItemHandlers::UseOnPokemon.add(:JOLLYMINT, proc { |item, qty, pkmn, scene|
  if pkmn.respond_to?(:fused?) && pkmn.fused?
    scene.pbDisplay(_INTL("It can't be used on a fused Pokémon."))
    next false
  end
  pbNatureChangingMint(:JOLLY, item, pkmn, scene)
})

ItemHandlers::UseOnPokemon.add(:NAIVEMINT, proc { |item, qty, pkmn, scene|
  if pkmn.respond_to?(:fused?) && pkmn.fused?
    scene.pbDisplay(_INTL("It can't be used on a fused Pokémon."))
    next false
  end
  pbNatureChangingMint(:NAIVE, item, pkmn, scene)
})

ItemHandlers::UseOnPokemon.add(:SERIOUSMINT, proc { |item, qty, pkmn, scene|
  if pkmn.respond_to?(:fused?) && pkmn.fused?
    scene.pbDisplay(_INTL("It can't be used on a fused Pokémon."))
    next false
  end
  pbNatureChangingMint(:SERIOUS, item, pkmn, scene)
})

ItemHandlers::UseOnPokemon.add(:ROTOMCATALOG, proc { |item, qty, pkmn, scene|
  if pkmn.respond_to?(:fused?) && pkmn.fused?
    scene.pbDisplay(_INTL("It had no effect."))
    next false
  end
  if !pkmn.isSpecies?(:ROTOM)
    scene.pbDisplay(_INTL("It had no effect."))
    next false
  elsif pkmn.fainted?
    scene.pbDisplay(_INTL("This can't be used on the fainted Pokémon."))
    next false
  end
  choices = [
    _INTL("Light bulb"),
    _INTL("Microwave oven"),
    _INTL("Washing machine"),
    _INTL("Refrigerator"),
    _INTL("Electric fan"),
    _INTL("Lawn mower"),
    _INTL("Cancel")
  ]
  new_form = scene.pbShowCommands(_INTL("Which appliance would you like to order?"), choices, pkmn.form)
  if new_form == pkmn.form
    scene.pbDisplay(_INTL("It won't have any effect."))
    next false
  elsif new_form >= 0 && new_form < choices.length - 1
    pkmn.setForm(new_form) do
      scene.pbRefresh
      scene.pbDisplay(_INTL("{1} transformed!", pkmn.name))
    end
    next true
  end
  next false
})