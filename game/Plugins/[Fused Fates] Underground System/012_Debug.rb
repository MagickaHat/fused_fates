#================================================================================================
# Pokémon Fused Fates Underground System - 012_Debug.rb
#================================================================================================

#==================================================================
# Debug menu
#==================================================================
MenuHandlers.add(:debug_menu, :underground_menu, {
  "name"        => _INTL("Underground..."),
  "parent"      => :field_menu,
  "description" => _INTL("Give Underground spheres, statues and goods, and skip ahead in missions."),
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
    colors = Underground::SPHERES.keys
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
    ids = Underground::STATUES.keys
    cmds = ids.map { |id| _INTL("{1} ({2})", Underground.statue_name(id), Underground::STATUES[id][:tier]) }
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
    ids = Underground::GOODS.keys
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
    Underground::STATIONS.each_key { |id| d.discovered_stations.push(id) unless d.discovered_stations.include?(id) }
    Underground::LINES.each_key { |id| d.repaired_lines.push(id) unless d.repaired_lines.include?(id) }
    pbMessage(_INTL("Every station is discovered and every line is running."))
  }
})

MenuHandlers.add(:debug_menu, :underground_new_day, {
  "name"        => _INTL("Start a new day"),
  "parent"      => :underground_menu,
  "description" => _INTL("Reset dig spots, Diglett, hideaway Pokémon, rivals, flags and trader stock."),
  "effect"      => proc {
    Underground.data.day_key = 0
    Underground.data
    Underground::Transit.refresh_barriers if Underground.in_underground?
    pbMessage(_INTL("A new day has begun in the Underground. Re-enter the map to see it."))
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
