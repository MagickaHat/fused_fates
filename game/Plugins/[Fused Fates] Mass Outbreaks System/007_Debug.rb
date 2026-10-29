#================================================================================================
# Pokémon Fused Fates Mass Outbreaks System - 007_Debug.rb
#================================================================================================

#==================================================================
# module MassOutbreaksDebug
#==================================================================
# @brief Shared helpers for the Mass Outbreaks debug menu commands.
module MassOutbreaksDebug
  module_function

  # @brief One line describing an active outbreak.
  # @param e [Hash] Pool entry.
  # @param rec [Hash] Saved record.
  # @return [String]
  def outbreak_line(e, rec)
    line = "#{e[:id]}: #{e[:species]} Lv. #{e[:levels]} (#{e[:category]}) on map #{e[:map]}, " \
           "count #{rec[:count]}"
    nxt = MassOutbreaks.next_threshold(e[:id])
    line += "/#{nxt}" if nxt
    hours = MassOutbreaks.hours_left(e[:id])
    line += ", #{hours}h left" if hours
    return line
  end

  # @brief Lines describing the whole outbreak state, for the console.
  # @return [Array<String>]
  def status_lines
    ret = []
    ret.push("Mode: #{MassOutbreaksSettings::MODE}, enabled: #{MassOutbreaks.enabled?}")
    if MassOutbreaksSettings::MODE == :rotating
      ret.push("Hour tick: #{MassOutbreaks.current_tick}")
    else
      ret.push("Day key: #{MassOutbreaks.current_day_key}")
    end
    eligible = MassOutbreaks.pool.values.count { |e| MassOutbreaks.eligible?(e) }
    ret.push("Pool: #{MassOutbreaks.pool.length} entries, #{eligible} eligible")
    list = MassOutbreaks.active
    ret.push("Active: #{list.empty? ? 'none' : list.length}")
    list.each { |e, rec| ret.push("  " + outbreak_line(e, rec)) }
    return ret
  end

  # @brief Ask the player to pick an active outbreak.
  # @return [Symbol, nil] Entry ID, or nil if cancelled or none are active.
  def choose_active
    list = MassOutbreaks.active
    if list.empty?
      pbMessage(_INTL("No outbreaks are active."))
      return nil
    end
    cmds = list.map { |e, _rec| "#{MassOutbreaks.species_name(e)} - #{MassOutbreaks.map_name(e)}" }
    choice = pbMessage(_INTL("Which outbreak?"), cmds + [_INTL("Cancel")], -1)
    return nil if choice < 0 || choice >= list.length
    return list[choice][0][:id]
  end
end

#==================================================================
# Debug menu
#==================================================================
MenuHandlers.add(:debug_menu, :mass_outbreaks_menu, {
  "name"        => _INTL("Mass Outbreaks..."),
  "parent"      => :field_menu,
  "description" => _INTL("Inspect, reroll, start and clear mass outbreaks."),
  "always_show" => false
})

MenuHandlers.add(:debug_menu, :mass_outbreaks_status, {
  "name"        => _INTL("Show outbreak status"),
  "parent"      => :mass_outbreaks_menu,
  "description" => _INTL("List the active outbreaks and their counters in the console."),
  "effect"      => proc {
    lines = MassOutbreaksDebug.status_lines
    Console.echo_h2("Mass Outbreaks", text: :white)
    lines.each { |line| Console.echoln(line) }
    pbMessage(_INTL("{1} outbreaks active. See the console for details.", MassOutbreaks.active.length))
  }
})

MenuHandlers.add(:debug_menu, :mass_outbreaks_news, {
  "name"        => _INTL("Play outbreak news"),
  "parent"      => :mass_outbreaks_menu,
  "description" => _INTL("Run pbMassOutbreakNews, as a TV or NPC event would."),
  "effect"      => proc {
    pbMassOutbreakNews
  }
})

MenuHandlers.add(:debug_menu, :mass_outbreaks_reroll, {
  "name"        => _INTL("Reroll outbreaks"),
  "parent"      => :mass_outbreaks_menu,
  "description" => _INTL("Throw away the active outbreaks and roll a new random set."),
  "effect"      => proc {
    if !MassOutbreaks.enabled?
      pbMessage(_INTL("Outbreaks aren't enabled yet (check UNLOCK_SWITCH)."))
      next
    end
    MassOutbreaks.reroll
    pbMessage(_INTL("Rolled {1} outbreaks.", MassOutbreaks.active.length))
  }
})

MenuHandlers.add(:debug_menu, :mass_outbreaks_start, {
  "name"        => _INTL("Start an outbreak"),
  "parent"      => :mass_outbreaks_menu,
  "description" => _INTL("Start any pool entry now, ignoring badges and switches."),
  "effect"      => proc {
    entries = MassOutbreaks.pool.values
    if entries.empty?
      pbMessage(_INTL("No outbreaks are registered."))
      next
    end
    cmds = entries.map { |e| "#{e[:id]} (#{MassOutbreaks.species_name(e)}, map #{e[:map]})" }
    choice = pbMessage(_INTL("Start which outbreak?"), cmds + [_INTL("Cancel")], -1)
    next if choice < 0 || choice >= entries.length
    e = entries[choice]
    if MassOutbreaks.force_start(e[:id])
      pbMessage(_INTL("Started the {1} outbreak on {2}.", MassOutbreaks.species_name(e), MassOutbreaks.map_name(e)))
    else
      pbMessage(_INTL("Outbreaks aren't enabled yet (check UNLOCK_SWITCH)."))
    end
  }
})

MenuHandlers.add(:debug_menu, :mass_outbreaks_counter, {
  "name"        => _INTL("Set outbreak counter"),
  "parent"      => :mass_outbreaks_menu,
  "description" => _INTL("Change how many of an outbreak's Pokémon have been battled."),
  "effect"      => proc {
    id = MassOutbreaksDebug.choose_active
    next if !id
    rec = MassOutbreaks.record(id)
    params = ChooseNumberParams.new
    params.setRange(0, 999)
    params.setDefaultValue(rec[:count])
    params.setCancelValue(-1)
    count = pbMessageChooseNumber(_INTL("Set the counter to?"), params)
    next if count < 0
    rec[:count] = count
    pbMessage(_INTL("Counter set to {1}.", count))
  }
})

MenuHandlers.add(:debug_menu, :mass_outbreaks_clear, {
  "name"        => _INTL("Clear outbreaks"),
  "parent"      => :mass_outbreaks_menu,
  "description" => _INTL("End every active outbreak. New ones roll next day (daily) or hour (rotating)."),
  "effect"      => proc {
    MassOutbreaks.clear
    pbMessage(_INTL("All outbreaks cleared."))
  }
})
