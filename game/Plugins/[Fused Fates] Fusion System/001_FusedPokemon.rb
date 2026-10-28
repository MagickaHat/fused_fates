#================================================================================================
# Pokémon Fused Fates Fusion System - 001_FusedPokemon.rb
#================================================================================================

#==================================================================
# class FusedPokemon < Pokemon
#==================================================================
class FusedPokemon < Pokemon
  attr_accessor :fusion_head, :fusion_body
  attr_accessor :original_head_data, :original_body_data

  # Alias Initialization to include fusion tracking
  def initialize(species, level, head = nil, body = nil)
    # Parse compound fusion symbol if passed directly
    if species.to_s.include?('_')
      parts = species.to_s.split('_')
      @fusion_head = parts[0].upcase.to_sym
      @fusion_body = parts[1..-1].join('_').upcase.to_sym
    else
      @fusion_head = head || species
      @fusion_body = body
    end

    # Check if a full Pokemon object was passed in for the Head
    if head.is_a?(Pokemon)
      @fusion_head = head.species
      @original_head_data = head.clone
    else
      @fusion_head = head
    end
    
    # Check if a full Pokemon object was passed in for the Body
    if body.is_a?(Pokemon)
      @fusion_body = body.species
      @original_body_data = body.clone
    else
      @fusion_body = body
    end
    
    # Initialize the base Pokemon object
    base_species = @fusion_head || species
    super(base_species, level)

    # Restore the Pokémon's form
    if head.is_a?(Pokemon)
      @form = head.form
      @original_head_data.form = head.form 
    end
    
    if body.is_a?(Pokemon)
      @original_body_data.form = body.form
    end

    # Clear the proxy cache generated during super() and recalculate stats
    @_virtual_species_data = nil
    calc_stats if respond_to?(:calc_stats)
  end

  def play_cry(volume = 90, pitch = 100)
    if fused? && @fusion_head && @fusion_body
      # Extract form data if it exists, otherwise default to 0
      head_form = @original_head_data ? @original_head_data.form : 0
      body_form = @original_body_data ? @original_body_data.form : 0
      
      GameData::Species.play_cry_from_species(@fusion_head, head_form, volume * 2 / 3, pitch)
      GameData::Species.play_cry_from_species(@fusion_body, body_form, volume / 3, pitch)
    else
      super(volume, pitch)
    end
  end

  # Check if the Pokémon is fused
  def fused?
    return !@fusion_head.nil? && !@fusion_body.nil?
  end

  # Ensure core engine methods receive a valid registered base species
  def species
    return @fusion_head if fused? && @fusion_head
    return super
  end

  # Delegate core attributes to the primary Pokémon
  def species=(species_id)
    # Pass through for normal Pokémon
    return super(species_id) unless fused?
    
    # Split the incoming fusion symbol into its components
    parts = species_id.to_s.split('_')
    
    if parts.length >= 2
      new_head = parts[0].upcase.to_sym
      new_body = parts[1..-1].join('_').upcase.to_sym

      # Update the hidden original head data if its species changed
      if @original_head_data && @original_head_data.species != new_head
        old_form = @original_head_data.form # Save the alternate form
        @original_head_data.species = new_head
        @original_head_data.form = old_form # Restore the alternate form
        @original_head_data.calc_stats if @original_head_data.respond_to?(:calc_stats)
      end

      # Update the hidden original body data if its species changed
      if @original_body_data && @original_body_data.species != new_body
        old_body_form = @original_body_data.form 
        @original_body_data.species = new_body
        @original_body_data.form = old_body_form 
        @original_body_data.calc_stats if @original_body_data.respond_to?(:calc_stats)
      end

      # Synchronize the fusion trackers
      @fusion_head = new_head
      @fusion_body = new_body

      # Clear the proxy cache so it will rebuild with the new species data
      @_virtual_species_data = nil
    end
    
    # Assign the combined species to the outer Pokémon
    old_outer_form = @form
    super(@fusion_head)
    @form = old_outer_form if old_outer_form
  end

  # Dynamic species data proxy
  def species_data
    return super unless respond_to?(:fused?) && fused?
    @_virtual_species_data ||= create_virtual_species_data
    return @_virtual_species_data
  end

  def create_virtual_species_data
    head_data = if @original_head_data
                  @original_head_data.respond_to?(:species_data) ? @original_head_data.species_data : @original_head_data
                else
                  GameData::Species.try_get(@fusion_head)
                end

    body_data = if @original_body_data
                  @original_body_data.respond_to?(:species_data) ? @original_body_data.species_data : @original_body_data
                else
                  GameData::Species.try_get(@fusion_body)
                end
    
    return super unless head_data && body_data
    
    return VirtualSpeciesProxy.new(head_data, body_data, @original_head_data, @original_body_data)
  end

  def compatible_with_move?(move_id)
    return super(move_id) unless respond_to?(:fused?) && fused?
    
    # Safely fetch form-specific head data
    head_data = if @original_head_data
                  @original_head_data.respond_to?(:species_data) ? @original_head_data.species_data : @original_head_data
                else
                  GameData::Species.get(@fusion_head)
                end

    # Safely fetch form-specific body data
    body_data = if @original_body_data
                  @original_body_data.respond_to?(:species_data) ? @original_body_data.species_data : @original_body_data
                else
                  GameData::Species.get(@fusion_body)
                end

    head_compat = head_data.respond_to?(:compatible_with_move?) ? head_data.compatible_with_move?(move_id) : false
    body_compat = body_data.respond_to?(:compatible_with_move?) ? body_data.compatible_with_move?(move_id) : false

    return head_compat || body_compat || super(move_id)
  end

  def getMoveList
    return super unless respond_to?(:fused?) && fused?
    return fusion_level_up_moves
  end

  # Returns a combined, unique array of all level-up move IDs from both Components
  def fusion_level_up_moves
    # Safely fetch form-specific head data
    head_data = if @original_head_data
                  @original_head_data.respond_to?(:species_data) ? @original_head_data.species_data : @original_head_data
                else
                  GameData::Species.try_get(@fusion_head)
                end

    # Safely fetch form-specific body data
    body_data = if @original_body_data
                  @original_body_data.respond_to?(:species_data) ? @original_body_data.species_data : @original_body_data
                else
                  GameData::Species.try_get(@fusion_body)
                end

    moves_list = []

    extract_moves = lambda do |species_data|
      return unless species_data && species_data.respond_to?(:moves) && species_data.moves
      species_data.moves.each do |move_data|
        if move_data.is_a?(Array) && move_data.length >= 2
          moves_list.push([move_data[0], move_data[1]])
        end
      end
    end

    extract_moves.call(head_data)
    extract_moves.call(body_data)
    moves_list.sort_by! { |move| move[0] }
    
    return moves_list
  end
