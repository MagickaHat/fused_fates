#================================================================================================
# Pokémon Fused Fates Wonder Link System - 006_SaveData.rb
#================================================================================================

#==================================================================
# class WonderLinkSaveData
#==================================================================
# @brief Everything Wonder Link keeps in the save file.
#
# Codes work offline, so "redeemed once" and "once per day" are tracked per save file. The same
# code can still be used in a different save; there is no server that could prevent that.
class WonderLinkSaveData
  include DailyRefreshable

  # @brief Profile code most recently redeemed for anything, used by the Underground rival.
  # @return [String, nil]
  attr_accessor :last_profile_code

  # @brief Creates empty Wonder Link state for a new game.
  def initialize
    @day_key           = 0
    @redeemed          = {}
    @daily_uses        = {}
    @safari_signature  = nil
    @safari_boosts     = {}
    @last_profile_code = nil
    @outbreak_entries  = {}
  end

  #----------------------------------------------------------------
  # One-time codes (trades and gifts)
  #----------------------------------------------------------------
  # @brief Whether a trade or gift code was already redeemed in this save.
  # @param digest [String] The decoded code's :digest.
  # @return [Boolean]
  def redeemed?(digest)
    return @redeemed.key?(digest)
  end

  # @brief Remembers that a trade or gift code was redeemed.
  # @param digest [String]
  def mark_redeemed(digest)
    @redeemed[digest] = DailyRefresh.today_key
  end

  # @brief Forgets every redeemed code. Used by the debug menu.
  def clear_redeemed
    @redeemed.clear
  end

  #----------------------------------------------------------------
  # Daily uses (profile codes)
  #----------------------------------------------------------------
  # @brief Whether a player's code was already used for something today.
  # @param use [Symbol] :battle, :safari, ...
  # @param key [Object] Identifies the sharer (their trainer ID).
  # @return [Boolean]
  def used_today?(use, key)
    refresh_day!
    return (@daily_uses[use] || []).include?(key)
  end

  # @brief Records that a player's code was used for something today.
  # @param use [Symbol]
  # @param key [Object]
  def mark_used_today(use, key)
    refresh_day!
    (@daily_uses[use] ||= []).push(key)
  end

  # @brief How many different codes were used for something today.
  # @param use [Symbol]
  # @return [Integer]
  def uses_today(use)
    refresh_day!
    return (@daily_uses[use] || []).length
  end

  #----------------------------------------------------------------
  # Safari Zone
  #----------------------------------------------------------------
  # @brief This save's Safari species, or nil if they haven't been rolled yet.
  # @return [Array<Symbol>, nil]
  attr_accessor :safari_signature

  # @brief Species boosted by codes redeemed today, with how many codes boosted each.
  # @return [Hash{Symbol => Integer}]
  def safari_boosts
    refresh_day!
    return @safari_boosts
  end

  #----------------------------------------------------------------
  # Mass Outbreaks
  #----------------------------------------------------------------
  # @brief Outbreak pool entries Wonder Link created, so they can be registered again on load.
  # @return [Hash{Symbol => Hash}] Options for MassOutbreaks.register, keyed by entry ID.
  def outbreak_entries
    @outbreak_entries ||= {}
    return @outbreak_entries
  end

  #----------------------------------------------------------------
  # Daily state
  #----------------------------------------------------------------
  # @brief Clears the daily cooldowns and today's Safari boosts.
  def on_new_day
    @daily_uses.clear
    @safari_boosts.clear
  end

  SaveData.register(:wonder_link) do
    ensure_class :WonderLinkSaveData
    save_value { $wonder_link }
    load_value do |value|
      $wonder_link = value
      WonderLink::Outbreaks.restore_entries if defined?(WonderLink::Outbreaks)
    end
    new_game_value { WonderLinkSaveData.new }
  end
end

#==================================================================
# module WonderLink
#==================================================================
module WonderLink
  module_function

  # @brief The save's Wonder Link state, brought up to date for today.
  # @return [WonderLinkSaveData]
  def data
    $wonder_link ||= WonderLinkSaveData.new
    $wonder_link.refresh_day!
    return $wonder_link
  end

  # @brief Checks the daily cooldown for a profile code and records the use.
  # @param decoded [Hash] A decoded :party code.
  # @param use [Symbol] :battle, :safari, ...
  # @return [Boolean] False (with a message) if the code was already used for this today.
  def use_daily(decoded, use)
    key = decoded[:owner][:id]
    if data.used_today?(use, key)
      pbMessage(_INTL("You've already used {1}'s Wonder Link code for this today. Try again tomorrow!",
                      owner_name(decoded)))
      return false
    end
    data.mark_used_today(use, key)
    return true
  end

  # @brief Things every redeemed profile code does, whatever it was redeemed for.
  # @param decoded [Hash] A decoded :party code, as returned by ask_for_code.
  def on_profile_redeemed(decoded)
    data.last_profile_code = decoded[:code] if decoded[:code]
    WonderLink::Outbreaks.try_start(decoded) if defined?(WonderLink::Outbreaks)
  end

  # @brief The sharer's name, or the fallback name for codes without one.
  # @param decoded [Hash]
  # @return [String]
  def owner_name(decoded)
    name = decoded[:owner][:name].to_s.strip
    return name.empty? ? WonderLinkSettings::FALLBACK_TRAINER_NAME : name
  end
end
