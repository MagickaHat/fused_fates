#================================================================================================
# Pokémon Fused Fates Mass Outbreaks System - 001_OutbreakPool.rb
#================================================================================================

#==================================================================
# module MassOutbreaks
#==================================================================
module MassOutbreaks
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
  #   - :perks    [Array]   Tier list overriding MassOutbreaks::TIERS.
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
end