end

#==================================================================
# class VirtualSpeciesProxy
#==================================================================
class VirtualSpeciesProxy
  def initialize(head, body, original_head, original_body)
    @head = head
    @body = body
    @original_head_data = original_head
    @original_body_data = original_body
  end

  def id; :VIRTUAL_FUSION; end

  def name
    head_name = @head ? @head.name : "Unknown"
    body_name = @body ? @body.name : "Unknown"
    return "#{head_name[0..(head_name.length / 2)]}#{body_name[(body_name.length / 2)..-1]}"
  end

  def play_cry(volume = 90, pitch = 100)
    head_form = @original_head_data ? @original_head_data.form : 0
    body_form = @original_body_data ? @original_body_data.form : 0
    
    GameData::Species.play_cry_from_species(@head.id, head_form, volume * 2 / 3, pitch)
    GameData::Species.play_cry_from_species(@body.id, body_form, volume / 3, pitch)
  end

  def types
    t1 = @head.types[0]
    t2 = @body.types[1] || @body.types[0]
    t1 == t2 ? [t1] : [t1, t2]
  end

  def has_type?(type)
    types.include?(type)
  end

  def baseStats
    ret = {}
    [:HP, :ATTACK, :DEFENSE, :SPECIAL_ATTACK, :SPECIAL_DEFENSE, :SPEED].each do |stat|
      head_stat = (@head.respond_to?(:base_stats) && @head.base_stats[stat]) || (@head.respond_to?(:baseStats) && @head.baseStats[stat]) || 0
      body_stat = (@body.respond_to?(:base_stats) && @body.base_stats[stat]) || (@body.respond_to?(:baseStats) && @body.baseStats[stat]) || 0
      ret[stat] = (head_stat + body_stat) / 2
    end
    return ret
  end

  def egg_groups
    return [:Undiscovered]
  end

  # Combines TM, HM, and Move Tutor compatibility arrays
  def tutor_moves
    head_tutor = @head.respond_to?(:tutor_moves) && @head.tutor_moves ? @head.tutor_moves : []
    body_tutor = @body.respond_to?(:tutor_moves) && @body.tutor_moves ? @body.tutor_moves : []
    return (head_tutor + body_tutor).uniq
  end

  # Combines Egg Moves so the Daycare/Move Relearner can access both
  def egg_moves
    head_egg = @head.respond_to?(:egg_moves) && @head.egg_moves ? @head.egg_moves : []
    body_egg = @body.respond_to?(:egg_moves) && @body.egg_moves ? @body.egg_moves : []
    return (head_egg + body_egg).uniq
  end

  # Ensures TM/HM items interacting directly with species_data respect both components
  def compatible_with_move?(move_id)
    head_compat = @head.respond_to?(:compatible_with_move?) ? @head.compatible_with_move?(move_id) : false
    body_compat = @body.respond_to?(:compatible_with_move?) ? @body.compatible_with_move?(move_id) : false
    return head_compat || body_compat
  end

  # Handle any missing methods by forwarding them to the Head's species data
  def method_missing(method, *args, &block)
    if @head.respond_to?(method)
      @head.send(method, *args, &block)
    else
      super
    end
  end

  def respond_to_missing?(method, include_private = false)
    @head.respond_to?(method, include_private) || super
  end
end