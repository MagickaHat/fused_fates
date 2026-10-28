#================================================================================================
# Pokémon Fused Fates Character Customization System - 002_PlayerParts.rb
#================================================================================================

#==================================================================
# module GameData
#==================================================================
module GameData
  #==================================================================
  # class PlayerColor
  #==================================================================
  # @brief A labeled color swatch, compiled from PBS/player_colors.txt.
  # Grayscale part art is colored with a shading ramp built around the swatch's color.
  class PlayerColor
    attr_reader :id, :real_name, :color, :flags

    DATA = {}
    DATA_FILENAME     = "player_colors.dat"
    PBS_BASE_FILENAME = "player_colors"
    SCHEMA = {
      "SectionName" => [:id,        "m"],
      "Name"        => [:real_name, "s"],
      "Color"       => [:color,     "uuu"],
      "Flags"       => [:flags,     "*s"]
    }

    extend ClassMethodsSymbols
    include InstanceMethods

    # @brief Builds a swatch from compiled PBS data.
    # @param hash [Hash] Values keyed by schema attribute.
    def initialize(hash)
      @id        = hash[:id]
      @real_name = hash[:real_name] || "???"
      @color     = (hash[:color] || [128, 128, 128]).map { |c| c.clamp(0, 255) }
      @flags     = hash[:flags] || []
    end

    # @brief The swatch's label as shown to the player.
    # @return [String]
    def name
      return _INTL(@real_name)
    end

    # @brief The swatch's color as a Color object.
    # @return [Color]
    def to_color
      return ColorMath.to_color(@color)
    end

    # @brief The shading ramp used to color grayscale art with this swatch (darkest first).
    # @return [Array<Color>]
    def ramp
      @ramp ||= Ramp.generate(@color, CustomizationSettings::RAMP_STEPS)
      return @ramp
    end

    # @param flag [String]
    # @return [Boolean]
    def has_flag?(flag)
      return @flags.any? { |f| f.downcase == flag.downcase }
    end
  end

  #==================================================================
  # class PlayerPart
  #==================================================================
  # @brief Static definition of one customizable part, compiled from PBS/player_parts.txt.
  class PlayerPart
    attr_reader :id, :real_name, :slot, :graphic, :color_slots, :region_names
    attr_reader :default_colors, :default_hues, :default_saturations, :default_values
    attr_reader :occupies, :hides, :contexts, :price, :unlocked, :flags

    DATA = {}
    DATA_FILENAME     = "player_parts.dat"
    PBS_BASE_FILENAME = "player_parts"
    SCHEMA = {
      "SectionName"        => [:id,                  "m"],
      "Name"               => [:real_name,           "s"],
      "Slot"               => [:slot,                "m"],
      "Graphic"            => [:graphic,             "s"],
      "ColorSlots"         => [:color_slots,         "u"],
      "RegionNames"        => [:region_names,        "*s"],
      "DefaultColors"      => [:default_colors,      "*m"],
      "DefaultHues"        => [:default_hues,        "*i"],
      "DefaultSaturations" => [:default_saturations, "*i"],
      "DefaultValues"      => [:default_values,      "*i"],
      "Occupies"           => [:occupies,            "*m"],
      "Hides"              => [:hides,               "*m"],
      "Contexts"           => [:contexts,            "*m"],
      "Price"              => [:price,               "u"],
      "Unlocked"           => [:unlocked,            "b"],
      "Flags"              => [:flags,               "*s"]
    }

    extend ClassMethodsSymbols
    include InstanceMethods

    # @brief Builds a part definition from compiled PBS data.
    # @param hash [Hash] Values keyed by schema attribute.
    def initialize(hash)
      @id                  = hash[:id]
      @real_name           = hash[:real_name] || "???"
      @slot                = hash[:slot]
      @graphic             = hash[:graphic] || @id.to_s.downcase
      @color_slots         = [hash[:color_slots] || 1, 1].max
      @region_names        = hash[:region_names] || []
      @default_colors      = hash[:default_colors] || []
      @default_hues        = hash[:default_hues] || []
      @default_saturations = hash[:default_saturations] || []
      @default_values      = hash[:default_values] || []
      @occupies            = hash[:occupies] || []
      @hides               = hash[:hides] || []
      @contexts            = hash[:contexts] || []
      @price               = hash[:price] || 0
      @unlocked            = hash[:unlocked] || false
      @flags               = hash[:flags] || []
    end

    # @brief The part's name as shown to the player.
    # @return [String]
    def name
      return _INTL(@real_name)
    end

    # @brief Every slot this part fills: its own slot plus the ones it occupies.
    # @return [Array<Symbol>]
    def all_slots
      return [@slot] + (@occupies - [@slot])
    end

    # @brief Label for one color region.
    # @param region [Integer] 1-based region number.
    # @return [String]
    def region_name(region)
      name = @region_names[region - 1]
      return _INTL(name) if name && !name.empty?
      return (@color_slots == 1) ? _INTL("Color") : _INTL("Color {1}", region)
    end

    # @brief The swatch a region starts with.
    # @param region [Integer] 1-based region number.
    # @return [Symbol, nil] nil to leave the region's art uncolored.
    def default_color(region)
      id = @default_colors[region - 1] || @default_colors.last
      return (id && GameData::PlayerColor.exists?(id)) ? id : nil
    end

    # @brief The fine-tune adjustment a region starts with.
    # @param region [Integer] 1-based region number.
    # @return [ColorAdjust]
    def default_adjust(region)
      i = region - 1
      return ColorAdjust.new((@default_hues[i] || 0) % 360,
                             (@default_saturations[i] || 0).clamp(-100, 100),
                             (@default_values[i] || 0).clamp(-100, 100))
    end

    # @brief Checks whether this part has art for a sprite context.
    # @param context [Symbol] A key of CustomizationSettings::CONTEXTS.
    # @return [Boolean]
    def supports?(context)
      return @contexts.empty? || @contexts.include?(context)
    end

    # @param flag [String]
    # @return [Boolean]
    def has_flag?(flag)
      return @flags.any? { |f| f.downcase == flag.downcase }
    end

    # @brief Lists every part that belongs in a given slot.
    # @param slot [Symbol] e.g. :Hair, :Top.
    # @return [Array<PlayerPart>]
    def self.for_slot(slot)
      return self::DATA.values.select { |part| part.slot == slot }
    end
  end
