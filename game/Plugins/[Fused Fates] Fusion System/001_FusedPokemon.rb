#================================================================================================
# Pokémon Fused Fates Fusion System - 001_FusedPokemon.rb
#================================================================================================

#==================================================================
# class FusedPokemon < Pokemon
#==================================================================
class FusedPokemon < Pokemon
  attr_accessor :fusion_head, :fusion_body
  attr_accessor :original_head_data, :original_body_data
  # Hash of {:head, :body, :fused} EXP values recorded at the moment of fusion
  attr_accessor :fusion_exp_record

  # Cache variables that are rebuilt on demand and never written to save files
  TRANSIENT_IVARS = [:@_virtual_species_data, :@_fusion_ability_id].freeze

  # @param species [Symbol] species of the head (used if head is not given)
  # @param level [Integer] starting level
  # @param head [Pokemon, Symbol, nil] head component, or its species
  # @param body [Pokemon, Symbol, nil] body component, or its species
  def initialize(species, level, head = nil, body = nil)
    @fusion_head = head.is_a?(Pokemon) ? head.species : (head || species)
    @fusion_body = body.is_a?(Pokemon) ? body.species : body

    # The component Pokémon leave the party, so they are stored directly for later restoration
    @original_head_data = head if head.is_a?(Pokemon)
    @original_body_data = body if body.is_a?(Pokemon)

    # Initialize the base Pokemon object
    super(@fusion_head, level)

    # Restore the head Pokémon's form
    @form = head.form if head.is_a?(Pokemon)

    # Clear the caches generated during super() and recalculate stats
    invalidate_fusion_caches
    calc_stats
  end

  #----------------------------------------------------------------
  # Save data
  #----------------------------------------------------------------
  # Excludes cache variables so they are not serialized into save files.
  # Saves made before this existed still load, as Marshal restores them as plain objects.
  # @return [Hash] instance variables to save
  def marshal_dump
    ret = {}
    instance_variables.each do |var|
      next if TRANSIENT_IVARS.include?(var)
      ret[var] = instance_variable_get(var)
    end
    return ret
  end

  # @param data [Hash] instance variables produced by marshal_dump
  def marshal_load(data)
    data.each { |var, value| instance_variable_set(var, value) }
  end

  #----------------------------------------------------------------
  # Component helpers
  #----------------------------------------------------------------
  # @param side [Symbol] :head or :body
  # @return [Pokemon, GameData::Species, nil] the stored component data
  def component(side)
    return (side == :head) ? @original_head_data : @original_body_data
  end

  # @param side [Symbol] :head or :body
  # @return [Symbol, nil] the component's species ID
  def component_species(side)
    return (side == :head) ? @fusion_head : @fusion_body
  end

  # @param side [Symbol] :head or :body
  # @return [Integer] the component's form, or 0 if unknown
  def component_form(side)
    data = component(side)
    return (data.respond_to?(:form) && data.form) ? data.form : 0
  end

  # @param side [Symbol] :head or :body
  # @return [GameData::Species, nil] form-specific species data of the component
  def component_species_data(side)
    data = component(side)
    return data.species_data if data.respond_to?(:species_data)
    return data if data
    return GameData::Species.try_get(component_species(side))
  end

  # Clears every cached value derived from the fusion's components.
  # Call this whenever the head, body or ability of the fusion changes.
  def invalidate_fusion_caches
    @_virtual_species_data = nil
    @_fusion_ability_id    = nil
  end

  #----------------------------------------------------------------
  # Core overrides
  #----------------------------------------------------------------
  def play_cry(volume = 90, pitch = 100)
    return super(volume, pitch) unless fused?
    FusionHandlers.play_fusion_cry(@fusion_head, component_form(:head),
                                   @fusion_body, component_form(:body), volume, pitch)
  end

  # Check if the Pokémon is fused
  def fused?
    return !@fusion_head.nil? && !@fusion_body.nil?
  end

  # Ensure core engine methods receive a valid registered base species
  def species
    return @fusion_head if fused?
    return super
  end

  # Accepts either a normal species or a compound HEAD_BODY fusion symbol
  # @param species_id [Symbol, String] the new species
  def species=(species_id)
    # Pass through for normal Pokémon
    return super(species_id) unless fused?

    # Split the incoming fusion symbol into its components
    parts = species_id.to_s.split('_', 2)
    if parts.length >= 2
      new_head = parts[0].upcase.to_sym
      new_body = parts[1].upcase.to_sym

      # Register the compound symbol so engine lookups (e.g. the evolution scene) succeed
      FusionHandlers.ensure_fusion_species(species_id.to_sym, new_head)

      # Update the stored component data if its species changed
      update_component_species(:head, new_head)
      update_component_species(:body, new_body)

      # Synchronize the fusion trackers
      @fusion_head = new_head
      @fusion_body = new_body
      invalidate_fusion_caches
    end

    # Assign the head species to the outer Pokémon
    old_outer_form = @form
    super(@fusion_head)
    @form = old_outer_form if old_outer_form
  end

  # Changes a component's species while keeping its alternate form
  # @param side [Symbol] :head or :body
  # @param new_species [Symbol] the component's new species
  def update_component_species(side, new_species)
    data = component(side)
    return if !data || data.species == new_species
    if data.is_a?(Pokemon)
      old_form = data.form
      data.species = new_species
      data.form = old_form
      data.calc_stats
    else
      # Trainer fusions store species data instead of Pokémon objects
      new_data = GameData::Species.try_get(new_species)
      if side == :head
        @original_head_data = new_data
      else
        @original_body_data = new_data
      end
    end
  end

  # Dynamic species data proxy
  def species_data
    return super unless fused?
    @_virtual_species_data ||= create_virtual_species_data
    return @_virtual_species_data
  end

  def create_virtual_species_data
    head_data = component_species_data(:head)
    body_data = component_species_data(:body)
    return GameData::Species.get_species_form(@species, form_simple) unless head_data && body_data
    return VirtualSpeciesProxy.new(head_data, body_data, component_form(:head), component_form(:body))
  end

  def compatible_with_move?(move_id)
    return super(move_id) unless fused?
    [:head, :body].each do |side|
      data = component_species_data(side)
      return true if data.respond_to?(:compatible_with_move?) && data.compatible_with_move?(move_id)
    end
    return super(move_id)
  end

  def getMoveList
    return super unless fused?
    return fusion_level_up_moves
  end

  # @return [Array<Array>] combined, unique [level, move] pairs from both components
  def fusion_level_up_moves
    moves_list = []
    [:head, :body].each do |side|
      data = component_species_data(side)
      next unless data.respond_to?(:moves) && data.moves
      data.moves.each do |move_data|
        moves_list.push([move_data[0], move_data[1]]) if move_data.is_a?(Array) && move_data.length >= 2
      end
    end
    moves_list.uniq!
    moves_list.sort_by! { |move| move[0] }
    return moves_list
  end
