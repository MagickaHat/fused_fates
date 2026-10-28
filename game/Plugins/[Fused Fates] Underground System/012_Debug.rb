#================================================================================================
# Pokémon Fused Fates Underground System - 012_Debug.rb
#================================================================================================

#==================================================================
# module UndergroundDebug
#==================================================================
# @brief Shared helpers for the Underground debug menu commands.
module UndergroundDebug
  module_function

  # @brief Reapplies daily state to the current map's events, if it is part
  # of the Underground.
  def refresh_map
    return unless $game_map && Underground.in_underground?
    Underground::DigSpots.refresh
    Underground::Hideaways.refresh
    Underground::SecretBase.refresh_flags
    Underground::SecretBase.refresh_entrances
    Underground::Transit.refresh_barriers
    Underground.refresh_graphics
    $game_map.need_refresh = true
  end

  # @brief Describes a [map_id, x, y, direction] position.
  # @param pos [Array, nil]
  # @return [String]
  def position_text(pos)
    return "not set" unless Underground::Transit.set?(pos)
    return "#{pbGetMapNameFromId(pos[0])} (map #{pos[0]}) at #{pos[1]},#{pos[2]}"
  end

  # @brief Lines describing the whole Underground state, for the console.
  # @return [Array<String>]
  def status_lines
    d = Underground.data
    map_id = $game_map&.map_id
    ret = []
    ret.push("Day key: #{d.day_key} (today is #{DailyRefresh.today_key})")
    ret.push("Mission stage: #{d.mission_stage}/#{Underground::MISSIONS.length}")
    spheres = GameData::UndergroundSphere.keys.map { |c| "#{c} #{d.spheres[c]}" }
    ret.push("Spheres: #{spheres.join(', ')}")
    ret.push("Diglett meter: #{d.diglett_meter}/#{UndergroundSettings::DIGLETTS_PER_BONUS}, bonus digs: #{d.bonus_digs}")
    buried = d.buried.map { |e| "#{e[:color]} size #{e[:size]} (#{e[:steps]} steps)" }
    ret.push("Buried (#{d.buried.length}/#{Underground::Spheres.capacity}): #{buried.empty? ? 'none' : buried.join(', ')}")
    statues = d.statues.select { |_id, n| n > 0 }.map { |id, n| "#{id} x#{n}" }
    ret.push("Statues in storage: #{statues.empty? ? 'none' : statues.join(', ')}")
    goods = d.goods.select { |_id, n| n > 0 }.map { |id, n| "#{id} x#{n}" }
    ret.push("Goods in storage: #{goods.empty? ? 'none' : goods.join(', ')}")
    ret.push("Base size: #{d.base_size || 'none'}")
    loc = d.base_location
    ret.push("Base entrance: " + (loc ? "map #{loc[:map_id]}, event #{loc[:event_id]}" : "not dug"))
    layout = d.base_layout.map { |e| "#{e[:kind]} #{e[:slot]}: #{e[:id]}" }
    ret.push("Base layout: #{layout.empty? ? 'empty' : layout.join(', ')}")
    ret.push("Repaired lines: #{d.repaired_lines.empty? ? 'none' : d.repaired_lines.join(', ')}")
    ret.push("Discovered stations: #{d.discovered_stations.empty? ? 'none' : d.discovered_stations.join(', ')}")
    ret.push("Rivals beaten today: #{d.rivals_beaten.empty? ? 'none' : d.rivals_beaten.join(', ')}")
    ret.push("Flags taken today: #{d.flags_taken.empty? ? 'none' : d.flags_taken.join(', ')}")
    d.trader_stock.each do |id, wares|
      ret.push("#{id} stock: " + wares.map { |w, sold| sold ? "#{w} (traded)" : w.to_s }.join(", "))
    end
    if map_id
      ret.push("Current map #{map_id}: #{Underground.in_underground?(map_id) ? 'in' : 'not in'} the Underground")
      dug = d.dug_spots.select { |m, _e| m == map_id }.map { |_m, e| e }
      ret.push("  Dig spots dug today: #{dug.empty? ? 'none' : dug.join(', ')}")
      found = d.diglett_found.select { |m, _e| m == map_id }.map { |_m, e| e }
      ret.push("  Diglett found today: #{found.empty? ? 'none' : found.join(', ')}")
      d.hideaway_spawns.each do |(m, e), spawn|
        next if m != map_id || spawn.nil?
        mon = spawn[:partner] ? "#{spawn[:species]}/#{spawn[:partner]}" : spawn[:species].to_s
        cleared = Underground::Hideaways.cleared?(m, e) ? " (cleared)" : ""
        ret.push("  Hideaway event #{e}: #{mon} Lv. #{spawn[:level]}#{cleared}")
      end
    end
    stats = d.stats.map { |k, v| "#{k} #{v}" }
    ret.push("Stats: #{stats.empty? ? 'none' : stats.join(', ')}")
    return ret
  end

  # @brief Every place the debug warp can go, as [label, position] pairs.
  # Positions that aren't set up yet are left out.
  # @return [Array<Array>]
  def warp_targets
    ret = []
    loc = Underground.data.base_location
    ret.push([_INTL("Secret Base entrance"), loc[:exit]]) if loc
    size = Underground.data.base_size || :small
    x, y, dir = UndergroundSettings::BASE_ENTRY[size]
    ret.push([_INTL("Secret Base room ({1})", size), [UndergroundSettings::BASE_MAPS[size], x, y, dir]])
    GameData::UndergroundStation.each do |station|
      ret.push([_INTL("{1} (underground)", station.name), station.underground])
      ret.push([_INTL("{1} (platform)", station.name), station.platform])
    end
    return ret.select { |_label, pos| Underground::Transit.set?(pos) }
  end
