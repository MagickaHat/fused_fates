#================================================================================================
# Pokémon Fused Fates Underground System - 006_SecretBase.rb
#================================================================================================

#==================================================================
# module Underground
#==================================================================
module Underground
  #==================================================================
  # module SecretBase
  #==================================================================
  # @brief The player's Secret Base and the rival diggers' bases.
  #
  # Like DPPT, the player picks where to dig their base: any "BaseWall"
  # event in the tunnels can become the entrance, and digging at another
  # wall moves the base there (decorations come along). Whichever wall it
  # is, the room inside is one of the BASE_MAPS rooms, picked by base size.
  # Statues go on "BaseSlot:N" pedestal events and goods in "GoodSlot:N" events; slots
  # numbered above the size's limit stay locked until the base grows. Placed
  # statues show their Pokémon's overworld sprite, and goods show their
  # :charset (or the slot event's own graphic if it has none).
  module SecretBase
    module_function

    # @brief Whether a map is one of the player's base rooms.
    # @param map_id [Integer]
    # @return [Boolean]
    def base_map?(map_id)
      return UndergroundSettings::BASE_MAPS.value?(map_id)
    end

    # @brief How many slots of a kind the current base has.
    # @param kind [Symbol] :statue or :good
    # @return [Integer]
    def slot_count(kind)
      size = Underground.data.base_size
      return 0 unless size
      limits = (kind == :statue) ? UndergroundSettings::PEDESTALS_BY_SIZE : UndergroundSettings::GOOD_SLOTS_BY_SIZE
      return limits[size] || 0
    end

    # @brief The storage hash for a kind.
    # @param kind [Symbol] :statue or :good
    # @return [Hash]
    def storage(kind)
      d = Underground.data
      return (kind == :statue) ? d.statues : d.goods
    end

    # @brief Display name of a statue or good.
    # @param kind [Symbol] :statue or :good
    # @param id [Symbol]
    # @return [String]
    def name_of(kind, id)
      return (kind == :statue) ? Underground.statue_name(id) : Underground.good_name(id)
    end

    # @brief The graphic shown on a slot.
    # @param kind [Symbol] :statue or :good
    # @param slot [Integer]
    # @return [String, nil]
    def graphic(kind, slot)
      entry = Underground.data.layout_at(kind, slot)
      return nil unless entry
      if kind == :statue
        s = GameData::UndergroundStatue.try_get(entry[:id])
        return s ? Underground.pokemon_charset(s.species, s.body) : nil
      end
      return GameData::UndergroundGood.try_get(entry[:id])&.charset
    end

    # @brief Takes whatever is in a slot back into storage.
    # @param kind [Symbol] :statue or :good
    # @param slot [Integer]
    # @return [Symbol, nil] The ID taken back.
    def remove(kind, slot)
      d = Underground.data
      entry = d.layout_at(kind, slot)
      return nil unless entry
      d.base_layout.delete(entry)
      storage(kind)[entry[:id]] += 1
      return entry[:id]
    end

    # @brief Puts something from storage into a slot, returning whatever was
    # there to storage.
    # @param kind [Symbol] :statue or :good
    # @param slot [Integer]
    # @param id [Symbol]
    # @return [Boolean] false if none are in storage.
    def place(kind, slot, id)
      store = storage(kind)
      return false if store[id] <= 0
      remove(kind, slot)
      store[id] -= 1
      store.delete(id) if store[id] <= 0
      Underground.data.base_layout.push({ kind: kind, slot: slot, id: id })
      return true
    end

    # @brief Lets the player pick something from storage.
    # @param kind [Symbol] :statue or :good
    # @return [Symbol, nil] The chosen ID, or nil if cancelled or empty.
    def choose_from_storage(kind)
      ids = storage(kind).select { |_id, qty| qty > 0 }.keys
      if ids.empty?
        pbMessage((kind == :statue) ? _INTL("You don't have any statues in storage.") :
                                      _INTL("You don't have any goods in storage."))
        return nil
      end
      cmds = ids.map { |id| _INTL("{1} x{2}", name_of(kind, id), storage(kind)[id]) }
      cmds.push(_INTL("Cancel"))
      choice = pbMessage((kind == :statue) ? _INTL("Which statue?") : _INTL("Which good?"), cmds, -1)
      return nil if choice < 0 || choice >= ids.length
      return ids[choice]
    end

    # @brief Runs the place/swap/take-back menu for a slot.
    # @param kind [Symbol] :statue or :good
    # @param slot [Integer]
    # @param event [Game_Event, nil] The slot event, refreshed afterwards.
    def edit_slot(kind, slot, event = nil)
      if slot > slot_count(kind)
        pbMessage((kind == :statue) ? _INTL("This pedestal is buried in rubble. A bigger base would free it up.") :
                                      _INTL("There isn't room here yet. A bigger base would free it up."))
        return
      end
      entry = Underground.data.layout_at(kind, slot)
      if entry
        good_use = (kind == :good) ? GameData::UndergroundGood.try_get(entry[:id])&.use : nil
        cmds = []
        cmds.push(_INTL("Use")) if good_use
        cmds += [_INTL("Swap"), _INTL("Take back"), _INTL("Cancel")]
        choice = pbMessage(_INTL("{1} is here.", name_of(kind, entry[:id])), cmds, -1)
        choice += 1 if !good_use && choice >= 0
        case choice
        when 0
          use_good(good_use)
          return
        when 1
          id = choose_from_storage(kind)
          place(kind, slot, id) if id
        when 2
          id = remove(kind, slot)
          pbMessage(_INTL("{1} went back into storage.", name_of(kind, id)))
        else
          return
        end
      else
        prompt = (kind == :statue) ? _INTL("An empty pedestal. Place a statue?") : _INTL("An empty spot. Place a good?")
        return unless pbConfirmMessage(prompt)
        id = choose_from_storage(kind)
        return unless id
        place(kind, slot, id)
        pbMessage(_INTL("You placed the {1}.", name_of(kind, id)))
      end
      event&.apply_underground_graphic
      $game_map.need_refresh = true
    end

    # @brief Runs a placed good's effect.
    # @param use [Symbol] :planter or :pc
    def use_good(use)
      case use
      when :planter then Underground::Spheres.planter_menu
      when :pc      then pbPokeCenterPC
      end
    end

    #----------------------------------------------------------------
    # Location
    #----------------------------------------------------------------
    # @brief Whether a BaseWall event is the current base entrance.
    # @param event [Game_Event]
    # @return [Boolean]
    def entrance?(event)
      loc = Underground.data.base_location
      return !loc.nil? && loc[:map_id] == event.map_id && loc[:event_id] == event.id
    end

    # @brief Opens or closes a BaseWall's entrance page.
    # @param map_id [Integer]
    # @param event_id [Integer]
    # @param open [Boolean]
    def set_entrance(map_id, event_id, open)
      $game_self_switches[[map_id, event_id, UndergroundSettings::BASE_ENTRANCE_SWITCH]] = open
      $game_map.need_refresh = true if $game_map
    end

    # @brief Digs the base at a wall, filling in the old entrance if there was one.
    # The layout isn't touched, so the decorations move with the base.
    # @param event [Game_Event] The BaseWall event.
    # @param exit_pos [Array] [map_id, x, y, direction] to put the player on when leaving.
    def dig_base_at(event, exit_pos)
      d = Underground.data
      old = d.base_location
      set_entrance(old[:map_id], old[:event_id], false) if old
      d.base_location = { map_id: event.map_id, event_id: event.id, exit: exit_pos }
      set_entrance(event.map_id, event.id, true)
      d.stats[:bases_dug] += 1
    end

    # @brief Matches every BaseWall on the current map to the base location.
    def refresh_entrances
      Underground.events_named(UndergroundSettings::EVENT_BASE_WALL).each do |ev|
        key = [ev.map_id, ev.id, UndergroundSettings::BASE_ENTRANCE_SWITCH]
        open = entrance?(ev)
        next if !!$game_self_switches[key] == open
        set_entrance(ev.map_id, ev.id, open)
      end
    end

    # @brief Enters the base room for the current size.
    def enter
      size = Underground.data.base_size
      x, y, dir = UndergroundSettings::BASE_ENTRY[size]
      Underground::Transit.transfer([UndergroundSettings::BASE_MAPS[size], x, y, dir])
    end

    #----------------------------------------------------------------
    # Rivals
    #----------------------------------------------------------------
    # @brief Battles a rival digger, once per day.
    # @param rival_id [Symbol] A section of underground_rivals.txt.
    # @return [Boolean] Whether the player has beaten them today.
    def battle_rival(rival_id)
      rival = GameData::UndergroundRival.try_get(rival_id)
      return false unless rival
      d = Underground.data
      if d.rivals_beaten.include?(rival_id)
        pbMessage(_INTL("{1}: You got me already today. Come back tomorrow!", rival.name))
        return true
      end
      if rival.leader? && d.mission_stage < UndergroundSettings::LEADER_STAGE
        pbMessage(_INTL("{1}: Come back when you've made a name for yourself down here.", rival.name))
        return false
      end
      type, name, version = rival.trainer
      unless GameData::Trainer.exists?(type, name, version)
        DevLog.warn("Underground: rival #{rival_id} has no trainer #{type}, #{name}, #{version} in trainers.txt")
        pbMessage(_INTL("{1} isn't ready to battle yet.", rival.name))
        return false
      end
      return false unless TrainerBattle.start_core(type, name, version) == 1
      d.rivals_beaten.push(rival_id)
      d.stats[:rival_wins] += 1
      d.stats[:rival_leader] += 1 if rival.leader?
      return true
    end

    # @brief Takes a rival's flag, once per day, after beating them today.
    # @param rival_id [Symbol] A section of underground_rivals.txt.
    # @return [Boolean] Whether a flag was taken.
    def take_flag(rival_id)
      rival = GameData::UndergroundRival.try_get(rival_id)
      return false unless rival && !rival.leader?
      d = Underground.data
      return false if d.flags_taken.include?(rival_id)
      unless d.rivals_beaten.include?(rival_id)
        pbMessage(_INTL("{1} is guarding this flag. Beat them in a battle first!", rival.name))
        return false
      end
      d.flags_taken.push(rival_id)
      d.stats[:flags] += 1
      pbMessage(_INTL("You took {1}'s flag!", rival.name) + "\\me[Item get]")
      return true
    end

    # @brief Hides the flags already taken today on the current map.
    def refresh_flags
      d = Underground.data
      Underground.events_named(UndergroundSettings::EVENT_RIVAL_FLAG).each do |ev|
        id = Underground.event_tag(ev)[1].to_s.to_sym
        Underground.set_hidden(ev, d.flags_taken.include?(id))
      end
    end
  end
