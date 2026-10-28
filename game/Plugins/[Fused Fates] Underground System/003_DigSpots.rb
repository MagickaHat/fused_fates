#================================================================================================
# Pokémon Fused Fates Underground System - 003_DigSpots.rb
#================================================================================================

#==================================================================
# module Underground
#==================================================================
module Underground
  #==================================================================
  # module DigSpots
  #==================================================================
  # @brief Daily dig spots and Diglett on the tunnel maps.
  #
  # Every DigSpot event on a tunnel map is a possible spot. Each day,
  # DIG_SPOTS_PER_MAP of them are picked (the same ones every time the map
  # is entered that day) and the rest are hidden. Diglett events show
  # until they are found, and come back the next day.
  module DigSpots
    module_function

    # @brief The dig spot event IDs active today on a map.
    # @param map_id [Integer]
    # @param event_ids [Array<Integer>] Every DigSpot event ID on the map.
    # @return [Array<Integer>]
    def active_ids(map_id, event_ids)
      rng = Underground.seeded_rng(Underground.data.day_key, map_id, "dig")
      return event_ids.sort.shuffle(random: rng).first(UndergroundSettings::DIG_SPOTS_PER_MAP)
    end

    # @brief Shows today's dig spots and unfound Diglett on the current map,
    # and hides everything else.
    def refresh
      return unless UndergroundSettings::TUNNEL_MAPS.include?($game_map.map_id)
      d = Underground.data
      map_id = $game_map.map_id
      spots = Underground.events_named(UndergroundSettings::EVENT_DIG_SPOT)
      active = active_ids(map_id, spots.map(&:id))
      spots.each do |ev|
        dug = d.dug_spots.include?([map_id, ev.id])
        Underground.set_hidden(ev, dug || !active.include?(ev.id))
      end
      Underground.events_named(UndergroundSettings::EVENT_DIGLETT).each do |ev|
        Underground.set_hidden(ev, d.diglett_found.include?([map_id, ev.id]))
      end
    end

    # @brief Fills the Diglett meter by one, granting bonus digs when it's full.
    # @return [Boolean] Whether the meter filled.
    def add_diglett
      d = Underground.data
      d.diglett_meter += 1
      d.stats[:digletts] += 1
      return false if d.diglett_meter < UndergroundSettings::DIGLETTS_PER_BONUS
      d.diglett_meter = 0
      d.bonus_digs += UndergroundSettings::BONUS_DIGS_PER_FILL
      return true
    end
  end
end

# @brief Dig spot event: starts mining and uses the spot up for today.
# Call it from a DigSpot event's page 1. Name the event "DigSpot:name" to use
# MINING_TABLES[:name] instead of the map's table.
def pbUndergroundDig
  ev = Underground.calling_event
  return unless ev
  d = Underground.data
  key = [ev.map_id, ev.id]
  return if d.dug_spots.include?(key)
  return unless pbConfirmMessage(_INTL("Something sparkles in the wall. Dig here?"))
  Underground::Mining.start(ev.map_id, Underground.event_tag(ev)[1])
  d.dug_spots.push(key)
  Underground.set_hidden(ev, true)
end

# @brief Diglett event: adds to the Diglett meter and hides it until tomorrow.
# Call it from a Diglett event's page 1.
def pbUndergroundDiglett
  ev = Underground.calling_event
  return unless ev
  d = Underground.data
  key = [ev.map_id, ev.id]
  return if d.diglett_found.include?(key)
  d.diglett_found.push(key)
  pbSEPlay("Mining ping")
  pbMessage(_INTL("A Diglett popped out of the ground... and dug away again!"))
  if Underground::DigSpots.add_diglett
    pbMessage(_INTL("The Diglett meter is full! Your next {1} digs are bonus digs!",
                    d.bonus_digs))
  else
    pbMessage(_INTL("Diglett meter: {1}/{2}",
                    d.diglett_meter, UndergroundSettings::DIGLETTS_PER_BONUS))
  end
  Underground.set_hidden(ev, true)
end

EventHandlers.add(:on_enter_map, :underground_dig_spots,
  proc { |_old_map_id|
    Underground::DigSpots.refresh if Underground.in_underground?
  }
)