end

#==================================================================
# module Compiler
#==================================================================
# @brief Registers player_colors.txt and player_parts.txt with the PBS compiler.
module Compiler
  module_function

  class << self
    alias __custom_compile_pbs_files compile_pbs_files unless method_defined?(:__custom_compile_pbs_files)
  end

  # @brief Compiles all PBS files, including player colors and parts.
  def compile_pbs_files
    __custom_compile_pbs_files
    text_files = get_all_pbs_files_to_compile
    compile_player_colors(*text_files[:PlayerColor][1])
    compile_player_parts(*text_files[:PlayerPart][1])   # Depends on PlayerColor
  end

  # @brief Compiles PBS/player_colors.txt.
  # @param paths [Array<String>]
  def compile_player_colors(*paths)
    compile_PBS_file_generic(GameData::PlayerColor, *paths)
  end

  # @brief Compiles PBS/player_parts.txt, checking slots and swatches as it goes.
  # @param paths [Array<String>]
  def compile_player_parts(*paths)
    compile_PBS_file_generic(GameData::PlayerPart, *paths) do |final_validate, hash|
      validate_compiled_player_part(hash) if !final_validate
    end
  end

  # @brief Raises a readable error for an unknown slot, context or swatch.
  # @param hash [Hash] One compiled section.
  def validate_compiled_player_part(hash)
    slots = CustomizationSettings::SLOT_ORDER
    if !slots.include?(hash[:slot])
      raise _INTL("Slot '{1}' is not in CustomizationSettings::SLOT_ORDER.\n{2}", hash[:slot], FileLineData.linereport)
    end
    ((hash[:occupies] || []) + (hash[:hides] || [])).each do |slot|
      next if slots.include?(slot)
      raise _INTL("Slot '{1}' is not in CustomizationSettings::SLOT_ORDER.\n{2}", slot, FileLineData.linereport)
    end
    (hash[:contexts] || []).each do |context|
      next if CustomizationSettings::CONTEXTS.key?(context)
      raise _INTL("Context '{1}' is not in CustomizationSettings::CONTEXTS.\n{2}", context, FileLineData.linereport)
    end
    (hash[:default_colors] || []).each do |color|
      next if GameData::PlayerColor.exists?(color)
      raise _INTL("Color '{1}' is not defined in player_colors.txt.\n{2}", color, FileLineData.linereport)
    end
  end
end