end

# @brief BaseWall event: digs the Secret Base here, moves it here, or enters it
# if this wall is already the entrance.
def pbUndergroundSecretBase
  ev = Underground.calling_event
  return unless ev
  d = Underground.data
  sb = Underground::SecretBase
  unless d.base_size
    pbMessage(_INTL("A plain rock wall. Maybe someone could help you dig a base here."))
    return
  end
  if sb.entrance?(ev)
    sb.enter
    return
  end
  moving = !d.base_location.nil?
  if moving
    return unless pbConfirmMessage(_INTL("Move your Secret Base here? The old entrance will be filled in. Your decorations come with you."))
  else
    return unless pbConfirmMessage(_INTL("This wall looks soft enough. Dig your Secret Base here?"))
  end
  exit_pos = [$game_map.map_id, $game_player.x, $game_player.y, 10 - $game_player.direction]
  sb.dig_base_at(ev, exit_pos)
  pbSEPlay("Mining collapse")
  pbMessage(moving ? _INTL("You moved your Secret Base here!") : _INTL("You dug out a Secret Base!"))
  return unless pbConfirmMessage(_INTL("Go inside?"))
  sb.enter
end

# @brief Secret Base exit: returns to the tile in front of the entrance.
def pbUndergroundLeaveBase
  dest = Underground.data.base_location&.dig(:exit)
  if dest.nil?
    pbMessage(_INTL("The way out is blocked."))
    return
  end
  Underground::Transit.transfer(dest)
