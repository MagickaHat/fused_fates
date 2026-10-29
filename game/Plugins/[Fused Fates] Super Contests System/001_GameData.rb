#================================================================================================
# Pokémon Fused Fates Super Contests System - 001_GameData.rb
#================================================================================================
# Contest conditions and flavors are fixed by the games' rules, so they are
# hardcoded here like natures and stats. Everything that changes per move,
# berry or poffin is compiled from PBS files; each class's comment names its
# file, and the files themselves describe every field.

#==================================================================
# module GameData
#==================================================================
module GameData
  #==================================================================
  # class ContestCondition
  #==================================================================
  # @brief One of the five contest conditions (Cool, Beauty, Cute, Smart,
  # Tough). Each is stored on Pokemon under #attribute and raised by poffins
  # of its #flavor.
  class ContestCondition
    attr_reader :id, :real_name, :attribute, :flavor, :color, :shadow_color, :icon_position

    DATA = {}

    extend ClassMethodsSymbols
    include InstanceMethods

    def self.load; end
    def self.save; end

    # @brief Builds a condition from its registration hash.
    # @param hash [Hash]
    def initialize(hash)
      @id            = hash[:id]
      @real_name     = hash[:name] || "Unnamed"
      @attribute     = hash[:attribute]
      @flavor        = hash[:flavor]
      @color         = hash[:color] || Color.new(64, 64, 64)
      @shadow_color  = hash[:shadow_color] || Color.new(176, 176, 176)
      @icon_position = hash[:icon_position] || 0
    end

    # @brief The condition's name as shown to the player.
    # @return [String]
    def name
      return _INTL(@real_name)
    end

    # @brief The flavor that raises this condition.
    # @return [GameData::Flavor]
    def flavor_data
      return GameData::Flavor.get(@flavor)
    end

    # @brief A Pokémon's value for this condition.
    # @param pkmn [Pokemon]
    # @return [Integer]
    def value_of(pkmn)
      return pkmn.send(@attribute) || 0
    end
  end

  #==================================================================
  # class Flavor
  #==================================================================
  # @brief One of the five berry flavors. A nature likes the flavor tied to
  # the stat it raises and dislikes the flavor tied to the stat it lowers.
  class Flavor
    attr_reader :id, :real_name, :condition, :stat

    DATA = {}

    extend ClassMethodsSymbols
    include InstanceMethods

    def self.load; end
    def self.save; end

    # @brief Builds a flavor from its registration hash.
    # @param hash [Hash]
    def initialize(hash)
      @id        = hash[:id]
      @real_name = hash[:name] || "Unnamed"
      @condition = hash[:condition]
      @stat      = hash[:stat]
    end

    # @brief The flavor's name as shown to the player.
    # @return [String]
    def name
      return _INTL(@real_name)
    end

    # @brief The condition this flavor raises.
    # @return [GameData::ContestCondition]
    def condition_data
      return GameData::ContestCondition.get(@condition)
    end

    # @brief Whether a nature likes this flavor (it raises this flavor's stat).
    # @param nature [GameData::Nature, Symbol]
    # @return [Boolean]
    def liked_by?(nature)
      return GameData::Nature.get(nature).stat_changes.any? { |stat, change| stat == @stat && change > 0 }
    end

    # @brief Whether a nature dislikes this flavor (it lowers this flavor's stat).
    # @param nature [GameData::Nature, Symbol]
    # @return [Boolean]
    def disliked_by?(nature)
      return GameData::Nature.get(nature).stat_changes.any? { |stat, change| stat == @stat && change < 0 }
    end

    # @brief The flavor a nature likes.
    # @param nature [GameData::Nature, Symbol]
    # @return [GameData::Flavor, nil] nil for neutral natures.
    def self.liked_by(nature)
      each { |flavor| return flavor if flavor.liked_by?(nature) }
      return nil
    end

    # @brief The flavor a nature dislikes.
    # @param nature [GameData::Nature, Symbol]
    # @return [GameData::Flavor, nil] nil for neutral natures.
    def self.disliked_by(nature)
      each { |flavor| return flavor if flavor.disliked_by?(nature) }
      return nil
    end
  end

  #==================================================================
  # class ContestEffect
  #==================================================================
  # @brief A contest effect, compiled from PBS/contest_effects.txt. Each move
  # has one, which gives the move its base appeal and its description on the
  # summary's CONTEST MOVES page.
  #
  # Effects only describe themselves for now. Flags is read and stored so the
  # Acting round can give effects their mechanics once it is built.
  class ContestEffect
    attr_reader :id, :real_name, :real_description, :appeal, :flags

    DATA = {}
    DATA_FILENAME     = "contest_effects.dat"
    PBS_BASE_FILENAME = "contest_effects"
    SCHEMA = {
      "SectionName" => [:id,               "m"],
      "Name"        => [:real_name,        "s"],
      "Description" => [:real_description, "q"],
      "Appeal"      => [:appeal,           "u"],
      "Flags"       => [:flags,            "*s"]
    }

    extend ClassMethodsSymbols
    include InstanceMethods

    # @brief Builds a contest effect from compiled PBS data.
    # @param hash [Hash] Values keyed by schema attribute.
    def initialize(hash)
      @id               = hash[:id]
      @real_name        = hash[:real_name] || @id.to_s
      @real_description = hash[:real_description] || ""
      @appeal           = hash[:appeal] || 0
      @flags            = hash[:flags] || []
    end

    # @brief The effect's name as shown to the player.
    # @return [String]
    def name
      return _INTL(@real_name)
    end

    # @brief The effect's description as shown to the player.
    # @return [String]
    def description
      return _INTL(@real_description)
    end

    # @brief Whether the effect has a flag.
    # @param flag [String]
    # @return [Boolean]
    def has_flag?(flag)
      return @flags.any? { |f| f.downcase == flag.downcase }
    end
  end

  #==================================================================
  # class ContestMove
  #==================================================================
  # @brief A move's contest data, compiled from PBS/contest_moves.txt.
  #
  # The condition and effect are used now. Appeal and Description override
  # the effect's own, and Jam is stored for the Acting round.
  class ContestMove
    attr_reader :id, :condition, :jam, :effect, :real_description

    DATA = {}
    DATA_FILENAME     = "contest_moves.dat"
    PBS_BASE_FILENAME = "contest_moves"
    SCHEMA = {
      "SectionName" => [:id,               "e", :Move],
      "Condition"   => [:condition,        "e", :ContestCondition],
      "Effect"      => [:effect,           "e", :ContestEffect],
      "Appeal"      => [:appeal,           "u"],
      "Jam"         => [:jam,              "u"],
      "Description" => [:real_description, "q"]
    }

    extend ClassMethodsSymbols
    include InstanceMethods

    # @brief Builds a move's contest data from compiled PBS data.
    # @param hash [Hash] Values keyed by schema attribute.
    def initialize(hash)
      @id               = hash[:id]
      @condition        = hash[:condition] || ContestSettings::DEFAULT_CONDITION
      @effect           = hash[:effect]
      @appeal           = hash[:appeal]
      @jam              = hash[:jam]
      @real_description = hash[:real_description]
    end

    # @brief The move's contest effect.
    # @return [GameData::ContestEffect, nil] nil if it has none, or its effect
    #   was removed from contest_effects.txt.
    def effect_data
      return GameData::ContestEffect.try_get(@effect)
    end

    # @brief The move's appeal: its own Appeal, or its effect's.
    # @return [Integer, nil] nil if it has neither.
    def appeal
      return @appeal || effect_data&.appeal
    end

    # @brief The move's contest description: its own Description, or its
    # effect's.
    # @return [String, nil] nil if it has neither.
    def description
      return _INTL(@real_description) if !nil_or_empty?(@real_description)
      return effect_data&.description
    end

    # @brief The condition a move appeals to, falling back to
    # ContestSettings::DEFAULT_CONDITION for moves missing from the PBS file.
    # @param move [Symbol, GameData::Move, Pokemon::Move]
    # @return [Symbol]
    def self.condition_for(move)
      move = move.id if move.respond_to?(:id)
      data = try_get(move)
      return data ? data.condition : ContestSettings::DEFAULT_CONDITION
    end
  end

  #==================================================================
  # class BerryFlavor
  #==================================================================
  # @brief A berry's flavors and smoothness, compiled from
  # PBS/berry_flavors.txt. Only berries listed there can be cooked.
  class BerryFlavor
    attr_reader :id, :flavors, :smoothness

    DATA = {}
    DATA_FILENAME     = "berry_flavors.dat"
    PBS_BASE_FILENAME = "berry_flavors"
    SCHEMA = {
      "SectionName" => [:id,         "e", :Item],
      "Flavor"      => [:flavors,    "uuuuu"],
      "Smoothness"  => [:smoothness, "v"]
    }

    extend ClassMethodsSymbols
    include InstanceMethods

    # @brief Builds a berry's flavor data from compiled PBS data.
    # @param hash [Hash] Values keyed by schema attribute.
    def initialize(hash)
      @id         = hash[:id]
      @flavors    = hash[:flavors] || [0, 0, 0, 0, 0]
      @smoothness = hash[:smoothness] || 20
    end

    # @brief The berry's item data.
    # @return [GameData::Item]
    def item
      return GameData::Item.get(@id)
    end

    # @brief The berry's flavors keyed by flavor ID, in GameData::Flavor order.
    # @return [Hash{Symbol => Integer}]
    def flavor_hash
      ret = {}
      GameData::Flavor.keys.each_with_index { |flavor, i| ret[flavor] = @flavors[i] || 0 }
      return ret
    end

    # @brief One flavor's value.
    # @param flavor [Symbol]
    # @return [Integer]
    def flavor(flavor)
      return flavor_hash[flavor] || 0
    end
  end

  #==================================================================
  # class PoffinType
  #==================================================================
  # @brief A kind of poffin cooking can produce, compiled from PBS/poffins.txt.
  #
  # A cooked poffin becomes the matching type with the highest Priority. A
  # type matches when the poffin's level is at least MinLevel, its number of
  # flavors is between MinFlavors and MaxFlavors, and (if Flavors is set) its
  # strongest flavors are exactly Flavors, in order. Foul types are used
  # when cooking fails instead, and never match otherwise.
  class PoffinType
    attr_reader :id, :real_name, :real_description, :icon, :priority,
                :foul, :min_level, :min_flavors, :max_flavors, :flavors

    DATA = {}
    DATA_FILENAME     = "poffins.dat"
    PBS_BASE_FILENAME = "poffins"
    SCHEMA = {
      "SectionName" => [:id,               "m"],
      "Name"        => [:real_name,        "s"],
      "Description" => [:real_description, "q"],
      "Icon"        => [:icon,             "uu"],
      "Priority"    => [:priority,         "i"],
      "Foul"        => [:foul,             "b"],
      "MinLevel"    => [:min_level,        "u"],
      "MinFlavors"  => [:min_flavors,      "u"],
      "MaxFlavors"  => [:max_flavors,      "u"],
      "Flavors"     => [:flavors,          "*e", :Flavor]
    }

    extend ClassMethodsSymbols
    include InstanceMethods

    # @brief Builds a poffin type from compiled PBS data.
    # @param hash [Hash] Values keyed by schema attribute.
    def initialize(hash)
      @id               = hash[:id]
      @real_name        = hash[:real_name] || @id.to_s
      @real_description = hash[:real_description] || ""
      @icon             = hash[:icon] || [0, 0]
      @priority         = hash[:priority] || 0
      @foul             = hash[:foul] || false
      @min_level        = hash[:min_level] || 0
      @min_flavors      = hash[:min_flavors] || 0
      @max_flavors      = hash[:max_flavors] || GameData::Flavor.count
      @flavors          = hash[:flavors] || []
    end

    # @brief The poffin's name as shown to the player.
    # @return [String]
    def name
      return _INTL(@real_name)
    end

    # @brief The poffin's description as shown to the player.
    # @return [String]
    def description
      return _INTL(@real_description)
    end

    # @brief Whether this type is used for failed cooking.
    # @return [Boolean]
    def foul?
      return @foul
    end

    # @brief Whether a cooked result is this type of poffin.
    # @param level [Integer] The result's strongest flavor value.
    # @param main_flavors [Array<Symbol>] The result's flavors above 0,
    #   strongest first.
    # @return [Boolean]
    def matches?(level, main_flavors)
      return false if foul?
      return false if level < @min_level
      return false if main_flavors.length < @min_flavors || main_flavors.length > @max_flavors
      return false if !@flavors.empty? && main_flavors != @flavors
      return true
    end

    # @brief The type a cooked result becomes.
    # @param level [Integer]
    # @param main_flavors [Array<Symbol>] Strongest first.
    # @return [GameData::PoffinType]
    def self.resolve(level, main_flavors)
      best = nil
      each do |type|
        next if !type.matches?(level, main_flavors)
        best = type if best.nil? || type.priority > best.priority
      end
      return best || foul_type
    end

    # @brief The type used when cooking fails.
    # @return [GameData::PoffinType]
    def self.foul_type
      best = nil
      each do |type|
        next if !type.foul?
        best = type if best.nil? || type.priority > best.priority
      end
      return best
    end
  end
