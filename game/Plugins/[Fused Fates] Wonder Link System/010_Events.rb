#================================================================================================
# Pokémon Fused Fates Wonder Link System - 010_Events.rb
#================================================================================================
# Script calls for map events (PCs, terminals and NPCs). Each returns whether something
# happened, so it can be used in a Conditional Branch.

# @brief A Wonder Link terminal offering every Wonder Link feature in one menu.
# @param safari [Boolean] Include the Safari Zone option (e.g. at the Safari Zone gate).
# @return [Boolean] Whether anything was shared or redeemed.
def pbWonderLinkTerminal(safari = false)
  commands = []
  actions  = []
  commands.push(_INTL("Share my code"));  actions.push(proc { WonderLink.export_party })
  commands.push(_INTL("Offer a trade"));  actions.push(proc { WonderLink.export_trade })
  commands.push(_INTL("Send a gift"));    actions.push(proc { WonderLink.export_gift })
  commands.push(_INTL("Battle a code"));  actions.push(proc { WonderLink::Battles.battle_from_input })
  commands.push(_INTL("Redeem a trade")); actions.push(proc { WonderLink::Trades.redeem_trade })
  commands.push(_INTL("Redeem a gift"));  actions.push(proc { WonderLink::Trades.redeem_gift })
  if safari
    commands.push(_INTL("Link Safari Zone")); actions.push(proc { WonderLink::Safari.redeem_from_input })
  end
  commands.push(_INTL("Cancel"))
  choice = pbMessage(_INTL("Welcome to Wonder Link! What would you like to do?"), commands, commands.length)
  return false if choice < 0 || choice >= actions.length
  return actions[choice].call ? true : false
end

# @brief Copies the player's profile code to the clipboard.
# @return [Boolean]
def pbWonderLinkShare
  return WonderLink.export_party
end

# @brief Asks for a profile code and battles its trainer (once per code per day).
# @return [Boolean] Whether the player won.
def pbWonderLinkBattle
  return WonderLink::Battles.battle_from_input
end

# @brief Asks for a trade code and trades for its Pokémon (once per code).
# @return [Boolean] Whether a trade happened.
def pbWonderLinkTrade
  return WonderLink::Trades.redeem_trade
end

# @brief Asks for a gift code and receives its Pokémon (once per code).
# @return [Boolean] Whether the Pokémon was received.
def pbWonderLinkGift
  return WonderLink::Trades.redeem_gift
end

# @brief Asks for a profile code and boosts its Safari species today (once per code per day).
# @return [Boolean] Whether the boost was applied.
def pbWonderLinkSafari
  return WonderLink::Safari.redeem_from_input
end