end

# @brief Statue pedestal event ("BaseSlot:N").
def pbUndergroundBaseSlot
  ev = Underground.calling_event
  return unless ev
  Underground::SecretBase.edit_slot(:statue, Underground.event_tag(ev)[1].to_i, ev)
end

# @brief Goods slot event ("GoodSlot:N").
def pbUndergroundGoodSlot
  ev = Underground.calling_event
  return unless ev
  Underground::SecretBase.edit_slot(:good, Underground.event_tag(ev)[1].to_i, ev)
end

# @brief Rival digger event: battles them once per day.
# @param rival_id [Symbol] A section of underground_rivals.txt.
# @return [Boolean] Whether the player has beaten them today.
def pbUndergroundRival(rival_id)
  return Underground::SecretBase.battle_rival(rival_id)
end

# @brief Rival flag event ("RivalFlag:rival_id"): takes the flag.
# @param rival_id [Symbol, nil] Defaults to the ID in the event's name.
def pbUndergroundRivalFlag(rival_id = nil)
  ev = Underground.calling_event
  rival_id ||= Underground.event_tag(ev)[1].to_s.to_sym if ev
  return unless rival_id
  return unless Underground::SecretBase.take_flag(rival_id)
  Underground.set_hidden(ev, true) if ev
end

EventHandlers.add(:on_enter_map, :underground_secret_base,
  proc { |_old_map_id|
    next unless Underground.in_underground?
    Underground::SecretBase.refresh_flags
    Underground::SecretBase.refresh_entrances
    Underground.refresh_graphics if Underground::SecretBase.base_map?($game_map.map_id)
  }
)
