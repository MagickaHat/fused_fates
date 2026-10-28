#================================================================================================
# Pokémon Fused Fates Character Customization System - 008_Debug.rb
#================================================================================================

#==================================================================
# Debug menu
#==================================================================
MenuHandlers.add(:debug_menu, :customization_menu, {
  "name"        => _INTL("Character customization..."),
  "parent"      => :player_menu,
  "description" => _INTL("Edit the player's appearance, unlock parts and inspect composited sprites."),
  "always_show" => false
})

MenuHandlers.add(:debug_menu, :customization_editor, {
  "name"        => _INTL("Open editor"),
  "parent"      => :customization_menu,
  "description" => _INTL("Open the character editor."),
  "effect"      => proc {
    pbCustomizeCharacter
  }
})

MenuHandlers.add(:debug_menu, :customization_unlock_all, {
  "name"        => _INTL("Unlock all parts"),
  "parent"      => :customization_menu,
  "description" => _INTL("Let the player wear every part outside debug mode too."),
  "effect"      => proc {
    GameData::PlayerPart.each { |part| $player.unlock_part(part.id) }
    pbMessage(_INTL("Unlocked {1} parts.", GameData::PlayerPart::DATA.length))
  }
})

MenuHandlers.add(:debug_menu, :customization_lock_all, {
  "name"        => _INTL("Re-lock all parts"),
  "parent"      => :customization_menu,
  "description" => _INTL("Forget every part unlocked during play (worn parts stay worn)."),
  "effect"      => proc {
    $player.unlocked_parts.clear
    pbMessage(_INTL("Only parts unlocked in player_parts.txt are available now."))
  }
})

MenuHandlers.add(:debug_menu, :customization_reset, {
  "name"        => _INTL("Reset appearance"),
  "parent"      => :customization_menu,
  "description" => _INTL("Go back to the default parts and colors."),
  "effect"      => proc {
    next if !pbConfirmMessage(_INTL("Reset the player's appearance to the defaults?"))
    $player.appearance = PlayerAppearance.new
    CharacterCustomization.refresh
    pbMessage(_INTL("The player's appearance was reset."))
  }
})

MenuHandlers.add(:debug_menu, :customization_art_report, {
  "name"        => _INTL("Check part art"),
  "parent"      => :customization_menu,
  "description" => _INTL("List which sprite contexts have art for the current appearance (details in the console)."),
  "effect"      => proc {
    appearance = $player.appearance
    found = []
    CustomizationSettings::CONTEXTS.each_key do |context|
      art = PlayerCompositor.art_context(context, appearance)
      found.push(context) if art
      Console.echoln("#{context}: " + (art ? "drawn with #{art} art" : "stock sprite")) if defined?(Console)
      appearance.worn_parts.each do |part|
        (1..part.color_slots).each do |region|
          path = PlayerCompositor.layer_path(context, part, region)
          Console.echoln("  missing #{path}") if defined?(Console) && part.supports?(context) && !PlayerCompositor.resolve(path)
        end
      end
    end
    if found.empty?
      pbMessage(_INTL("No context has art yet, so the stock sprites are used."))
    else
      names = found.map { |c| _INTL(CustomizationSettings::CONTEXTS[c][:name]) }
      pbMessage(_INTL("Custom sprites are used for: {1}.", names.join(", ")))
    end
  }
})

MenuHandlers.add(:debug_menu, :customization_dump, {
  "name"        => _INTL("Dump composited sprites"),
  "parent"      => :customization_menu,
  "description" => _INTL("Save the player's composited sprite for every context as PNG files."),
  "effect"      => proc {
    saved = 0
    CustomizationSettings::CONTEXTS.each_key do |context|
      bmp = PlayerCompositor.bitmap_for(context, $player.appearance)
      next if !bmp
      saved += 1 if SpriteUtils.dump(bmp, "player_#{context}")
      bmp.dispose
    end
    if saved > 0
      pbMessage(_INTL("Saved {1} sprites to {2}.", saved, UtilitySettings::DUMP_FOLDER))
    else
      pbMessage(_INTL("There was nothing to save."))
    end
  }
})

MenuHandlers.add(:debug_menu, :customization_code, {
  "name"        => _INTL("Print appearance code"),
  "parent"      => :customization_menu,
  "description" => _INTL("Show the share code for the current appearance and print it in the console."),
  "effect"      => proc {
    code = $player.appearance.to_code
    Console.echoln("Appearance code: #{code}") if defined?(Console)
    pbMessage(_INTL("{1}", code))
  }
})

MenuHandlers.add(:debug_menu, :customization_cache_stats, {
  "name"        => _INTL("Show sprite cache statistics"),
  "parent"      => :customization_menu,
  "description" => _INTL("Show how many composited player sprites are cached."),
  "effect"      => proc {
    pbMessage(UtilityDebug.stats_line(_INTL("Player sprite cache"), PlayerCompositor.cache_stats))
  }
})

MenuHandlers.add(:debug_menu, :customization_clear_cache, {
  "name"        => _INTL("Clear sprite cache"),
  "parent"      => :customization_menu,
  "description" => _INTL("Re-composite the player's sprites and pick up newly added part art."),
  "effect"      => proc {
    PlayerCompositor.clear_cache
    CharacterCustomization.refresh
    pbMessage(_INTL("The player sprite cache was cleared."))
  }
})