end

#==================================================================
# Debug menu
#==================================================================
MenuHandlers.add(:debug_menu, :underground_menu, {
  "name"        => _INTL("Underground..."),
  "parent"      => :field_menu,
  "description" => _INTL("Give Underground items, skip ahead in missions, reset daily state and inspect the Underground."),
  "always_show" => false
})

MenuHandlers.add(:debug_menu, :underground_open_menu, {
  "name"        => _INTL("Open Underground menu"),
  "parent"      => :underground_menu,
  "description" => _INTL("Open the Underground menu from anywhere."),
  "effect"      => proc {
    pbUndergroundMenu
  }
})

MenuHandlers.add(:debug_menu, :underground_spheres, {
  "name"        => _INTL("Give spheres"),
  "parent"      => :underground_menu,
  "description" => _INTL("Add sphere units of one color."),
  "effect"      => proc {
    colors = GameData::UndergroundSphere.keys
    cmds = colors.map { |c| Underground.sphere_name(c) }
    choice = pbMessage(_INTL("Which color?"), cmds + [_INTL("Cancel")], -1)
    next if choice < 0 || choice >= colors.length
    params = ChooseNumberParams.new
    params.setRange(1, 999)
    params.setDefaultValue(50)
    params.setCancelValue(0)
    qty = pbMessageChooseNumber(_INTL("How many units?"), params)
    next if qty <= 0
    Underground.add_spheres(colors[choice], qty)
    pbMessage(_INTL("Gave {1} {2} units.", qty, cmds[choice]))
  }
})

MenuHandlers.add(:debug_menu, :underground_statues, {
  "name"        => _INTL("Give statue"),
  "parent"      => :underground_menu,
  "description" => _INTL("Add a statue to storage."),
  "effect"      => proc {
    ids = GameData::UndergroundStatue.keys
    cmds = ids.map { |id| _INTL("{1} ({2})", Underground.statue_name(id), GameData::UndergroundStatue.get(id).tier) }
    choice = pbMessage(_INTL("Which statue?"), cmds + [_INTL("Cancel")], -1)
    next if choice < 0 || choice >= ids.length
    Underground.grant_statue(ids[choice])
    pbMessage(_INTL("Gave a {1}.", Underground.statue_name(ids[choice])))
  }
})

MenuHandlers.add(:debug_menu, :underground_goods, {
  "name"        => _INTL("Give good"),
  "parent"      => :underground_menu,
  "description" => _INTL("Add a good to storage."),
  "effect"      => proc {
    ids = GameData::UndergroundGood.keys
    cmds = ids.map { |id| Underground.good_name(id) }
    choice = pbMessage(_INTL("Which good?"), cmds + [_INTL("Cancel")], -1)
    next if choice < 0 || choice >= ids.length
    Underground.grant_good(ids[choice])
    pbMessage(_INTL("Gave a {1}.", cmds[choice]))
  }
})

