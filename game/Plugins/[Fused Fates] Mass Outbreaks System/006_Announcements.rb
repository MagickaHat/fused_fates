#================================================================================================
# Pokémon Fused Fates Mass Outbreaks System - 006_Announcements.rb
#================================================================================================
# @brief How the player hears about outbreaks, DPPt style: a TV, a phone call
# or an NPC event runs the pbMassOutbreakNews script call. Also holds the
# tier-up message shown after battle.

#==================================================================
# module MassOutbreaks
#==================================================================
module MassOutbreaks
  # @brief Display name of an outbreak's Pokémon, including its form.
  # @param e [Hash] Pool entry.
  # @return [String]
  def self.species_name(e)
    return GameData::Species.get_species_form(e[:species], e[:form]).name
  end

  # @brief Display name of an outbreak's map.
  # @param e [Hash] Pool entry.
  # @return [String]
  def self.map_name(e)
    return pbGetMapNameFromId(e[:map])
  end

  # @brief One news line describing an active outbreak.
  # @param e [Hash] Pool entry.
  # @return [String]
  def self.describe(e)
    case e[:category]
    when :water
      text = _INTL("There's a mass outbreak of {1} in the waters of {2}!", species_name(e), map_name(e))
    when :fishing
      text = _INTL("Lots of {1} are biting at {2}!", species_name(e), map_name(e))
    when :cave
      text = _INTL("There's a mass outbreak of {1} in {2}!", species_name(e), map_name(e))
    else
      text = _INTL("There's a mass outbreak of {1} on {2}!", species_name(e), map_name(e))
    end
    hours = hours_left(e[:id])
    if hours
      if hours <= 1
        text += " " + _INTL("It should die down within the hour.")
      else
        text += " " + _INTL("It should last about {1} more hours.", hours)
      end
    end
    return text
  end

  # @brief Show the message for an outbreak that just reached a new tier.
  # @param e [Hash] Pool entry.
  def self.announce_tier_up(e)
    pbMessage(_INTL("The {1} outbreak on {2} is getting more intense!", species_name(e), map_name(e)))
  end

  # @brief Mark an outbreak's species as seen, if MARK_SEEN_ON_ANNOUNCE is on.
  # @param e [Hash] Pool entry.
  def self.mark_seen(e)
    return if !MARK_SEEN_ON_ANNOUNCE
    $player.pokedex.set_seen(e[:species])
  end
end

#==================================================================
# Script calls
#==================================================================
# @brief Read out the current outbreaks, e.g. from a TV or NPC event.
# Each active outbreak gets one message, and its species is marked as seen
# when MARK_SEEN_ON_ANNOUNCE is on. Use the result in a Conditional Branch
# (Script: pbMassOutbreakNews) to react to there being no news.
# @param show_none [Boolean] Show a message when nothing is going on.
# @return [Boolean] Whether any outbreak was announced.
def pbMassOutbreakNews(show_none = true)
  list = MassOutbreaks.active
  if list.empty?
    pbMessage(_INTL("There are no reports of mass outbreaks right now.")) if show_none
    return false
  end
  list.each do |e, _rec|
    MassOutbreaks.mark_seen(e)
    pbMessage(MassOutbreaks.describe(e))
  end
  return true
end

# @brief Whether an outbreak is going on, anywhere or on one map.
# @param map_id [Integer, nil] Map to check, or nil for anywhere.
# @return [Boolean]
def pbMassOutbreakActive?(map_id = nil)
  list = MassOutbreaks.active
  return !list.empty? if !map_id
  return list.any? { |e, _rec| e[:map] == map_id }
end

# @brief How many outbreaks are going on right now.
# @return [Integer]
def pbMassOutbreakCount
  return MassOutbreaks.active.length
end