end

#==================================================================
# class VirtualSpeciesProxy
#==================================================================
# Stands in for GameData::Species on a fused Pokémon. Values are memoized because the
# proxy is rebuilt whenever the fusion's components change.
class VirtualSpeciesProxy
  STAT_IDS = [:HP, :ATTACK, :DEFENSE, :SPECIAL_ATTACK, :SPECIAL_DEFENSE, :SPEED].freeze

  # @param head [GameData::Species] head species data
  # @param body [GameData::Species] body species data
  # @param head_form [Integer] head form, used for cries
  # @param body_form [Integer] body form, used for cries
  def initialize(head, body, head_form = 0, body_form = 0)
    @head      = head
    @body      = body
    @head_form = head_form
    @body_form = body_form
  end

  def id; :VIRTUAL_FUSION; end

  def name
    @name ||= FusionHandlers.fusion_name(@head ? @head.name : "Unknown", @body ? @body.name : "Unknown")
    return @name
  end

  def play_cry(volume = 90, pitch = 100)
    FusionHandlers.play_fusion_cry(@head.id, @head_form, @body.id, @body_form, volume, pitch)
  end

  def types
    @types ||= begin
      t1 = @head.types[0]
      t2 = @body.types[1] || @body.types[0]
      (t1 == t2) ? [t1] : [t1, t2]
    end
    return @types
  end

  def has_type?(type)
    types.include?(type)
  end

  # Averaged base stats of both components (read by Pokemon#baseStats / calc_stats)
  # @return [Hash{Symbol => Integer}]
  def base_stats
    @base_stats ||= STAT_IDS.to_h do |stat|
      [stat, ((@head.base_stats[stat] || 0) + (@body.base_stats[stat] || 0)) / 2]
    end
    return @base_stats
  end
  alias baseStats base_stats

  def egg_groups
    return [:Undiscovered]
  end

  # Combines TM, HM, and Move Tutor compatibility arrays
  def tutor_moves
    @tutor_moves ||= (Array(@head.tutor_moves) + Array(@body.tutor_moves)).uniq
    return @tutor_moves
  end

  # Combines Egg Moves so the Daycare/Move Relearner can access both
  def egg_moves
    @egg_moves ||= (Array(@head.egg_moves) + Array(@body.egg_moves)).uniq
    return @egg_moves
  end

  def get_egg_moves
    @get_egg_moves ||= (Array(@head.get_egg_moves) + Array(@body.get_egg_moves)).uniq
    return @get_egg_moves
  end

  # Ensures TM/HM items interacting directly with species_data respect both components
  def compatible_with_move?(move_id)
    return true if tutor_moves.include?(move_id) || get_egg_moves.include?(move_id)
    return [@head, @body].any? { |data| Array(data.moves).any? { |m| m[1] == move_id } }
  end

  # Handle any missing methods by forwarding them to the Head's species data
  def method_missing(method, *args, &block)
    return @head.send(method, *args, &block) if @head.respond_to?(method)
    super
  end

  def respond_to_missing?(method, include_private = false)
    @head.respond_to?(method, include_private) || super
  end
end
