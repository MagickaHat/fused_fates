#================================================================================================
# Pokémon Fused Fates Underground System - 010_Transit.rb
#================================================================================================

#==================================================================
# module Underground
#==================================================================
module Underground
  #-----------------------------------------------------------------------------
  # Lines
  #-----------------------------------------------------------------------------
  # @brief Main lines. A line's carts run once it is in repaired_lines.
  LINES = {
    oreburgh: { name: "Oreburgh Line" }, # west of Mt. Coronet
    veilstone: { name: "Veilstone Line" }, # east of Mt. Coronet
    deep: { name: "Deep Line" } # under Mt. Coronet
  }

  #-----------------------------------------------------------------------------
  # Stations
  # 
  # Positions are [map_id, x, y, direction] (2 = down, 4 = left,
  # 6 = right, 8 = up).
  #   :lines       - lines this station's platform serves. A station on
  #                 two lines is an interchange.
  #   :underground - where the player arrives after taking the ladder down
  #   :surface     - where the player arrives after climbing out
  #   :platform    - where the player arrives by cart
  #-----------------------------------------------------------------------------
  
  STATIONS = {
    jubilife: {
      name: "Jubilife Station", lines: [:oreburgh],
      underground: [0, 0, 0, 0], surface: [0, 0, 0, 0], platform: [0, 0, 0, 0]
    },
    oreburgh: {
      name: "Oreburgh Station", lines: [:oreburgh],
      underground: [0, 0, 0, 0], surface: [0, 0, 0, 0], platform: [0, 0, 0, 0]
    },
    hearthome: {
      name: "Hearthome Station", lines: [:oreburgh, :deep],
      underground: [0, 0, 0, 0], surface: [0, 0, 0, 0], platform: [0, 0, 0, 0]
    },
    veilstone: {
      name: "Veilstone Station", lines: [:veilstone],
      underground: [0, 0, 0, 0], surface: [0, 0, 0, 0], platform: [0, 0, 0, 0]
    }
  }

  #-----------------------------------------------------------------------------
  # Cave-ins
  #
  # Every condition given must be met:
  #   :badges - minimum badge count
  #   :stage  - minimum Underground Man mission stage
  #   :switch - game switch that must be ON
  #-----------------------------------------------------------------------------
  
  BARRIERS = {
    oreburgh_north: { badges: 1, message: "Loose rock blocks the way north." },
    coronet_deep:   { stage: 7, switch: 0,
                      message: "The tunnel ends in solid bedrock. Something deeper might break through." },
    veilstone_east: { badges: 3, message: "A cave-in blocks the tunnel east." }
  }

  #==================================================================
  # module Transit
  #==================================================================
  module Transit
    module_function

    # @brief Whether every condition of a barrier is met.
    # @param barrier_id [Symbol]
    # @return [Boolean]
    def barrier_open?(barrier_id)
      b = BARRIERS[barrier_id]
      return true unless b
      return false if b[:badges] && $player.badge_count < b[:badges]
      return false if b[:stage] && Underground.data.mission_stage < b[:stage]
      return false if b[:switch] && !$game_switches[b[:switch]]
      return true
    end

    # @brief Hides every cave-in on the current map whose conditions are met.
    def refresh_barriers
      $game_map.events.each_value do |ev|
        next unless ev.name.start_with?("CaveIn:")
        id = ev.name.split(":", 2)[1].to_sym
        Underground.set_hidden(ev, barrier_open?(id))
      end
      $game_map.need_refresh = true
    end

    # @brief Whether a station has been discovered from the surface.
    # @param station_id [Symbol]
    # @return [Boolean]
    def discovered?(station_id)
      return Underground.data.discovered_stations.include?(station_id)
    end

    # @brief Stations reachable by cart from a station: discovered stations
    # sharing at least one repaired line with it.
    # @param from_id [Symbol]
    # @return [Array<Symbol>]
    def cart_destinations(from_id)
      repaired = Underground.data.repaired_lines
      lines = STATIONS[from_id][:lines] & repaired
      return STATIONS.keys.select do |id|
        next false if id == from_id || !discovered?(id)
        next (STATIONS[id][:lines] & lines).any?
      end
    end

    # @brief Moves the player, using the same pattern as v21.1's Fly.
    # @param dest [Array] [map_id, x, y, direction]
    def transfer(dest)
      map_id, x, y, dir = dest
      pbFadeOutIn do
        $game_temp.player_new_map_id    = map_id
        $game_temp.player_new_x         = x
        $game_temp.player_new_y         = y
        $game_temp.player_new_direction = dir
        $scene.transfer_player
        $game_map.autoplay
        $game_map.refresh
      end
    end
  end
end

# @brief Surface entrance: discovers the station and takes the player down.
# @param station_id [Symbol]
def pbUndergroundEnter(station_id)
  station = Underground::STATIONS[station_id]
  return unless station
  d = Underground.data
  unless d.discovered_stations.include?(station_id)
    d.discovered_stations.push(station_id)
    pbMessage(_INTL("{1} was added to your Underground map!", station[:name]))
  end
  Underground::Transit.transfer(station[:underground])
end

# @brief Exit ladder: climbs out, but only at discovered stations.
# @param station_id [Symbol]
def pbUndergroundExit(station_id)
  station = Underground::STATIONS[station_id]
  return unless station
  unless Underground::Transit.discovered?(station_id)
    pbMessage(_INTL("The hatch is sealed from above. Maybe it opens from the town side."))
    return
  end
  Underground::Transit.transfer(station[:surface])
end

# @brief Cart platform: pick a destination station and ride there.
# @param station_id [Symbol] The station this platform is in.
def pbUndergroundCart(station_id)
  station = Underground::STATIONS[station_id]
  return unless station
  if (station[:lines] & Underground.data.repaired_lines).empty?
    pbMessage(_INTL("The rails here are still broken."))
    return
  end
  dests = Underground::Transit.cart_destinations(station_id)
  if dests.empty?
    pbMessage(_INTL("There's nowhere to ride to yet. Find more stations from the surface!"))
    return
  end
  cmds = dests.map { |id| Underground::STATIONS[id][:name] }
  cmds.push(_INTL("Cancel"))
  choice = pbMessage(_INTL("Where would you like to ride?"), cmds, -1)
  return if choice < 0 || choice >= dests.length
  Underground::Transit.transfer(Underground::STATIONS[dests[choice]][:platform])
end

# @brief Cave-in interaction: shows why the way is blocked.
# @param barrier_id [Symbol]
def pbUndergroundBarrier(barrier_id)
  return if Underground::Transit.barrier_open?(barrier_id)
  msg = Underground::BARRIERS.dig(barrier_id, :message) || "The way is blocked."
  pbMessage(_INTL(msg))
end

EventHandlers.add(:on_enter_map, :underground_barriers,
  proc { |_old_map_id|
    Underground::Transit.refresh_barriers if Underground.in_underground?
  }
)