end

#==================================================================
# Conditions and flavors
#==================================================================
GameData::ContestCondition.register({
  :id            => :COOL,
  :name          => _INTL("Cool"),
  :attribute     => :cool,
  :flavor        => :SPICY,
  :color         => Color.new(240, 80, 56),
  :shadow_color  => Color.new(144, 40, 32),
  :icon_position => 0
})

GameData::ContestCondition.register({
  :id            => :BEAUTY,
  :name          => _INTL("Beauty"),
  :attribute     => :beauty,
  :flavor        => :DRY,
  :color         => Color.new(72, 136, 240),
  :shadow_color  => Color.new(40, 72, 144),
  :icon_position => 1
})

GameData::ContestCondition.register({
  :id            => :CUTE,
  :name          => _INTL("Cute"),
  :attribute     => :cute,
  :flavor        => :SWEET,
  :color         => Color.new(248, 120, 184),
  :shadow_color  => Color.new(152, 64, 112),
  :icon_position => 2
})

GameData::ContestCondition.register({
  :id            => :SMART,
  :name          => _INTL("Smart"),
  :attribute     => :smart,
  :flavor        => :BITTER,
  :color         => Color.new(80, 192, 80),
  :shadow_color  => Color.new(40, 104, 40),
  :icon_position => 3
})

