#================================================================================================
# Pokémon Fused Fates Mass Outbreaks System - 002_State.rb
#================================================================================================
# @brief Where outbreak data lives between maps, battles, and save files.
# Saved state is a plain Hash of Integers and Symbols with no custom classes:
#   { mode: Symbol, day: Integer, tick: Integer,
#     active: [{ id: Symbol, count: Integer, expires: Integer or nil }, ...] }
# :day is used by :daily mode and :tick by :rotating mode. :expires is the
# hour tick an outbreak ends on, or nil for :daily outbreaks.

#==================================================================
# class PokemonGlobalMetadata
#==================================================================
# @brief Adds the saved outbreak state to the global metadata.
class PokemonGlobalMetadata
  attr_writer :mass_outbreaks

  # @brief Saved outbreak state, created on first access.
  # @return [Hash] See the file header for the layout.
  def mass_outbreaks
    @mass_outbreaks ||= { day: -1, active: [] }
    return @mass_outbreaks
  end
end

#==================================================================
# class Game_Temp
#==================================================================
# @brief Adds an unsaved flag for the battle currently being set up.
class Game_Temp
  # @brief ID of the outbreak that produced the pending wild battle, or nil.
  # Set when an encounter is replaced and cleared after the battle or on a
  # map change. Never saved.
  attr_accessor :mass_outbreak_id

  # @brief Whether the outbreak roll has already happened for the encounter
  # being set up. Stops the second Pokémon of a double encounter from rolling
  # again. Reset at the start of every encounter. Never saved.
  attr_accessor :mass_outbreak_rolled
end