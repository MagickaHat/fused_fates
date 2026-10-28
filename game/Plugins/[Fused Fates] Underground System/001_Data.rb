#================================================================================================
# Pokémon Fused Fates Underground System - 001_Data.rb
#================================================================================================
# The Underground's content lives in PBS files, compiled into these GameData
# classes. Each class's comment names its file; see the files themselves for
# the format of every field.
#
# IDs are used as save data keys (sphere colors, statue and good IDs, line IDs
# and so on), so renaming a section in a PBS file orphans whatever the player
# already owns under the old name.

#==================================================================
# module GameData
#==================================================================
module GameData
  #==================================================================
  # class UndergroundSphere
  #==================================================================
  # @brief A sphere color, compiled from PBS/underground_spheres.txt.
  # Colors are listed in menus in the order they appear in the file.
  class UndergroundSphere
    attr_reader :id, :real_name, :small_icon, :large_icon

    DATA = {}
    DATA_FILENAME     = "underground_spheres.dat"
    PBS_BASE_FILENAME = "underground_spheres"
    SCHEMA = {
      "SectionName" => [:id,         "m"],
      "Name"        => [:real_name,  "s"],
      "SmallIcon"   => [:small_icon, "uu"],
      "LargeIcon"   => [:large_icon, "uu"]
    }

    extend ClassMethodsSymbols
    include InstanceMethods

    # @brief Builds a sphere color from compiled PBS data.
    # @param hash [Hash] Values keyed by schema attribute.
    def initialize(hash)
      @id         = hash[:id]
      @real_name  = hash[:real_name] || @id.to_s.capitalize
      @small_icon = hash[:small_icon] || [0, 0]
      @large_icon = hash[:large_icon] || [0, 0]
    end

    # @brief The color's name as shown to the player.
    # @return [String]
    def name
      return _INTL(@real_name)
    end

    # @brief Cell of the sphere's graphic on Graphics/UI/Mining/items.
    # @param large [Boolean] The 3x3 cell instead of the 2x2 one.
    # @return [Array<Integer>] [x, y]
    def icon(large)
      return large ? @large_icon : @small_icon
    end
  end

  #==================================================================
  # class UndergroundStatue
  #==================================================================
  # @brief A statue that can be owned or placed on a pedestal, compiled from
  # PBS/underground_statues.txt.
  class UndergroundStatue
    attr_reader :id, :species, :body, :tier

    # @brief Valid values for Tier.
    TIERS = [:common, :rare, :fused]

    DATA = {}
    DATA_FILENAME     = "underground_statues.dat"
    PBS_BASE_FILENAME = "underground_statues"
    SCHEMA = {
      "SectionName" => [:id,      "m"],
      "Species"     => [:species, "e", :Species],
      "Body"        => [:body,    "e", :Species],
      "Tier"        => [:tier,    "m"]
    }

    extend ClassMethodsSymbols
    include InstanceMethods

    # @brief Builds a statue from compiled PBS data.
    # @param hash [Hash] Values keyed by schema attribute.
    def initialize(hash)
      @id      = hash[:id]
      @species = hash[:species]
      @body    = hash[:body]
      @tier    = hash[:tier] || :common
    end

    # @brief Whether the statue shows a fusion.
    # @return [Boolean]
    def fused?
      return !@body.nil?
    end

    # @brief Whether the statue shows a species, as itself or either half of a fusion.
    # @param species [Symbol]
    # @return [Boolean]
    def shows?(species)
      return @species == species || @body == species
    end

    # @brief The statue's name, built from its species: "Pikachu Statue",
    # "Shinxible Statue"...
    # @return [String]
    def name
      name = GameData::Species.get(@species).name
      if @body
        body = GameData::Species.get(@body).name
        name = defined?(FusionHandlers) ? FusionHandlers.fusion_name(name, body) : "#{name}/#{body}"
      end
      return _INTL("{1} Statue", name)
    end
  end

  #==================================================================
  # class UndergroundGood
  #==================================================================
  # @brief A good that can be owned or placed in a goods slot, compiled from
  # PBS/underground_goods.txt.
  class UndergroundGood
    attr_reader :id, :real_name, :real_description, :charset, :use

    # @brief Valid values for Use.
    USES = [:planter, :pc]

    DATA = {}
    DATA_FILENAME     = "underground_goods.dat"
    PBS_BASE_FILENAME = "underground_goods"
    SCHEMA = {
      "SectionName" => [:id,               "m"],
      "Name"        => [:real_name,        "s"],
      "Description" => [:real_description, "q"],
      "Charset"     => [:charset,          "s"],
      "Use"         => [:use,              "m"]
    }

    extend ClassMethodsSymbols
    include InstanceMethods

    # @brief Builds a good from compiled PBS data.
    # @param hash [Hash] Values keyed by schema attribute.
    def initialize(hash)
      @id               = hash[:id]
      @real_name        = hash[:real_name] || @id.to_s
      @real_description = hash[:real_description] || ""
      @charset          = hash[:charset]
      @use              = hash[:use]
    end

    # @brief The good's name as shown to the player.
    # @return [String]
    def name
      return _INTL(@real_name)
    end

    # @brief The good's description as shown to the player.
    # @return [String]
    def description
      return _INTL(@real_description)
    end
  end

  #==================================================================
  # class UndergroundTreasureTable
  #==================================================================
  # @brief A tunnel treasure table, compiled from PBS/underground_treasures.txt.
  #
  # A dig spot uses the table named after the colon in its event name
  # ("DigSpot:volcanic") first, then the table listing its map in Maps, then
  # [default]. Fields a table leaves out are taken from [default].
  class UndergroundTreasureTable
    attr_reader :id, :maps, :spheres, :items, :weights, :statues

    DATA = {}
    DATA_FILENAME     = "underground_treasures.dat"
    PBS_BASE_FILENAME = "underground_treasures"
    SCHEMA = {
      "SectionName" => [:id,      "m"],
      "Maps"        => [:maps,    "*u"],
      "Sphere"      => [:spheres, "^ebvvv", :UndergroundSphere],
      "Items"       => [:items,   "*e", :Item],
      "Weight"      => [:weights, "^mf"],
      "Statues"     => [:statues, "*e", :UndergroundStatue]
    }

    extend ClassMethodsSymbols
    include InstanceMethods

    # @brief Builds a treasure table from compiled PBS data.
    # @param hash [Hash] Values keyed by schema attribute.
    def initialize(hash)
      @id      = hash[:id]
      @maps    = hash[:maps] || []
      @spheres = hash[:spheres]&.map do |color, large, weight, min, max|
        { color: color, large: large, weight: weight, units: min..max }
      end
      @items   = hash[:items]
      @weights = hash[:weights]&.to_h
      @statues = hash[:statues]
    end

    # @brief The table settings for a dig spot, with anything it leaves out
    # filled in from [default].
    # @param map_id [Integer, nil]
    # @param key [Symbol, String, nil] The dig spot's own table name, if any.
    # @return [Hash] { spheres:, items:, weights:, statues: }. :items is :all
    # when no table restricts it, :statues is nil for every unlocked statue.
    def self.settings_for(map_id, key = nil)
      table = nil
      table = try_get(key.to_sym) if key && !key.to_s.empty?
      table ||= for_map(map_id)
      default = try_get(:default)
      ret = {}
      [:spheres, :items, :weights, :statues].each do |field|
        value = table&.send(field)
        value = default&.send(field) if value.nil?
        ret[field] = value
      end
      ret[:spheres] ||= []
      ret[:items]   ||= :all
      ret[:weights] ||= {}
      return ret
    end

    # @brief The table that lists a map in its Maps field.
    # @param map_id [Integer, nil]
    # @return [UndergroundTreasureTable, nil]
    def self.for_map(map_id)
      return nil unless map_id
      each { |table| return table if table.maps.include?(map_id) }
      return nil
    end
  end

  #==================================================================
  # class UndergroundHideaway
  #==================================================================
  # @brief A hideaway map and the Pokémon that live in it, compiled from
  # PBS/underground_hideaways.txt. Section names are map IDs.
  class UndergroundHideaway
    attr_reader :id, :real_name, :encounters

    DATA = {}
    DATA_FILENAME     = "underground_hideaways.dat"
    PBS_BASE_FILENAME = "underground_hideaways"
    SCHEMA = {
      "SectionName" => [:id,         "u"],
      "Name"        => [:real_name,  "s"],
      "Encounter"   => [:encounters, "^evvv", :Species]
    }

    extend ClassMethodsIDNumbers
    include InstanceMethods

    # @brief Builds a hideaway from compiled PBS data.
    # @param hash [Hash] Values keyed by schema attribute.
    def initialize(hash)
      @id         = hash[:id]
      @real_name  = hash[:real_name] || "???"
      @encounters = hash[:encounters] || []
    end

    # @brief The hideaway's name as shown to the player.
    # @return [String]
    def name
      return _INTL(@real_name)
    end
  end

  #==================================================================
  # class UndergroundTrader
  #==================================================================
  # @brief An Underground trader, compiled from PBS/underground_traders.txt.
  class UndergroundTrader
    attr_reader :id, :real_name, :wares, :prices, :buys

    DATA = {}
    DATA_FILENAME     = "underground_traders.dat"
    PBS_BASE_FILENAME = "underground_traders"
    SCHEMA = {
      "SectionName" => [:id,        "m"],
      "Name"        => [:real_name, "s"],
      "Wares"       => [:wares,     "*m"],
      "Price"       => [:prices,    "^mev", nil, :UndergroundSphere],
      "Buys"        => [:buys,      "*m"]
    }

    extend ClassMethodsSymbols
    include InstanceMethods

    # @brief Builds a trader from compiled PBS data.
    # @param hash [Hash] Values keyed by schema attribute.
    def initialize(hash)
      @id        = hash[:id]
      @real_name = hash[:real_name] || "???"
      @wares     = hash[:wares] || []
      @prices    = {}
      (hash[:prices] || []).each do |ware, color, units|
        @prices[ware] ||= {}
        @prices[ware][color] = units
      end
      @buys      = hash[:buys] || @wares
    end

    # @brief The trader's name as shown to the player.
    # @return [String]
    def name
      return _INTL(@real_name)
    end
  end

  #==================================================================
  # class UndergroundRival
  #==================================================================
  # @brief A rival digger with a base (and flag) of their own, compiled from
  # PBS/underground_rivals.txt.
  class UndergroundRival
    attr_reader :id, :real_name, :trainer, :leader

    DATA = {}
    DATA_FILENAME     = "underground_rivals.dat"
    PBS_BASE_FILENAME = "underground_rivals"
    SCHEMA = {
      "SectionName" => [:id,        "m"],
      "Name"        => [:real_name, "s"],
      "Trainer"     => [:trainer,   "esU", :TrainerType],
      "Leader"      => [:leader,    "b"]
    }

    extend ClassMethodsSymbols
    include InstanceMethods

    # @brief Builds a rival from compiled PBS data.
    # @param hash [Hash] Values keyed by schema attribute.
    def initialize(hash)
      @id        = hash[:id]
      @real_name = hash[:real_name] || "???"
      type, name, version = hash[:trainer]
      @trainer   = [type, name, version || 0]
      @leader    = hash[:leader] || false
    end

    # @brief The rival's name as shown to the player.
    # @return [String]
    def name
      return _INTL(@real_name)
    end

    # @brief Whether this is the digger leader (mission 6). The leader has no flag.
    # @return [Boolean]
    def leader?
      return @leader
    end
  end

  #==================================================================
  # class UndergroundLine
  #==================================================================
  # @brief A mine cart line, compiled from PBS/underground_lines.txt.
  # A line's carts run once it is in the save data's repaired_lines.
  class UndergroundLine
    attr_reader :id, :real_name

    DATA = {}
    DATA_FILENAME     = "underground_lines.dat"
    PBS_BASE_FILENAME = "underground_lines"
    SCHEMA = {
      "SectionName" => [:id,        "m"],
      "Name"        => [:real_name, "s"]
    }

    extend ClassMethodsSymbols
    include InstanceMethods

    # @brief Builds a line from compiled PBS data.
    # @param hash [Hash] Values keyed by schema attribute.
    def initialize(hash)
      @id        = hash[:id]
      @real_name = hash[:real_name] || "???"
    end

    # @brief The line's name as shown to the player.
    # @return [String]
    def name
      return _INTL(@real_name)
    end
  end

  #==================================================================
  # class UndergroundStation
  #==================================================================
  # @brief A station (surface entrance, ladder and cart platform), compiled
  # from PBS/underground_stations.txt.
  # Positions are [map_id, x, y, direction]; map ID 0 means not set up yet.
  class UndergroundStation
    attr_reader :id, :real_name, :lines, :underground, :surface, :platform

    DATA = {}
    DATA_FILENAME     = "underground_stations.dat"
    PBS_BASE_FILENAME = "underground_stations"
    SCHEMA = {
      "SectionName" => [:id,          "m"],
      "Name"        => [:real_name,   "s"],
      "Lines"       => [:lines,       "*e", :UndergroundLine],
      "Underground" => [:underground, "uuuu"],
      "Surface"     => [:surface,     "uuuu"],
      "Platform"    => [:platform,    "uuuu"]
    }

    extend ClassMethodsSymbols
    include InstanceMethods

    # @brief Builds a station from compiled PBS data.
    # @param hash [Hash] Values keyed by schema attribute.
    def initialize(hash)
      @id          = hash[:id]
      @real_name   = hash[:real_name] || "???"
      @lines       = hash[:lines] || []
      @underground = hash[:underground] || [0, 0, 0, 0]
      @surface     = hash[:surface] || [0, 0, 0, 0]
      @platform    = hash[:platform] || [0, 0, 0, 0]
    end

    # @brief The station's name as shown to the player.
    # @return [String]
    def name
      return _INTL(@real_name)
    end
  end

  #==================================================================
  # class UndergroundBarrier
  #==================================================================
  # @brief A cave-in, compiled from PBS/underground_barriers.txt. It clears
  # once every condition it gives is met.
  class UndergroundBarrier
    attr_reader :id, :badges, :stage, :switch, :real_message

    DATA = {}
    DATA_FILENAME     = "underground_barriers.dat"
    PBS_BASE_FILENAME = "underground_barriers"
    SCHEMA = {
      "SectionName" => [:id,           "m"],
      "Badges"      => [:badges,       "u"],
      "Stage"       => [:stage,        "u"],
      "Switch"      => [:switch,       "u"],
      "Message"     => [:real_message, "q"]
    }

    extend ClassMethodsSymbols
    include InstanceMethods

    # @brief Builds a cave-in from compiled PBS data.
    # @param hash [Hash] Values keyed by schema attribute.
    def initialize(hash)
      @id           = hash[:id]
      @badges       = hash[:badges]
      @stage        = hash[:stage]
      @switch       = hash[:switch]
      @real_message = hash[:real_message] || "The way is blocked."
    end

    # @brief The message shown while the way is blocked.
    # @return [String]
    def message
      return _INTL(@real_message)
    end

    # @brief The conditions that aren't met yet, as text.
    # @return [Array<String>] Empty if the barrier is open.
    def unmet_conditions
      ret = []
      ret.push(_INTL("{1} badges", @badges)) if @badges && $player.badge_count < @badges
      ret.push(_INTL("mission stage {1}", @stage)) if @stage && Underground.data.mission_stage < @stage
      ret.push(_INTL("switch {1} ON", @switch)) if @switch && !$game_switches[@switch]
      return ret
    end

    # @brief Whether every condition is met.
    # @return [Boolean]
    def open?
      return unmet_conditions.empty?
    end
  end