GameData::ContestCondition.register({
  :id            => :TOUGH,
  :name          => _INTL("Tough"),
  :attribute     => :tough,
  :flavor        => :SOUR,
  :color         => Color.new(232, 192, 40),
  :shadow_color  => Color.new(136, 104, 16),
  :icon_position => 4
})

GameData::Flavor.register({
  :id        => :SPICY,
  :name      => _INTL("Spicy"),
  :condition => :COOL,
  :stat      => :ATTACK
})

GameData::Flavor.register({
  :id        => :DRY,
  :name      => _INTL("Dry"),
  :condition => :BEAUTY,
  :stat      => :SPECIAL_ATTACK
})

GameData::Flavor.register({
  :id        => :SWEET,
  :name      => _INTL("Sweet"),
  :condition => :CUTE,
  :stat      => :SPEED
})

GameData::Flavor.register({
  :id        => :BITTER,
  :name      => _INTL("Bitter"),
  :condition => :SMART,
  :stat      => :SPECIAL_DEFENSE
})

GameData::Flavor.register({
  :id        => :SOUR,
  :name      => _INTL("Sour"),
  :condition => :TOUGH,
  :stat      => :DEFENSE
})

#==================================================================
# module Compiler
#==================================================================
# @brief Registers the contest PBS files with the PBS compiler.
module Compiler
  module_function

  class << self
    alias __contests_compile_pbs_files compile_pbs_files unless method_defined?(:__contests_compile_pbs_files)
  end

  # @brief Compiles all PBS files, including the contest ones.
  def compile_pbs_files
    __contests_compile_pbs_files
    compile_contest_data
  end

  # @brief Compiles every contest PBS file. Also used by the debug menu to
  # reload them without restarting.
  # @param text_files [Hash, nil] From get_all_pbs_files_to_compile.
  def compile_contest_data(text_files = nil)
    text_files ||= get_all_pbs_files_to_compile
    compile_contest_effects(*text_files[:ContestEffect][1])
    compile_contest_moves(*text_files[:ContestMove][1])   # Depends on Move, ContestEffect
    compile_berry_flavors(*text_files[:BerryFlavor][1])   # Depends on Item
    compile_poffin_types(*text_files[:PoffinType][1])
  end

  # @brief Compiles PBS/contest_effects.txt.
  # @param paths [Array<String>]
  def compile_contest_effects(*paths)
    compile_PBS_file_generic(GameData::ContestEffect, *paths)
  end

  # @brief Compiles PBS/contest_moves.txt, checking every move has a condition.
  # @param paths [Array<String>]
  def compile_contest_moves(*paths)
    compile_PBS_file_generic(GameData::ContestMove, *paths) do |final_validate, hash|
      next if final_validate || hash[:condition]
      raise _INTL("Move '{1}' has no Condition.\n{2}", hash[:id], FileLineData.linereport)
    end
  end

  # @brief Compiles PBS/berry_flavors.txt, checking each section is a berry.
  # @param paths [Array<String>]
  def compile_berry_flavors(*paths)
    compile_PBS_file_generic(GameData::BerryFlavor, *paths) do |final_validate, hash|
      next if final_validate
      if !GameData::Item.get(hash[:id]).is_berry?
        raise _INTL("Item '{1}' isn't a berry (it needs the Berry flag in items.txt).\n{2}", hash[:id], FileLineData.linereport)
      end
      if !hash[:flavors]
        raise _INTL("Berry '{1}' has no Flavor.\n{2}", hash[:id], FileLineData.linereport)
      end
    end
  end

  # @brief Compiles PBS/poffins.txt, checking flavor counts and that a Foul
  # type exists.
  # @param paths [Array<String>]
  def compile_poffin_types(*paths)
    compile_PBS_file_generic(GameData::PoffinType, *paths) do |final_validate, hash|
      if final_validate
        if GameData::PoffinType.count > 0 && !GameData::PoffinType.foul_type
          raise _INTL("poffins.txt must have at least one type with Foul = true.")
        end
        next
      end
      min = hash[:min_flavors] || 0
      max = hash[:max_flavors] || GameData::Flavor.count
      if min > max
        raise _INTL("Poffin '{1}': MinFlavors is higher than MaxFlavors.\n{2}", hash[:id], FileLineData.linereport)
      end
      flavors = hash[:flavors] || []
      if flavors.uniq.length != flavors.length
        raise _INTL("Poffin '{1}' lists the same flavor twice.\n{2}", hash[:id], FileLineData.linereport)
      end
    end
  end
end
