#================================================================================================
# Pokémon Fused Fates Wonder Link System - 007_Underground.rb
#================================================================================================
# Only loaded alongside the Underground System.
#
# The Wonder Link rival is a rival digger whose Secret Base belongs to whoever's profile code was
# redeemed most recently. Like the other rivals they can be battled once a day, and their flag
# can be taken after beating them. Set up a rival base map with:
#   - A rival event that runs the script  pbWonderLinkRival
#   - A flag event named  RivalFlag:wonder_link  (the ID in UNDERGROUND_RIVAL_ID) that runs
#     pbWonderLinkRivalFlag. The Underground hides it automatically once the flag is taken.
#   - Optionally, use  pbWonderLinkRivalReady?  in a Conditional Branch to hide the rival while
#     no code has been redeemed.
if defined?(Underground)

  #==================================================================
  # module WonderLink::UndergroundRival
  #==================================================================
  # @brief The Underground's Wonder Link rival digger.
  module WonderLink
    module UndergroundRival
      module_function

      # @brief Rival ID used in the Underground's daily lists.
      # @return [Symbol]
      def id
        return WonderLinkSettings::UNDERGROUND_RIVAL_ID
      end

      # @brief The current rival, built from the most recently redeemed profile code.
      # @return [NPCTrainer, nil] nil if no valid code has been redeemed.
      def trainer
        code = WonderLink.data.last_profile_code
        return nil if !code
        return WonderLink::Battles.from_code(code)
      end

      # @brief Battles the rival, once per day.
      # @return [Boolean] Whether the player has beaten them today.
      def battle
        rival = trainer
        if !rival
          pbMessage(_INTL("This Secret Base is empty. Link with a friend's Wonder Link code and they might move in!"))
          return false
        end
        d = ::Underground.data
        if d.rivals_beaten.include?(id)
          pbMessage(_INTL("{1}: You got me already today. Come back tomorrow!", rival.name))
          return true
        end
        pbMessage(_INTL("{1}: Welcome to my Secret Base! Let's see what you've got!", rival.name))
        return false if !WonderLink::Battles.battle(rival)
        d.rivals_beaten.push(id)
        d.stats[:rival_wins] += 1
        return true
      end

      # @brief Takes the rival's flag, once per day, after beating them today.
      # @return [Boolean] Whether the flag was taken.
      def take_flag
        rival = trainer
        return false if !rival
        d = ::Underground.data
        return false if d.flags_taken.include?(id)
        if !d.rivals_beaten.include?(id)
          pbMessage(_INTL("{1} is guarding this flag. Beat them in a battle first!", rival.name))
          return false
        end
        d.flags_taken.push(id)
        d.stats[:flags] += 1
        pbMessage(_INTL("You took {1}'s flag!", rival.name) + "\\me[Item get]")
        return true
      end
    end
  end

  #==================================================================
  # Script calls
  #==================================================================
  # @brief Wonder Link rival event: battles them once per day.
  # @return [Boolean] Whether the player has beaten them today.
  def pbWonderLinkRival
    return WonderLink::UndergroundRival.battle
  end

  # @brief Wonder Link rival flag event: takes the flag and hides the event.
  def pbWonderLinkRivalFlag
    return if !WonderLink::UndergroundRival.take_flag
    ev = Underground.calling_event
    Underground.set_hidden(ev, true) if ev
  end

  # @brief Whether a profile code has been redeemed, so the Wonder Link rival has someone in it.
  # @return [Boolean]
  def pbWonderLinkRivalReady?
    return !WonderLink.data.last_profile_code.nil?
  end
end
