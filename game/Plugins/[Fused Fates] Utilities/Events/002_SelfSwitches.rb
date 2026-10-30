#================================================================================================
# Pokémon Fused Fates Utilities/Events - 002_SelfSwitches.rb
#================================================================================================

#==================================================================
# module EventUtils (self switches)
#==================================================================
# @brief Self switches of any event on any map, by event ID or name.
module EventUtils
  SELF_SWITCH_LETTERS = %w[A B C D].freeze

  module_function

  # @brief Reads an event's self switch.
  # @param event [Integer, String, Regexp, Game_Event] Event ID or name (see EventUtils).
  # @param letter [String] "A", "B", "C" or "D".
  # @param map_id [Integer, nil] nil for the current map.
  # @return [Boolean]
  def self_switch(event, letter = "A", map_id = nil)
    map_id ||= event.is_a?(Game_Event) ? event.map_id : $game_map.map_id
    id = event_id(event, map_id)
    return false if !id
    return $game_self_switches[[map_id, id, letter.to_s.upcase]] ? true : false
  end

  # @brief Sets an event's self switch and refreshes the map if it is loaded.
  # @param event [Integer, String, Regexp, Game_Event] Event ID or name (see EventUtils).
  # @param letter [String] "A", "B", "C" or "D".
  # @param value [Boolean]
  # @param map_id [Integer, nil] nil for the current map.
  # @return [Boolean] Whether the event was found.
  def set_self_switch(event, letter = "A", value = true, map_id = nil)
    map_id ||= event.is_a?(Game_Event) ? event.map_id : $game_map.map_id
    id = event_id(event, map_id)
    return false if !id
    key = [map_id, id, letter.to_s.upcase]
    old_value = $game_self_switches[key]
    $game_self_switches[key] = value
    refresh_map(map_id) if old_value != value
    return true
  end

  # @brief Turns off self switches for every event on a map.
  # @param map_id [Integer, nil] nil for the current map.
  # @param letters [Array<String>] Which switches to clear.
  def reset_self_switches(map_id = nil, letters = SELF_SWITCH_LETTERS)
    map_id ||= $game_map.map_id
    letters = letters.map { |l| l.to_s.upcase }
    changed = false
    $game_self_switches.instance_variable_get(:@data).keys.each do |key|   # No public way to list them
      next if key[0] != map_id || !letters.include?(key[2])
      changed = true if $game_self_switches[key]
      $game_self_switches[key] = false
    end
    refresh_map(map_id) if changed
  end

  # @brief Makes a loaded map re-check its events' pages.
  # @param map_id [Integer]
  def refresh_map(map_id)
    return if !loaded_map?(map_id)
    map = (map_id == $game_map.map_id) ? $game_map : $map_factory.getMap(map_id, false)
    map.need_refresh = true
  end
end
