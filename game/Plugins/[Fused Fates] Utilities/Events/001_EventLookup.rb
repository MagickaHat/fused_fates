#================================================================================================
# Pokémon Fused Fates Utilities/Events - 001_EventLookup.rb
#================================================================================================

#==================================================================
# module EventUtils
#==================================================================
# @brief Helpers for scripting events and cutscenes.
#
# Wherever a helper takes a character, it accepts a "ref", which is any of:
#   - an Integer event ID (-1 is the player, 0 is the event running the map interpreter),
#   - a String event name (exact match first, then case-insensitive),
#   - a Regexp matched against event names,
#   - a Game_Character, which is used as it is.
module EventUtils
  module_function

  # @brief Resolves a ref to a character on a loaded map.
  # @param ref [Integer, String, Regexp, Game_Character]
  # @param map_id [Integer, nil] Map to look on; nil for the current map.
  # @return [Game_Character, nil] nil if nothing matches.
  def character(ref, map_id = nil)
    case ref
    when Game_Character then return ref
    when String, Regexp then return find(ref, map_id)
    when Integer
      return $game_player if ref == -1
      return pbMapInterpreter&.get_self if ref == 0 && !map_id
      return events_on(map_id)[ref]
    end
    return nil
  end

  # @brief Like character, but raises (in debug mode) or logs when nothing matches.
  # @param ref [Integer, String, Regexp, Game_Character]
  # @param map_id [Integer, nil]
  # @return [Game_Character, nil]
  def character!(ref, map_id = nil)
    chara = character(ref, map_id)
    DevLog.assert(chara, "EventUtils: no event matches #{ref.inspect}") if !chara
    return chara
  end

  # @brief Finds the first event on a loaded map whose name matches.
  # @param name [String, Regexp]
  # @param map_id [Integer, nil] nil for the current map.
  # @return [Game_Event, nil]
  def find(name, map_id = nil)
    events = events_on(map_id).values.sort_by(&:id)
    return events.find { |e| e.name.match?(name) } if name.is_a?(Regexp)
    return events.find { |e| e.name == name } ||
           events.find { |e| e.name.casecmp?(name) }
  end

  # @brief Finds every event on a loaded map whose name matches.
  # @param pattern [String, Regexp] A String must match the whole name (ignoring case).
  # @param map_id [Integer, nil] nil for the current map.
  # @return [Array<Game_Event>] Sorted by event ID.
  def find_all(pattern, map_id = nil)
    events = events_on(map_id).values.sort_by(&:id)
    return events.select { |e| e.name.match?(pattern) } if pattern.is_a?(Regexp)
    return events.select { |e| e.name.casecmp?(pattern) }
  end

  # @brief The ID of the event with a given name, for APIs that still want numbers.
  # Unlike find, this also works for maps that aren't loaded (it reads the map file).
  # @param name [String, Regexp, Integer] An Integer is returned unchanged.
  # @param map_id [Integer, nil] nil for the current map.
  # @return [Integer, nil] nil (with a warning) if no event has that name.
  def event_id(name, map_id = nil)
    return name if name.is_a?(Integer)
    return name.id if name.is_a?(Game_Event)
    map_id ||= $game_map.map_id
    if loaded_map?(map_id)
      id = find(name, map_id)&.id
    else
      data = map_data(map_id)&.events&.values&.sort_by(&:id) || []
      found = if name.is_a?(Regexp)
                data.find { |e| e.name.match?(name) }
              else
                data.find { |e| e.name == name } || data.find { |e| e.name.casecmp?(name) }
              end
      id = found&.id
    end
    DevLog.once([:event_id, map_id, name], "EventUtils: no event named #{name.inspect} on map #{map_id}") if !id
    return id
  end

  # @brief The events of a loaded map.
  # @param map_id [Integer, nil] nil for the current map.
  # @return [Hash{Integer => Game_Event}] Empty if the map isn't loaded.
  def events_on(map_id = nil)
    return $game_map&.events || {} if !map_id || map_id == $game_map&.map_id
    return {} if !loaded_map?(map_id)
    return $map_factory.getMap(map_id, false).events || {}
  end

  # @brief Checks whether a map is currently loaded (the current map or a connected one).
  # @param map_id [Integer]
  # @return [Boolean]
  def loaded_map?(map_id)
    return true if map_id == $game_map&.map_id
    return $map_factory ? $map_factory.hasMap?(map_id) : false
  end

  # @brief Reads a map's RPG::Map data from its file, keeping the last few in memory.
  # @param map_id [Integer]
  # @return [RPG::Map, nil] nil if the map file can't be read.
  def map_data(map_id)
    @map_data ||= {}
    return @map_data[map_id] if @map_data.key?(map_id)
    @map_data.delete(@map_data.keys.first) if @map_data.length >= 8
    @map_data[map_id] = DevLog.guard("EventUtils: could not load map #{map_id}") do
      load_data(sprintf("Data/Map%03d.rxdata", map_id))
    end
    return @map_data[map_id]
  end
end

#==================================================================
# class Interpreter
#==================================================================
class Interpreter
  # @brief Finds a character on the current map from inside an event's Script command,
  # e.g. pbEvent("Professor").turn_down. 0 is this event.
  # @param ref [Integer, String, Regexp, Game_Character] See EventUtils.
  # @return [Game_Character, nil]
  def pbEvent(ref = 0)
    return get_character(ref) if ref.is_a?(Integer)
    return EventUtils.character(ref)
  end
end