MenuHandlers.add(:debug_menu, :underground_mission, {
  "name"        => _INTL("Set mission stage"),
  "parent"      => :underground_menu,
  "description" => _INTL("Jump to a mission stage, applying the rewards of every mission before it."),
  "effect"      => proc {
    d = Underground.data
    params = ChooseNumberParams.new
    params.setRange(0, Underground::MISSIONS.length)
    params.setDefaultValue(d.mission_stage)
    params.setCancelValue(-1)
    stage = pbMessageChooseNumber(_INTL("Mission stage (0-{1})?", Underground::MISSIONS.length), params)
    next if stage < 0
    while d.mission_stage < stage
      Underground::MISSIONS[d.mission_stage][:reward].call(d)
      d.mission_stage += 1
    end
    d.mission_stage = stage
    pbMessage(_INTL("Mission stage is now {1}.", stage))
  }
})

MenuHandlers.add(:debug_menu, :underground_diglett, {
  "name"        => _INTL("Fill Diglett meter"),
  "parent"      => :underground_menu,
  "description" => _INTL("Grant a full Diglett meter's worth of bonus digs."),
  "effect"      => proc {
    d = Underground.data
    d.diglett_meter = 0
    d.bonus_digs += UndergroundSettings::BONUS_DIGS_PER_FILL
    pbMessage(_INTL("Bonus digs: {1}.", d.bonus_digs))
  }
})

MenuHandlers.add(:debug_menu, :underground_transit, {
  "name"        => _INTL("Open all transit"),
  "parent"      => :underground_menu,
  "description" => _INTL("Discover every station and repair every mine cart line."),
  "effect"      => proc {
    d = Underground.data
    GameData::UndergroundStation.keys.each { |id| d.discovered_stations.push(id) unless d.discovered_stations.include?(id) }
    GameData::UndergroundLine.keys.each { |id| d.repaired_lines.push(id) unless d.repaired_lines.include?(id) }
    pbMessage(_INTL("Every station is discovered and every line is running."))
  }
})

MenuHandlers.add(:debug_menu, :underground_new_day, {
  "name"        => _INTL("Start a new day"),
  "parent"      => :underground_menu,
  "description" => _INTL("Reset dig spots, Diglett, hideaway Pokémon, rivals, flags and trader stock."),
  "effect"      => proc {
    Underground.data.force_new_day!
    UndergroundDebug.refresh_map
    pbMessage(_INTL("A new day has begun in the Underground."))
  }
})

MenuHandlers.add(:debug_menu, :underground_grow, {
  "name"        => _INTL("Grow buried spheres"),
  "parent"      => :underground_menu,
  "description" => _INTL("Grow every buried sphere to full size."),
  "effect"      => proc {
    Underground.data.buried.each { |e| e[:size] = UndergroundSettings::SPHERE_MAX_SIZE }
    pbMessage(_INTL("Every buried sphere is fully grown."))
  }
})

MenuHandlers.add(:debug_menu, :underground_clear_base, {
  "name"        => _INTL("Clear base location"),
  "parent"      => :underground_menu,
  "description" => _INTL("Fill in the Secret Base entrance so a new wall can be picked. Decorations are kept."),
  "effect"      => proc {
    d = Underground.data
    loc = d.base_location
    next pbMessage(_INTL("No base has been dug yet.")) unless loc
    Underground::SecretBase.set_entrance(loc[:map_id], loc[:event_id], false)
    d.base_location = nil
    pbMessage(_INTL("The base entrance was filled in."))
  }
})

MenuHandlers.add(:debug_menu, :underground_status, {
  "name"        => _INTL("Show Underground status"),
  "parent"      => :underground_menu,
  "description" => _INTL("Print the whole Underground state, including today's picks on this map, to the console."),
  "effect"      => proc {
    Console.echo_h2("Underground status", text: :white)
    UndergroundDebug.status_lines.each { |line| Console.echoln(line) }
    d = Underground.data
    pbMessage(_INTL("Mission stage {1}, {2} sphere units, base: {3}. See the console for everything else.",
                    d.mission_stage, Underground.sphere_total, d.base_size ? d.base_size.to_s : _INTL("none")))
  }
})

