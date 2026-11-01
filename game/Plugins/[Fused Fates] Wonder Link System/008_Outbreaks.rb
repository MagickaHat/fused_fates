#================================================================================================
# Pokémon Fused Fates Wonder Link System - 008_Outbreaks.rb
#================================================================================================
# Only loaded alongside the Mass Outbreaks System.
#
# Redeeming a profile code has an OUTBREAK_CHANCE percent chance to start a Mass Outbreak of one
# of the sharer's species. Outbreaks only happen on a map where that species (or, for evolved
# Pokémon, its baby form; for fusions, either component) already appears in the wild, and never
# replace an outbreak that is already running.
if defined?(MassOutbreaks)

  #==================================================================
  # module WonderLink::Outbreaks
  #==================================================================
  # @brief Starts Mass Outbreaks from redeemed profile codes.
  module WonderLink
    module Outbreaks
      # Start of the ID of every outbreak entry Wonder Link creates
      ID_PREFIX = "wonderlink_"

      module_function

      # @brief Whether a pool entry was created by Wonder Link. These are never rolled on their
      # own; they only start when a code is redeemed.
      # @param id [Symbol]
      # @return [Boolean]
      def wonder_link_entry?(id)
        return id.to_s.start_with?(ID_PREFIX)
      end

      # @brief Species from a code that could break out.
      # @param decoded [Hash] A decoded :party code.
      # @return [Array<Symbol>]
      def candidate_species(decoded)
        ret = []
        decoded[:party].each do |rec|
          list = rec[:fusion] ? [rec[:fusion][:head], rec[:fusion][:body]] : [rec[:species]]
          list.each do |species|
            ret.push(species)
            baby = GameData::Species.try_get(species)&.get_baby_species
            ret.push(baby) if baby
          end
        end
        return ret.uniq
      end

      # @brief Every map and encounter category where a species appears in the wild.
      # @param species [Symbol]
      # @return [Array<Hash>] Partial pool entries ({ id:, species:, map:, category:, levels: }).
      def spawn_options(species)
        version = $PokemonGlobal&.encounter_version || 0
        ret = []
        GameData::Encounter.each_of_version(version) do |enc|
          enc.types.each do |enc_type, slots|
            category = GameData::EncounterType.try_get(enc_type)&.type
            next if !WonderLinkSettings::OUTBREAK_CATEGORIES.include?(category)
            matches = slots.select { |slot| slot[1] == species }
            next if matches.empty?
            next if ret.any? { |o| o[:map] == enc.map && o[:category] == category }
            min = matches.map { |slot| slot[2] }.min
            max = matches.map { |slot| slot[3] || slot[2] }.max
            ret.push({ id: :"#{ID_PREFIX}#{species}_#{enc.map}_#{category}", species: species,
                       map: enc.map, category: category, levels: min..max, zone: nil })
          end
        end
        return ret
      end

      # @brief Maybe starts an outbreak from a redeemed profile code.
      # @param decoded [Hash] A decoded :party code.
      # @param chance [Integer] Percent chance; defaults to OUTBREAK_CHANCE.
      # @return [Hash, nil] The pool entry that started, or nil.
      def try_start(decoded, chance = WonderLinkSettings::OUTBREAK_CHANCE)
        return nil if !MassOutbreaks.enabled? || rand(100) >= chance
        others = MassOutbreaks.active.map { |e, _rec| e }
        options = candidate_species(decoded).flat_map { |species| spawn_options(species) }
        options.select! { |o| MassOutbreaks.fits_with?(o, others) }
        return nil if options.empty?
        entry = start(options.sample)
        return nil if !entry
        pbMessage(_INTL("{1}'s Pokémon are on the move!", WonderLink.owner_name(decoded)) + "\1")
        pbMessage(MassOutbreaks.describe(entry))
        MassOutbreaks.mark_seen(entry)
        return entry
      end

      # @brief Registers (if needed), saves and starts a Wonder Link outbreak entry.
      # @param option [Hash] From spawn_options.
      # @return [Hash, nil] The pool entry, or nil if it couldn't start.
      def start(option)
        id = option[:id]
        opts = { map: option[:map], species: option[:species], levels: option[:levels],
                 category: option[:category] }
        WonderLink.data.outbreak_entries.delete(id)
        WonderLink.data.outbreak_entries[id] = opts   # Re-adding keeps the newest entries last
        MassOutbreaks.register(id, **opts) if !MassOutbreaks.entry(id)
        prune_entries
        return nil if !MassOutbreaks.force_start(id)
        return MassOutbreaks.entry(id)
      end

      # @brief Forgets the oldest saved entries that aren't running, beyond OUTBREAK_MAX_ENTRIES.
      def prune_entries
        saved = WonderLink.data.outbreak_entries
        saved.keys.each do |id|
          break if saved.length <= WonderLinkSettings::OUTBREAK_MAX_ENTRIES
          next if MassOutbreaks.record(id)
          saved.delete(id)
          MassOutbreaks.pool.delete(id)
        end
      end

      # @brief Registers the saved Wonder Link entries again after loading, so their running
      # outbreaks aren't thrown away as unknown.
      def restore_entries
        WonderLink.data.outbreak_entries.each do |id, opts|
          MassOutbreaks.register(id, **opts) if !MassOutbreaks.entry(id)
        end
      end
    end
  end

  #==================================================================
  # module MassOutbreaks
  #==================================================================
  module MassOutbreaks
    class << self
      alias_method :__wonder_link_eligible?, :eligible? unless method_defined?(:__wonder_link_eligible?)

      # @brief Wonder Link entries only start from codes, never from the normal rolls.
      # @param entry [Hash] Pool entry.
      # @return [Boolean]
      def eligible?(entry)
        return false if WonderLink::Outbreaks.wonder_link_entry?(entry[:id])
        return __wonder_link_eligible?(entry)
      end
    end
  end
end
