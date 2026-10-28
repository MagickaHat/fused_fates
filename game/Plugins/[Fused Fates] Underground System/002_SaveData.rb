#================================================================================================
# Pokémon Fused Fates Underground System - 002_SaveData.rb
#================================================================================================

#==================================================================
# class UndergroundSaveData
#==================================================================
# @class UndergroundSaveData
# @brief Everything about the Underground that must survive saving.
# Daily state (dug spots, hideaway spawns) is tagged with a date key
# and cleared by #refresh_day! when the date changes.
class UndergroundSaveData
  # @brief Date key the daily lists below belong to.
  attr_accessor :day_key
  # @brief [map_id, event_id] pairs of dig spots dug today.
  attr_accessor :dug_spots
  # @brief [map_id, event_id] pairs of Digletts found today.
  attr_accessor :diglett_found
  # @brief [map_id, event_id] => { species:, level:, partner: } for today.
  attr_accessor :hideaway_spawns
  # @brief [map_id, event_id] pairs of hideaway Pokémon caught or defeated today.
  attr_accessor :cleared_mons
  # @brief Sphere units owned, by color.
  attr_accessor :spheres
  # @brief Buried spheres: { color:, size:, start_size:, steps: }.
  attr_accessor :buried
  # @brief Statues in storage by statue ID.
  attr_accessor :statues
  # @brief Goods in storage by goods ID.
  attr_accessor :goods
  # @brief :small, :medium, :large, or nil before the base is unlocked.
  attr_accessor :base_size
  # @brief Items placed in the base: { kind: :statue/:good, slot:, id: }.
  attr_accessor :base_layout
  # @brief Where the base was dug: { map_id:, event_id:, exit: [map_id, x, y, direction] },
  # or nil before a wall has been chosen.
  attr_accessor :base_location
  # @brief No longer used (bases now return to their entrance). Kept so older
  # saves load.
  attr_accessor :base_return
  # @brief Diglett bonus meter progress.
  attr_accessor :diglett_meter
  # @brief Bonus digs remaining.
  attr_accessor :bonus_digs
  # @brief Index of the current Underground Man mission.
  attr_accessor :mission_stage
  # @brief Lifetime counters used by missions (:digs, :trades, ...).
  attr_accessor :stats

  # @brief Creates an empty Underground state for a new game.
  def initialize
    @day_key         = 0
    @dug_spots       = []
    @diglett_found   = []
    @hideaway_spawns = {}
    @cleared_mons    = []
    @spheres         = Hash.new(0)
    @buried          = []
    @statues         = Hash.new(0)
    @goods           = Hash.new(0)
    @base_size       = nil
    @base_layout     = []
    @base_location   = nil
    @base_return     = nil
    @diglett_meter   = 0
    @bonus_digs      = 0
    @mission_stage   = 0
    @stats           = Hash.new(0)
  end

  #-----------------------------------------------------------------------------
  # Added after the first version. Created on first use so older saves load.
  #-----------------------------------------------------------------------------
  # @brief Stations discovered from their surface entrance.
  def discovered_stations
    @discovered_stations ||= []
    return @discovered_stations
  end

  # @brief Lines whose mine carts have been repaired.
  def repaired_lines
    @repaired_lines ||= []
    return @repaired_lines
  end

  # @brief Rival IDs beaten today.
  def rivals_beaten
    @rivals_beaten ||= []
    return @rivals_beaten
  end

  # @brief Rival IDs whose flag was taken today.
  def flags_taken
    @flags_taken ||= []
    return @flags_taken
  end

  # @brief Today's stock by trader ID: { ware_id => sold? }.
  def trader_stock
    @trader_stock ||= {}
    return @trader_stock
  end

  #-----------------------------------------------------------------------------
  # Daily state
  #-----------------------------------------------------------------------------
  # @brief Clears all daily state if the date has changed since it was set.
  def refresh_day!
    key = Underground.today_key
    return if key == @day_key
    @day_key = key
    @dug_spots.clear
    @diglett_found.clear
    @hideaway_spawns.clear
    @cleared_mons.clear
    rivals_beaten.clear
    flags_taken.clear
    trader_stock.clear
  end

  #-----------------------------------------------------------------------------
  # Base layout
  #-----------------------------------------------------------------------------
  # @brief IDs of every statue currently on a pedestal.
  # @return [Array<Symbol>]
  def placed_statues
    return @base_layout.select { |e| e[:kind] == :statue }.map { |e| e[:id] }
  end

  # @brief IDs of every good currently in a goods slot.
  # @return [Array<Symbol>]
  def placed_goods
    return @base_layout.select { |e| e[:kind] == :good }.map { |e| e[:id] }
  end

  # @brief What is placed in a slot.
  # @param kind [Symbol] :statue or :good
  # @param slot [Integer]
  # @return [Hash, nil] The layout entry, or nil if the slot is empty.
  def layout_at(kind, slot)
    return @base_layout.find { |e| e[:kind] == kind && e[:slot] == slot }
  end

  SaveData.register(:underground) do
    ensure_class :UndergroundSaveData
    save_value { $underground }
    load_value { |value| $underground = value }
    new_game_value { UndergroundSaveData.new }
  end
end
