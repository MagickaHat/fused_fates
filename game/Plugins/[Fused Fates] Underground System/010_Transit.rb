#================================================================================================
# Pokémon Fused Fates Underground System - 010_Transit.rb
#================================================================================================

#==================================================================
# module Underground
#==================================================================
module Underground
  # Lines, stations and cave-ins are in PBS/underground_lines.txt,
  # PBS/underground_stations.txt and PBS/underground_barriers.txt.

  #==================================================================
  # module Transit
  #==================================================================
  module Transit
    module_function

    # @brief Whether every condition of a barrier is met.
    # @param barrier_id [Symbol]
    # @return [Boolean]
    def barrier_open?(barrier_id)
      b = GameData::UndergroundBarrier.try_get(barrier_id)
      return b.nil? || b.open?
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
      lines = GameData::UndergroundStation.get(from_id).lines & repaired
      ret = []
      GameData::UndergroundStation.each do |station|
        next if station.id == from_id || !discovered?(station.id) || !set?(station.platform)
        ret.push(station.id) if (station.lines & lines).any?
      end
      return ret
    end

    # @brief Whether a position has been filled in (map ID 0 means unset).
    # @param dest [Array, nil] [map_id, x, y, direction]
    # @return [Boolean]
    def set?(dest)
      return !dest.nil? && dest[0].to_i > 0
    end

    # @brief Moves the player, using the same pattern as v21.1's Fly.
    # @param dest [Array] [map_id, x, y, direction]
    # @return [Boolean] false if the position hasn't been set up.
    def transfer(dest)
      unless set?(dest)
        DevLog.warn("Underground: tried to transfer to an unset position #{dest.inspect}")
        pbMessage(_INTL("This way hasn't been dug out yet."))
        return false
      end
      map_id, x, y, dir = dest
      pbFadeOutIn do
        $game_temp.player_new_map_id    = map_id
        $game_temp.player_new_x         = x
        $game_temp.player_new_y         = y
        $game_temp.player_new_direction = (dir.to_i > 0) ? dir : 2
        pbDismountBike
        $scene.transfer_player
        $game_map.autoplay
        $game_map.refresh
      end
      return true
    end
  end
end

# @brief Surface entrance: discovers the station and takes the player down.
# @param station_id [Symbol]
def pbUndergroundEnter(station_id)
  station = GameData::UndergroundStation.try_get(station_id)
  return unless station
  d = Underground.data
  unless d.discovered_stations.include?(station_id)
    d.discovered_stations.push(station_id)
    pbMessage(_INTL("{1} was added to your Underground map!", station.name))
  end
  Underground::Transit.transfer(station.underground)
end

# @brief Exit ladder: climbs out, but only at discovered stations.
# @param station_id [Symbol]
def pbUndergroundExit(station_id)
  station = GameData::UndergroundStation.try_get(station_id)
  return unless station
  unless Underground::Transit.discovered?(station_id)
    pbMessage(_INTL("The hatch is sealed from above. Maybe it opens from the town side."))
    return
  end
  Underground::Transit.transfer(station.surface)
end

# @brief Cart platform: pick a destination station and ride there.
# @param station_id [Symbol] The station this platform is in.
def pbUndergroundCart(station_id)
  station = GameData::UndergroundStation.try_get(station_id)
  return unless station
  if (station.lines & Underground.data.repaired_lines).empty?
    pbMessage(_INTL("The rails here are still broken."))
    return
  end
  dests = Underground::Transit.cart_destinations(station_id)
  if dests.empty?
    pbMessage(_INTL("There's nowhere to ride to yet. Find more stations from the surface!"))
    return
  end
  cmds = dests.map { |id| GameData::UndergroundStation.get(id).name }
  cmds.push(_INTL("Cancel"))
  choice = pbMessage(_INTL("Where would you like to ride?"), cmds, -1)
  return if choice < 0 || choice >= dests.length
  Underground::Transit.transfer(GameData::UndergroundStation.get(dests[choice]).platform)
end

# @brief Cave-in interaction: shows why the way is blocked.
# @param barrier_id [Symbol]
def pbUndergroundBarrier(barrier_id)
  return if Underground::Transit.barrier_open?(barrier_id)
  barrier = GameData::UndergroundBarrier.try_get(barrier_id)
  pbMessage(barrier ? barrier.message : _INTL("The way is blocked."))
end

EventHandlers.add(:on_enter_map, :underground_barriers,
  proc { |_old_map_id|
    Underground::Transit.refresh_barriers if Underground.in_underground?
  }
)
