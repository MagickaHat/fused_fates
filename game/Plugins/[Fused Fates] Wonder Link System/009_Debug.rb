#================================================================================================
# Pokémon Fused Fates Wonder Link System - 009_Debug.rb
#================================================================================================

#==================================================================
# module WonderLinkDebug
#==================================================================
# @brief Shared helpers for the Wonder Link debug menu commands.
module WonderLinkDebug
  module_function

  # @brief Lines describing a decoded code, for the console.
  # @param decoded [Hash]
  # @return [Array<String>]
  def describe(decoded)
    owner = decoded[:owner]
    ret = ["Type: #{decoded[:type]}, digest #{decoded[:digest]}",
           "Owner: #{owner[:name]} (ID #{owner[:id]}, gender #{owner[:gender]}, #{owner[:trainer_type]})"]
    list = (decoded[:type] == :party) ? decoded[:party] : [decoded[:pokemon]]
    list.each do |rec|
      line = "  #{rec[:species]}"
      line += "_#{rec[:form]}" if rec[:form] > 0
      line += " (#{rec[:fusion][:head]}/#{rec[:fusion][:body]})" if rec[:fusion]
      line += " Lv. #{rec[:level]}, #{rec[:ability]}, #{rec[:nature]}, moves #{rec[:moves].map(&:first).join('/')}"
      ret.push(line)
    end
    ret.push("Safari species: #{decoded[:signature].join(', ')}") if decoded[:signature]
    return ret
  end

  # @brief Lines describing this save's Wonder Link state, for the console.
  # @return [Array<String>]
  def status_lines
    d = WonderLink.data
    boosts = WonderLink::Safari.boosts_today.map { |s, n| "#{s} x#{n}" }
    return ["Safari species: #{WonderLink::Safari.signature.join(', ')}",
            "Safari boosts today: #{boosts.empty? ? 'none' : boosts.join(', ')}",
            "Codes used today: battle #{d.uses_today(:battle)}, safari #{d.uses_today(:safari)}",
            "Underground rival code: #{d.last_profile_code ? 'set' : 'none'}"]
  end
end

#==================================================================
# Debug menu
#==================================================================
MenuHandlers.add(:debug_menu, :wonder_link_menu, {
  "name"        => _INTL("Wonder Link..."),
  "parent"      => :main,
  "description" => _INTL("Make and inspect Wonder Link codes, and reset Wonder Link cooldowns."),
  "always_show" => false
})

MenuHandlers.add(:debug_menu, :wonder_link_status, {
  "name"        => _INTL("Show Wonder Link status"),
  "parent"      => :wonder_link_menu,
  "description" => _INTL("Print the Safari species, today's boosts and cooldowns to the console."),
  "effect"      => proc {
    WonderLinkDebug.status_lines.each { |line| echoln(line) }
    pbMessage(_INTL("Safari species: {1}", WonderLink::Safari.signature.join(", ")))
  }
})

MenuHandlers.add(:debug_menu, :wonder_link_inspect, {
  "name"        => _INTL("Inspect a code"),
  "parent"      => :wonder_link_menu,
  "description" => _INTL("Decode a Wonder Link code and print what it contains to the console."),
  "effect"      => proc {
    text = WonderLink.read_code_input
    next if !text
    begin
      decoded = WonderLink.decode!(text)
      WonderLinkDebug.describe(decoded).each { |line| echoln(line) }
      pbMessage(_INTL("The code is valid. Its contents were printed to the console."))
    rescue WonderLink::InvalidCode => e
      echoln("Invalid code: #{e.message}")
      pbMessage(_INTL("Invalid code: {1}", e.message))
    end
  }
})

MenuHandlers.add(:debug_menu, :wonder_link_export, {
  "name"        => _INTL("Make codes"),
  "parent"      => :wonder_link_menu,
  "description" => _INTL("Make a profile, trade or gift code from your party."),
  "effect"      => proc {
    case pbMessage(_INTL("Which code?"), [_INTL("Profile"), _INTL("Trade"), _INTL("Gift"), _INTL("Cancel")], 4)
    when 0 then WonderLink.export_party
    when 1 then WonderLink.export_trade
    when 2 then WonderLink.export_gift
    end
  }
})

MenuHandlers.add(:debug_menu, :wonder_link_reset_daily, {
  "name"        => _INTL("Reset daily cooldowns"),
  "parent"      => :wonder_link_menu,
  "description" => _INTL("Start a new Wonder Link day, clearing cooldowns and Safari boosts."),
  "effect"      => proc {
    WonderLink.data.force_new_day!
    pbMessage(_INTL("Wonder Link cooldowns and Safari boosts were cleared."))
  }
})

MenuHandlers.add(:debug_menu, :wonder_link_clear_redeemed, {
  "name"        => _INTL("Forget redeemed codes"),
  "parent"      => :wonder_link_menu,
  "description" => _INTL("Allow trade and gift codes to be redeemed again in this save."),
  "effect"      => proc {
    WonderLink.data.clear_redeemed
    pbMessage(_INTL("Redeemed trade and gift codes were forgotten."))
  }
})

MenuHandlers.add(:debug_menu, :wonder_link_reroll_safari, {
  "name"        => _INTL("Re-roll Safari species"),
  "parent"      => :wonder_link_menu,
  "description" => _INTL("Give this save new random Safari species."),
  "effect"      => proc {
    pbMessage(_INTL("New Safari species: {1}", WonderLink::Safari.reroll_signature.join(", ")))
  }
})
