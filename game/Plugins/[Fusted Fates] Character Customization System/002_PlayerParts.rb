#================================================================================================
# Pokémon Fused Fates Fusion System - 002_PlayerParts.rb
#================================================================================================

#==================================================================
# module GameData
#==================================================================
# @brief Static definition of one customizable part, compiled from PBS/player_parts.txt.
module GameData
  class PlayerPart
    attr_reader :id, :real_name, :slot, :graphic, :color_slots, :default_hues, :unlocked, :flags

    DATA = {}
    DATA_FILENAME     = "player_parts.dat"
    PBS_BASE_FILENAME = "player_parts"
    SCHEMA = {
      "SectionName" => [:id,           "m"],
      "Name"        => [:real_name,    "s"],
      "Slot"        => [:slot,         "m"],
      "Graphic"     => [:graphic,      "s"],
      "ColorSlots"  => [:color_slots,  "u"],
      "DefaultHues" => [:default_hues, "*i"],
      "Unlocked"    => [:unlocked,     "b"],
      "Flags"       => [:flags,        "*s"]
    }

    extend ClassMethodsSymbols
    include InstanceMethods

    # @brief Builds a part definition from compiled PBS data.
    # @param hash [Hash] Values keyed by schema attribute.
    def initialize(hash)
      @id           = hash[:id]
      @real_name    = hash[:real_name] || "???"
      @slot         = hash[:slot]
      @graphic      = hash[:graphic]
      @color_slots  = hash[:color_slots] || 1
      @default_hues = hash[:default_hues] || [0]
      @unlocked     = hash[:unlocked] || false
      @flags        = hash[:flags] || []
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
# @brief Registers player_parts.txt with the PBS compiler and data loader.
module Compiler
  module_function

  class << self
    alias __custom_compile_pbs_files compile_pbs_files
  end

  # @brief Compiles all PBS files, including player parts.
  def compile_pbs_files
    __custom_compile_pbs_files
    compile_PBS_file_generic(GameData::PlayerPart)
  end
end