#================================================================================================
# Pokémon Fused Fates Character Customization System - 011_Services.rb
#================================================================================================

#==================================================================
# Script helpers
#==================================================================
# Every way to open the character editor from an event's Script command. They all edit a copy
# of the player's look and only apply it when the player keeps (and pays for) the changes.
#
#   pbCharacterCreation                                   # the intro
#   pbCustomizeCharacter                                  # a mirror: everything, free
#   pbCosmeticShop([:CAP, :SCARF], title: "Boutique")     # try on and buy
#   pbStylist([:Hair, :Eyes], fee: 500, title: "Salon")   # restyle some slots

# @brief Opens the character editor.
# @param config [CustomizationConfig, nil] The session's rules; nil gives the full mirror editor.
# @param allow_cancel [Boolean] Only used without a config: whether the player may leave
#   without keeping their changes.
# @return [Boolean] Whether the player's appearance changed.
def pbCustomizeCharacter(config = nil, allow_cancel: true)
  config ||= CustomizationConfig.new(allow_cancel: allow_cancel)
  editing = $player.appearance.snapshot.sanitize!
  before = $player.appearance.snapshot
  keep = false
  pbFadeOutIn do
    screen = CharacterEditor_Screen.new(CharacterEditor_Scene.new, editing, config)
    keep = screen.pbStartScreen
  end
  return false if !keep || editing == before
  $player.appearance = editing
  CharacterCustomization.refresh
  return true
end

# @brief Lets the player create their look during the intro: body basics only
# (CustomizationSettings::INTRO_SLOTS) and no way to cancel.
# The look is kept every time the editor closes, so calling this again (e.g. after the player
# says they aren't happy yet) carries on from where they left off.
# @return [Boolean] Whether the player's appearance changed.
def pbCharacterCreation
  return pbCustomizeCharacter(CustomizationConfig.intro)
end

# @brief Opens a cosmetics shop. Every part in stock can be tried on; parts the player buys
# are unlocked for good.
# @param stock [Array<Symbol>] Part ids for sale.
# @param title [String, nil] Shop name shown in the editor's header.
# @return [Boolean] Whether the player's appearance changed.
def pbCosmeticShop(stock, title: nil)
  config = CustomizationConfig.boutique(stock, title: title)
  if config.stock.empty?
    pbMessage(_INTL("There's nothing for sale right now."))
    return false
  end
  return pbCustomizeCharacter(config)
end

# @brief Opens a styling service (hair salon, tailor...) for some slots, using parts the
# player already owns.
# @param slots [Array<Symbol>] Slots the service handles, e.g. [:Hair, :Eyes].
# @param fee [Integer] Charged only if the look changed; 0 is free.
# @param title [String, nil] Service name shown in the editor's header.
# @return [Boolean] Whether the player's appearance changed.
def pbStylist(slots, fee: 0, title: nil)
  return pbCustomizeCharacter(CustomizationConfig.stylist(slots, fee: fee, title: title))
end
