#================================================================================================
# Pokémon Fused Fates Fusion System - 011_Debug.rb
#================================================================================================

#==================================================================
# Pokémon debug menu (party screen)
#==================================================================
MenuHandlers.add(:pokemon_debug_menu, :fusion_menu, {
  "name"   => _INTL("Fusion..."),
  "parent" => :main
})

MenuHandlers.add(:pokemon_debug_menu, :fusion_fuse, {
  "name"   => _INTL("Fuse with..."),
  "parent" => :fusion_menu,
  "effect" => proc { |pkmn, pkmnid, heldpoke, settingUpBattle, screen|
    # Fusing only works on party Pokémon
    if !pkmnid.is_a?(Integer) || !screen.respond_to?(:pbChoosePokemon)
      screen.pbDisplay(_INTL("Only Pokémon in the party can be fused."))
      next false
    end
    if FusionHandlers.fused?(pkmn)
      screen.pbDisplay(_INTL("{1} is already fused.", pkmn.name))
      next false
    end
    chosen = screen.pbChoosePokemon(_INTL("Fuse with which Pokémon?"))
    chosen = chosen[1] if chosen.is_a?(Array)
    next false if !chosen.is_a?(Integer) || chosen < 0 || chosen == pkmnid
    next false if !FusionHandlers.fuse_party_pokemon(pkmnid, chosen)
    screen.pbHardRefresh
    next true
  }
})

MenuHandlers.add(:pokemon_debug_menu, :fusion_unfuse, {
  "name"   => _INTL("Unfuse"),
  "parent" => :fusion_menu,
  "effect" => proc { |pkmn, pkmnid, heldpoke, settingUpBattle, screen|
    if !pkmnid.is_a?(Integer) || !FusionHandlers.fused?(pkmn)
      screen.pbDisplay(_INTL("Only fused Pokémon in the party can be unfused."))
      next false
    end
    next false if !FusionHandlers.unfuse_party_pokemon(pkmnid)
    screen.pbHardRefresh
    next true
  }
})

MenuHandlers.add(:pokemon_debug_menu, :fusion_reverse, {
  "name"   => _INTL("Reverse fusion"),
  "parent" => :fusion_menu,
  "effect" => proc { |pkmn, pkmnid, heldpoke, settingUpBattle, screen|
    if !pkmnid.is_a?(Integer) || !FusionHandlers.reverse_party_pokemon(pkmnid)
      screen.pbDisplay(_INTL("Only fused Pokémon in the party can be reversed."))
      next false
    end
    screen.pbHardRefresh
    screen.pbDisplay(_INTL("Swapped the head and body of {1}.", $player.party[pkmnid].name))
    next true
  }
})

#==================================================================
# Main debug menu
#==================================================================
MenuHandlers.add(:debug_menu, :clear_fusion_cache, {
  "name"        => _INTL("Clear fusion sprite cache"),
  "parent"      => :pokemon_menu,
  "description" => _INTL("Regenerate fusion graphics and pick up newly added custom sprites."),
  "effect"      => proc {
    FusionSprites.clear_cache
    FusionFollowers.apply_to_follower
    pbMessage(_INTL("The fusion sprite cache was cleared."))
  }
})
