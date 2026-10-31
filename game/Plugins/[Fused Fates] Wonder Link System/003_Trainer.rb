#================================================================================================
# Pokémon Fused Fates Wonder Link System - 003_Trainer.rb
#================================================================================================

#==================================================================
# module WonderLink::Battles
#==================================================================
# @brief Battles against trainers generated from profile codes.
module WonderLink
  module Battles
    module_function

    # @brief Builds an opponent from a decoded profile code.
    # The sharer's own trainer type is used if it exists in this game, otherwise one of
    # FALLBACK_TRAINER_TYPES. The trainer type's BaseMoney sets the prize money as usual.
    # @param decoded [Hash] A decoded :party code.
    # @return [NPCTrainer]
    def build(decoded)
      owner = decoded[:owner]
      type = owner[:trainer_type]
      if !type || !GameData::TrainerType.exists?(type)
        fallbacks = WonderLinkSettings::FALLBACK_TRAINER_TYPES
        type = fallbacks[owner[:gender]] || fallbacks.values.first
      end
      trainer = NPCTrainer.new(WonderLink.owner_name(decoded), type)
      trainer.id        = owner[:id]
      trainer.party     = WonderLink.import_party(decoded)
      trainer.lose_text = _INTL(WonderLinkSettings::TRAINER_LOSE_TEXT)
      return trainer
    end

    # @brief Builds an opponent straight from code text.
    # @param code [String]
    # @return [NPCTrainer, nil] nil if the code isn't a valid profile code.
    def from_code(code)
      decoded = WonderLink.decode(code)
      return nil if !decoded || decoded[:type] != :party
      return build(decoded)
    end

    # @brief Fights a generated trainer, paying the bonus prize money if the player wins.
    # @param trainer [NPCTrainer]
    # @return [Boolean] Whether the player won.
    def battle(trainer)
      setBattleRule("canLose") if WonderLinkSettings::BATTLE_CAN_LOSE
      won = (TrainerBattle.start_core(trainer) == 1)
      pay_bonus(trainer) if won
      return won
    end

    # @brief Pays BONUS_PRIZE_PER_LEVEL on top of the normal prize money.
    # @param trainer [NPCTrainer]
    def pay_bonus(trainer)
      bonus = WonderLinkSettings::BONUS_PRIZE_PER_LEVEL * (trainer.party.last&.level || 0)
      return if bonus <= 0
      $player.money += bonus
      pbMessage(_INTL("You got a Wonder Link bonus of ${1}!", bonus.to_s_formatted))
    end

    # @brief Asks for a profile code and battles its trainer, once per code per day.
    # @return [Boolean] Whether the player won.
    def battle_from_input
      decoded = WonderLink.ask_for_code(_INTL("Enter a trainer's Wonder Link code to battle them."), [:party])
      return false if !decoded
      return false if !WonderLink.use_daily(decoded, :battle)
      WonderLink.on_profile_redeemed(decoded)
      trainer = build(decoded)
      pbMessage(_INTL("Linked with {1}! {1} wants to battle!", trainer.name))
      return battle(trainer)
    end
  end
end