end

#==================================================================
# module Compiler
#==================================================================
# @brief Registers the underground_*.txt PBS files with the PBS compiler.
module Compiler
  module_function

  class << self
    alias __underground_compile_pbs_files compile_pbs_files unless method_defined?(:__underground_compile_pbs_files)
  end

  # @brief Compiles all PBS files, including the Underground's.
  def compile_pbs_files
    __underground_compile_pbs_files
    compile_underground_data
  end

  # @brief Compiles every underground_*.txt file, in dependency order. Also
  # used by the debug menu to reload them without restarting.
  # @param text_files [Hash, nil] From get_all_pbs_files_to_compile.
  def compile_underground_data(text_files = nil)
    text_files ||= get_all_pbs_files_to_compile
    compile_underground_spheres(*text_files[:UndergroundSphere][1])
    compile_underground_statues(*text_files[:UndergroundStatue][1])        # Depends on Species
    compile_underground_goods(*text_files[:UndergroundGood][1])
    compile_underground_treasures(*text_files[:UndergroundTreasureTable][1]) # Depends on UndergroundSphere, Item, UndergroundStatue
    compile_underground_hideaways(*text_files[:UndergroundHideaway][1])   # Depends on Species
    compile_underground_traders(*text_files[:UndergroundTrader][1])       # Depends on UndergroundStatue, UndergroundGood, UndergroundSphere
    compile_underground_rivals(*text_files[:UndergroundRival][1])         # Depends on TrainerType
    compile_underground_lines(*text_files[:UndergroundLine][1])
    compile_underground_stations(*text_files[:UndergroundStation][1])     # Depends on UndergroundLine
    compile_underground_barriers(*text_files[:UndergroundBarrier][1])
  end

  # @brief Compiles PBS/underground_spheres.txt.
  # @param paths [Array<String>]
  def compile_underground_spheres(*paths)
    compile_PBS_file_generic(GameData::UndergroundSphere, *paths)
  end

  # @brief Compiles PBS/underground_statues.txt, checking tiers as it goes.
  # @param paths [Array<String>]
  def compile_underground_statues(*paths)
    compile_PBS_file_generic(GameData::UndergroundStatue, *paths) do |final_validate, hash|
      next if final_validate
      if !hash[:species]
        raise _INTL("Statue '{1}' has no Species.\n{2}", hash[:id], FileLineData.linereport)
      end
      tier = hash[:tier] || :common
      if !GameData::UndergroundStatue::TIERS.include?(tier)
        raise _INTL("Tier '{1}' must be common, rare or fused.\n{2}", tier, FileLineData.linereport)
      end
      if (tier == :fused) != !hash[:body].nil?
        raise _INTL("Statue '{1}' must have a Body if and only if its Tier is fused.\n{2}", hash[:id], FileLineData.linereport)
      end
    end
  end

  # @brief Compiles PBS/underground_goods.txt, checking uses as it goes.
  # @param paths [Array<String>]
  def compile_underground_goods(*paths)
    compile_PBS_file_generic(GameData::UndergroundGood, *paths) do |final_validate, hash|
      next if final_validate || hash[:use].nil?
      next if GameData::UndergroundGood::USES.include?(hash[:use])
      raise _INTL("Use '{1}' must be planter or pc.\n{2}", hash[:use], FileLineData.linereport)
    end
  end

  # @brief Compiles PBS/underground_treasures.txt, checking sphere sizes,
  # weights and map assignments as it goes.
  # @param paths [Array<String>]
  def compile_underground_treasures(*paths)
    map_owners = {}
    compile_PBS_file_generic(GameData::UndergroundTreasureTable, *paths) do |final_validate, hash|
      if final_validate
        if !GameData::UndergroundTreasureTable.exists?(:default)
          raise _INTL("underground_treasures.txt must have a [default] section.")
        end
        next
      end
      (hash[:spheres] || []).each do |_color, _large, _weight, min, max|
        next if min <= max
        raise _INTL("Sphere units {1}-{2}: the minimum is higher than the maximum.\n{3}", min, max, FileLineData.linereport)
      end
      (hash[:weights] || []).each do |id, _mult|
        next if GameData::UndergroundSphere.exists?(id) || GameData::Item.exists?(id)
        raise _INTL("Weight '{1}' is neither a sphere color nor an item.\n{2}", id, FileLineData.linereport)
      end
      (hash[:maps] || []).each do |map_id|
        if map_owners[map_id]
          raise _INTL("Map {1} is already in the Maps of [{2}].\n{3}", map_id, map_owners[map_id], FileLineData.linereport)
        end
        map_owners[map_id] = hash[:id]
      end
    end
  end

  # @brief Compiles PBS/underground_hideaways.txt, checking levels as it goes.
  # @param paths [Array<String>]
  def compile_underground_hideaways(*paths)
    compile_PBS_file_generic(GameData::UndergroundHideaway, *paths) do |final_validate, hash|
      next if final_validate
      (hash[:encounters] || []).each do |species, _weight, min, max|
        next if min <= max
        raise _INTL("{1}'s levels {2}-{3}: the minimum is higher than the maximum.\n{4}", species, min, max, FileLineData.linereport)
      end
    end
  end

  # @brief Compiles PBS/underground_traders.txt, checking every ware as it goes.
  # @param paths [Array<String>]
  def compile_underground_traders(*paths)
    compile_PBS_file_generic(GameData::UndergroundTrader, *paths) do |final_validate, hash|
      next if final_validate
      wares = (hash[:wares] || []) + (hash[:buys] || []) + (hash[:prices] || []).map { |p| p[0] }
      wares.each do |id|
        next if GameData::UndergroundStatue.exists?(id) || GameData::UndergroundGood.exists?(id)
        raise _INTL("Ware '{1}' is neither a statue nor a good.\n{2}", id, FileLineData.linereport)
      end
    end
  end

  # @brief Compiles PBS/underground_rivals.txt.
  # @param paths [Array<String>]
  def compile_underground_rivals(*paths)
    compile_PBS_file_generic(GameData::UndergroundRival, *paths) do |final_validate, hash|
      next if final_validate || hash[:trainer]
      raise _INTL("Rival '{1}' has no Trainer.\n{2}", hash[:id], FileLineData.linereport)
    end
  end

  # @brief Compiles PBS/underground_lines.txt.
  # @param paths [Array<String>]
  def compile_underground_lines(*paths)
    compile_PBS_file_generic(GameData::UndergroundLine, *paths)
  end

  # @brief Compiles PBS/underground_stations.txt.
  # @param paths [Array<String>]
  def compile_underground_stations(*paths)
    compile_PBS_file_generic(GameData::UndergroundStation, *paths)
  end

  # @brief Compiles PBS/underground_barriers.txt.
  # @param paths [Array<String>]
  def compile_underground_barriers(*paths)
    compile_PBS_file_generic(GameData::UndergroundBarrier, *paths)
  end
end
