#================================================================================================
# Pokémon Fused Fates Wonder Link System - 004_Trade.rb
#================================================================================================

#==================================================================
# module WonderLink::Trades
#==================================================================
# @brief Redeeming trade and gift codes. Each code can be redeemed once per save file, and the
# sharer keeps their own Pokémon.
module WonderLink
  module Trades
    module_function

    # @brief Asks for a trade code, then trades one of the player's Pokémon for its Pokémon.
    # @return [Boolean] Whether a trade happened.
    def redeem_trade
      decoded = WonderLink.ask_for_code(_INTL("Enter a Wonder Link trade code."), [:trade])
      return false if !decoded || already_redeemed?(decoded)
      pkmn  = WonderLink.build_pokemon(decoded[:pokemon])
      owner = WonderLink.owner_name(decoded)
      return false if !pbConfirmMessage(_INTL("{1} is offering {2} (Lv. {3}) in a trade. Trade for it?",
                                              owner, pkmn.name, pkmn.level))
      pbMessage(_INTL("Which Pokémon will you send to {1}?", owner))
      index = WonderLink.choose_party_pokemon(proc { |p| !p.egg? }, true)
      return false if index < 0
      WonderLink.data.mark_redeemed(decoded[:digest])
      ot = decoded[:pokemon]
      pbStartTrade(index, pkmn, pkmn.name, owner, decoded[:owner][:gender])
      # pbStartTrade gives the Pokémon a random foreign ID; put back its real Original Trainer
      received = $player.party[index]
      received.owner = Pokemon::Owner.new(ot[:ot_id], ot[:ot_name], ot[:ot_gender], 2)
      received.obtain_text = _INTL("Wonder Link")
      return true
    end

    # @brief Asks for a gift code and gives the player its Pokémon.
    # @return [Boolean] Whether the Pokémon was received.
    def redeem_gift
      decoded = WonderLink.ask_for_code(_INTL("Enter a Wonder Link gift code."), [:gift])
      return false if !decoded || already_redeemed?(decoded)
      if pbBoxesFull?
        pbMessage(_INTL("There's no more room for Pokémon! Make some space and try again."))
        return false
      end
      pkmn  = WonderLink.build_pokemon(decoded[:pokemon])
      owner = WonderLink.owner_name(decoded)
      return false if !pbConfirmMessage(_INTL("{1} sent you {2} (Lv. {3}) as a gift! Accept it?",
                                              owner, pkmn.name, pkmn.level))
      WonderLink.data.mark_redeemed(decoded[:digest])
      give(pkmn, owner)
      return true
    end

    # @brief Checks the one-redemption rule, telling the player if the code was already used.
    # @param decoded [Hash]
    # @return [Boolean] Whether the code was already redeemed.
    def already_redeemed?(decoded)
      return false if !WonderLink.data.redeemed?(decoded[:digest])
      pbMessage(_INTL("That Wonder Link code has already been redeemed."))
      return true
    end

    # @brief Adds a received Pokémon to the party or PC, registering it in the Pokédex.
    # @param pkmn [Pokemon]
    # @param owner [String] Who sent it.
    def give(pkmn, owner)
      pkmn.obtain_method = 2   # Traded
      pkmn.obtain_text   = _INTL("Wonder Link")
      pbMessage(_INTL("{1} received {2} from {3}!", $player.name, pkmn.name, owner) + "\\me[Pkmn get]\\wtnp[80]")
      $player.pokedex.set_seen(pkmn.species)
      $player.pokedex.set_owned(pkmn.species)
      $player.pokedex.register(pkmn)
      pbStorePokemon(pkmn)
    end
  end
end