MenuHandlers.add(:debug_menu, :underground_base_size, {
  "name"        => _INTL("Set base size"),
  "parent"      => :underground_menu,
  "description" => _INTL("Unlock, grow, shrink or take away the Secret Base. Placed items in locked slots stay placed."),
  "effect"      => proc {
    sizes = [nil] + UndergroundSettings::BASE_MAPS.keys
    cmds = sizes.map { |size| size ? _INTL(size.to_s.capitalize) : _INTL("None") }
    current = sizes.index(Underground.data.base_size) || 0
    choice = pbMessage(_INTL("Base size?"), cmds + [_INTL("Cancel")], -1, nil, current)
    next if choice < 0 || choice >= sizes.length
    Underground.data.base_size = sizes[choice]
    UndergroundDebug.refresh_map
    pbMessage(_INTL("Base size is now {1}.", cmds[choice]))
  }
})

MenuHandlers.add(:debug_menu, :underground_reset_daily, {
  "name"        => _INTL("Reset daily state..."),
  "parent"      => :underground_menu,
  "description" => _INTL("Bring back today's dig spots, Diglett, hideaway Pokémon, rivals, flags or trader stock."),
  "effect"      => proc {
    d = Underground.data
    cmds = [_INTL("Dig spots and Diglett"), _INTL("Hideaway Pokémon"), _INTL("Rivals and flags"),
            _INTL("Trader stock"), _INTL("Everything")]
    choice = pbMessage(_INTL("Reset which daily state?"), cmds + [_INTL("Cancel")], -1)
    next if choice < 0 || choice >= cmds.length
    if [0, 4].include?(choice)
      d.dug_spots.clear
      d.diglett_found.clear
    end
    if [1, 4].include?(choice)
      d.hideaway_spawns.clear
      d.cleared_mons.clear
    end
    if [2, 4].include?(choice)
      d.rivals_beaten.clear
      d.flags_taken.clear
    end
    d.trader_stock.clear if [3, 4].include?(choice)
    UndergroundDebug.refresh_map
    pbMessage(_INTL("Reset: {1}.", cmds[choice]))
  }
})

MenuHandlers.add(:debug_menu, :underground_warp, {
  "name"        => _INTL("Warp to Underground location"),
  "parent"      => :underground_menu,
  "description" => _INTL("Warp to the Secret Base, or a station's ladder or platform. Unset positions aren't listed."),
  "effect"      => proc {
    targets = UndergroundDebug.warp_targets
    next pbMessage(_INTL("No Underground positions are set up yet.")) if targets.empty?
    cmds = targets.map { |label, _pos| label }
    choice = pbMessage(_INTL("Warp where?"), cmds + [_INTL("Cancel")], -1)
    next if choice < 0 || choice >= targets.length
    Underground::Transit.transfer(targets[choice][1])
  }
})

MenuHandlers.add(:debug_menu, :underground_barriers, {
  "name"        => _INTL("Show cave-in status"),
  "parent"      => :underground_menu,
  "description" => _INTL("List every cave-in and what still keeps it blocked."),
  "effect"      => proc {
    next pbMessage(_INTL("There are no cave-ins in underground_barriers.txt.")) if GameData::UndergroundBarrier.count == 0
    cmds = []
    GameData::UndergroundBarrier.each do |barrier|
      unmet = barrier.unmet_conditions
      cmds.push(unmet.empty? ? _INTL("{1}: open", barrier.id) : _INTL("{1}: needs {2}", barrier.id, unmet.join(", ")))
    end
    pbMessage(_INTL("Cave-ins:"), cmds + [_INTL("Close")], -1)
  }
})

MenuHandlers.add(:debug_menu, :underground_reload_pbs, {
  "name"        => _INTL("Reload Underground PBS files"),
  "parent"      => :underground_menu,
  "description" => _INTL("Recompile the underground_*.txt PBS files so edits apply without restarting."),
  "effect"      => proc {
    ok = DevLog.guard("Underground: compiling PBS files failed", false) do
      Compiler.compile_underground_data
      next true
    end
    if ok
      UndergroundDebug.refresh_map
      pbMessage(_INTL("The Underground PBS files were recompiled."))
    else
      pbMessage(_INTL("Compiling failed. See the console for the error."))
    end
  }
})
