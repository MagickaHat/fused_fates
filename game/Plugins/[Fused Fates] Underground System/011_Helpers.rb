#================================================================================================
# Pokémon Fused Fates Underground System - 011_Helpers.rb
#================================================================================================

#==================================================================
# module Underground
#==================================================================
module Underground
  module_function

  #-----------------------------------------------------------------------------
  # State
  #-----------------------------------------------------------------------------
  # @brief The Underground save data, with daily state refreshed.
  # @return [UndergroundSaveData]
  def data
    $underground ||= UndergroundSaveData.new
    $underground.refresh_day!
    return $underground
  end

  # @brief Whether a map is part of the Underground: it has the
  # UndergroundSettings::MAP_FLAG flag in its map metadata.
  # @param map_id [Integer] Defaults to the current map.
  # @return [Boolean]
  def in_underground?(map_id = nil)
    map_id ||= $game_map&.map_id
    return false unless map_id
    return GameData::MapMetadata.try_get(map_id)&.has_flag?(UndergroundSettings::MAP_FLAG) || false
  end

  # @brief Maps given an Underground role (tunnel, base room or hideaway)
  # that are missing the map metadata flag.
  # @return [Array<Integer>]
  def unflagged_maps
    ids = UndergroundSettings::TUNNEL_MAPS + UndergroundSettings::BASE_MAPS.values +
          GameData::UndergroundHideaway.keys
    return ids.uniq.reject { |id| in_underground?(id) }
  end

  #-----------------------------------------------------------------------------
  # Events
  #-----------------------------------------------------------------------------
  # @brief Splits an event name like "BaseSlot:2" into its prefix and argument.
  # @param event [Game_Event]
  # @return [Array(String, String)] The argument is nil if there is no colon.
  def event_tag(event)
    prefix, arg = event.name.to_s.split(":", 2)
    return [prefix, arg]
  end

  # @brief Events on the current map whose name starts with a prefix.
  # @param prefix [String]
  # @return [Array<Game_Event>] Sorted by event ID.
  def events_named(prefix)
    return [] unless $game_map
    evs = $game_map.events.values.select { |ev| event_tag(ev)[0] == prefix }
    return evs.sort_by(&:id)
  end

  # @brief The event running the current script command.
  # @return [Game_Event, nil]
  def calling_event
    interp = pbMapInterpreter
    return nil unless interp
    return interp.get_self
  end

  # @brief Shows or hides a placeholder event with its HIDE_SWITCH self switch.
  # @param event [Game_Event]
  # @param hidden [Boolean]
  def set_hidden(event, hidden)
    key = [event.map_id, event.id, UndergroundSettings::HIDE_SWITCH]
    return if !!$game_self_switches[key] == hidden
    $game_self_switches[key] = hidden
    $game_map.need_refresh = true if $game_map
  end

  # @brief Whether a placeholder event is hidden.
  # @param event [Game_Event]
  # @return [Boolean]
  def hidden?(event)
    return !!$game_self_switches[[event.map_id, event.id, UndergroundSettings::HIDE_SWITCH]]
  end

  #-----------------------------------------------------------------------------
  # Event graphics
  #-----------------------------------------------------------------------------
  # @brief Event name prefixes whose graphic the Underground picks.
  GRAPHIC_EVENTS = [UndergroundSettings::EVENT_HIDEAWAY_MON, UndergroundSettings::EVENT_BASE_SLOT,
                    UndergroundSettings::EVENT_GOOD_SLOT]

  # @brief Whether the Underground picks an event's graphic.
  # @param event [Game_Event]
  # @return [Boolean]
  def graphic_event?(event)
    return GRAPHIC_EVENTS.include?(event_tag(event)[0])
  end

  # @brief The graphic an event should show instead of its page graphic.
  # @param event [Game_Event]
  # @return [String, nil] Character name, or nil to keep the page graphic.
  def graphic_for(event)
    return nil if hidden?(event)
    prefix, arg = event_tag(event)
    case prefix
    when UndergroundSettings::EVENT_HIDEAWAY_MON
      return Hideaways.graphic(event)
    when UndergroundSettings::EVENT_BASE_SLOT
      return SecretBase.graphic(:statue, arg.to_i) if SecretBase.base_map?(event.map_id)
    when UndergroundSettings::EVENT_GOOD_SLOT
      return SecretBase.graphic(:good, arg.to_i) if SecretBase.base_map?(event.map_id)
    end
    return nil
  end

  # @brief Reapplies graphic overrides to every event on the current map.
  def refresh_graphics
    return unless $game_map
    $game_map.events.each_value { |ev| ev.apply_underground_graphic }
  end

  # @brief The overworld charset of a species, if its file exists.
  # @param species [Symbol]
  # @return [String, nil] Character name relative to Graphics/Characters.
  def species_charset(species)
    name = format(UndergroundSettings::OVERWORLD_SPRITE_PATH, species.to_s)
    return nil unless pbResolveBitmap("Graphics/Characters/" + name)
    return name
  end

  # @brief The overworld charset of a Pokémon or fusion, reusing the Fusion
  # System's follower sprites. Fusions need either a custom fusion follower
  # or follower sprites for both halves; otherwise the head's sprite is used.
  # @param species [Symbol] Species, or head species for a fusion.
  # @param body [Symbol, nil] Body species for a fusion.
  # @return [String, nil] Character name relative to Graphics/Characters.
  def pokemon_charset(species, body = nil)
    head_name = species_charset(species)
    return head_name if body.nil?
    if defined?(FusionFollowers)
      custom = FusionFollowers.custom_character_name(species, 0, body, 0, false)
      return custom if custom
      if FusionSettings::FOLLOWER_SPRITE_MODE != :custom && head_name && species_charset(body)
        return FusionSprites.virtual_name(:follower, species, 0, body, 0)
      end
    end
    return head_name
  end

  #-----------------------------------------------------------------------------
  # Names
  #-----------------------------------------------------------------------------
  # @brief Display name of a sphere color.
  # @param color [Symbol]
  # @return [String]
  def sphere_name(color)
    return GameData::UndergroundSphere.try_get(color)&.name || color.to_s.capitalize
  end

  # @brief Display name of a statue, built from its species.
  # @param id [Symbol]
  # @return [String]
  def statue_name(id)
    return GameData::UndergroundStatue.try_get(id)&.name || id.to_s
  end

  # @brief Display name of a good.
  # @param id [Symbol]
  # @return [String]
  def good_name(id)
    return GameData::UndergroundGood.try_get(id)&.name || id.to_s
  end

  # @brief Display name of a statue or good.
  # @param id [Symbol]
  # @return [String]
  def ware_name(id)
    return statue?(id) ? statue_name(id) : good_name(id)
  end

  #-----------------------------------------------------------------------------
  # Wares
  #-----------------------------------------------------------------------------
  # @brief Whether an ID is a statue (and not a good).
  # @param id [Symbol]
  # @return [Boolean]
  def statue?(id)
    return GameData::UndergroundStatue.exists?(id)
  end

  # @brief The storage hash a statue or good is kept in.
  # @param id [Symbol]
  # @return [Hash] The save data's statues or goods.
  def storage_for(id)
    return statue?(id) ? data.statues : data.goods
  end

  #-----------------------------------------------------------------------------
  # Granting and spending
  #-----------------------------------------------------------------------------
  # @brief Adds statues to storage.
  # @param id [Symbol] A section of underground_statues.txt.
  # @param qty [Integer]
  def grant_statue(id, qty = 1)
    return DevLog.warn("Underground: unknown statue #{id}") unless statue?(id)
    data.statues[id] += qty
  end

  # @brief Adds goods to storage.
  # @param id [Symbol] A section of underground_goods.txt.
  # @param qty [Integer]
  def grant_good(id, qty = 1)
    return DevLog.warn("Underground: unknown good #{id}") unless GameData::UndergroundGood.exists?(id)
    data.goods[id] += qty
  end

  # @brief Adds a statue or good to storage.
  # @param id [Symbol]
  # @param qty [Integer]
  def grant_ware(id, qty = 1)
    statue?(id) ? grant_statue(id, qty) : grant_good(id, qty)
  end

  # @brief Adds sphere units.
  # @param color [Symbol] A section of underground_spheres.txt.
  # @param units [Integer]
  def add_spheres(color, units)
    data.spheres[color] += units
  end

  # @brief Total sphere units owned, across all colors.
  # @return [Integer]
  def sphere_total
    return data.spheres.values.sum
  end

  # @brief Whether the player owns enough spheres for a price.
  # @param price [Hash] { color => units }
  # @return [Boolean]
  def can_afford?(price)
    return price.all? { |color, units| data.spheres[color] >= units }
  end

  # @brief Takes a price's spheres from the player.
  # @param price [Hash] { color => units }
  # @return [Boolean] false (and nothing is taken) if the player can't afford it.
  def spend(price)
    return false unless can_afford?(price)
    price.each { |color, units| data.spheres[color] -= units }
    return true
  end

  # @brief A price as text, e.g. "15 Red, 5 Blue".
  # @param price [Hash] { color => units }
  # @return [String]
  def price_text(price)
    return price.map { |color, units| _INTL("{1} {2}", units, sphere_name(color)) }.join(", ")
  end
end

#==================================================================
# class Game_Event
#==================================================================
class Game_Event
  alias_method :underground_refresh, :refresh unless method_defined?(:underground_refresh)

  # @brief Refreshes the page, then puts back any Underground graphic override,
  # since a page change resets the graphic.
  def refresh
    underground_refresh
    apply_underground_graphic
  end

  # @brief Shows the graphic the Underground picks for this event, or the
  # page's own graphic if it picks none (e.g. an emptied slot).
  def apply_underground_graphic
    return unless @page && Underground.graphic_event?(self) && Underground.in_underground?(@map_id)
    name = Underground.graphic_for(self)
    if name
      @character_name = name
      @tile_id = 0
    else
      @character_name = @page.graphic.character_name
      @tile_id = @page.graphic.tile_id
    end
  end
end
