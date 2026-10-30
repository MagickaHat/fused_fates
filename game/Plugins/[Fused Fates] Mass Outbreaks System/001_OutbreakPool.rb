#================================================================================================
# Pokémon Fused Fates Mass Outbreaks System - 001_OutbreakPool.rb
#================================================================================================

#==================================================================
# module MassOutbreaks
#==================================================================
# @brief Pool of outbreaks that can be rolled, plus everything else in the
# system (see 003_Manager.rb onwards). Settings are included so they can be
# used unqualified, e.g. MassOutbreaks::TIERS.
module MassOutbreaks
  include MassOutbreaksSettings

  @@pool = {}

  # @brief Register an outbreak that can be rolled.
  # @param id [Symbol] Unique, permanent ID. Don't rename it after release.
  # @param options [Hash] Entry settings:
  #   - :map      [Integer] Map ID the outbreak happens on (required).
  #   - :species  [Symbol]  Base species (required).
  #   - :form     [Integer] Form number (default 0).
  #   - :levels   [Range]   Level range (required).
  #   - :category [Symbol]  Encounter category it replaces: :land, :cave,
  #                         :water or :fishing (default :land). Matches
  #                         GameData::EncounterType#type.
  #   - :weight   [Integer] Relative chance of being picked (default 10).
  #   - :badges   [Integer] Badges needed before it can roll (default 0).
  #   - :switch   [Integer] Extra game switch that must be ON (default nil).
  #   - :zone     [Symbol]  Region zone, limited by MAX_PER_ZONE (default nil).
  #   - :hours    [Range, Integer] Duration in :rotating mode (default
  #                         DURATION_HOURS).
  #   - :perks    [Array]   Tier list overriding MassOutbreaks::TIERS, in the
  #                         same format.
  # @raise [ArgumentError] If the ID is reused or a required key is missing.
  def self.register(id, **options)
    raise ArgumentError, "Mass outbreak #{id} registered twice" if @@pool[id]
    entry = {
      id:       id,
      map:      options[:map],
      species:  options[:species],
      form:     options[:form] || 0,
      levels:   options[:levels],
      category: options[:category] || :land,
      weight:   options[:weight] || 10,
      badges:   options[:badges] || 0,
      switch:   options[:switch],
      zone:     options[:zone],
      hours:    options[:hours],
      perks:    options[:perks]
    }
    [:map, :species, :levels].each do |key|
      raise ArgumentError, "Mass outbreak #{id} is missing :#{key}" if !entry[key]
    end
    @@pool[id] = entry
  end

  # @brief All registered entries.
  # @return [Hash{Symbol => Hash}] Entries keyed by ID.
  def self.pool
    return @@pool
  end

  # @brief Look up one entry.
  # @param id [Symbol] Entry ID.
  # @return [Hash, nil] The entry, or nil if it no longer exists.
  def self.entry(id)
    return @@pool[id]
  end

  #----------------------------------------------------------------
  # Outbreak entries
  #----------------------------------------------------------------
  # Register entries here (or from another plugin) with MassOutbreaks.register.
  # The map IDs below are only examples; replace them with real routes.
  #
  #   # A grass outbreak that can show up from the start.
  #   MassOutbreaks.register(:route1_doduo,
  #     map:     5,
  #     species: :DODUO,
  #     levels:  4..7,
  #     zone:    :south
  #   )
  #
  #   # A surfing outbreak that needs 3 badges and is twice as likely to roll.
  #   MassOutbreaks.register(:route4_psyduck,
  #     map:      12,
  #     species:  :PSYDUCK,
  #     levels:   18..22,
  #     category: :water,
  #     weight:   20,
  #     badges:   3,
  #     zone:     :east
  #   )
  #
  #   # A fishing outbreak of an alternate form that always lasts 4 hours in
  #   # :rotating mode and has its own, easier tiers.
  #   MassOutbreaks.register(:lake_shellos_east,
  #     map:      20,
  #     species:  :SHELLOS,
  #     form:     1,
  #     levels:   25..30,
  #     category: :fishing,
  #     hours:    4,
  #     perks:    [
  #       { count: 20, shiny_rolls: 1, hidden_ability: 10 },
  #       { count: 0,  shiny_rolls: 0, hidden_ability: 0 }
  #     ]
  #   )
end