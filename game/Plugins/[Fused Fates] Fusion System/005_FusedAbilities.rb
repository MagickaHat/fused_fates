#================================================================================================
# Pokémon Fused Fates Fusion System - 005_Abilities.rb
#================================================================================================

#==================================================================
# module FusedAbilities
#==================================================================
module FusedAbilities
  @combo_registry = {}
  @equivalent_abilities = {}

  # Abilities which are too volatile to fuse at all
  @blacklisted_singles = [:WONDERGUARD, :SHADOWTAG, :ARENATRAP]

  # Specific pairs that create broken syngergies
  @blacklisted_pairs = [
    [:HUGEPOWER, :PUREPOWER],
    [:PROTEAN, :LIBERO],
    [:MAGICGUARD, :UNAWARE],
    [:MAGICGUARD, :REGENERATOR]
  ]

  # Registry of all abilities with overworld effects
  OVERWORLD_ABILITIES = [
    :ARENATRAP, :COMPOUNDEYES, :CUTECHARM, :FLASHFIRE, :HARVEST, :HUSTLE,
    :ILLUMINATE, :INTIMIDATE, :KEENEYE, :LIGHTNINGROD, :MAGNETPULL, :NOGUARD, 
    :PRESSURE, :QUICKFEET, :SANDVEIL, :SNOWCLOAK, :STATIC, :STENCH, 
    :STICKYHOLD, :SUCTIONCUPS, :SUPERLUCK, :SWARM, :SYNCHRONIZE, 
    :VITALSPIRIT, :WHITESMOKE, :FLAMEBODY, :MAGMAARMOR, :STEAMENGINE, 
    :HONEYGATHER, :PICKUP
  ]

  def self.combo_registry
    @combo_registry
  end

  # Register custom pairs of different abilities that share the exact same effects
  def self.register_equivalent_ability(id1, id2)
    @equivalent_abilities[id1] ||= []
    @equivalent_abilities[id1] << id2 unless @equivalent_abilities[id1].include?(id2)
    @equivalent_abilities[id2] ||= []
    @equivalent_abilities[id2] << id1 unless @equivalent_abilities[id2].include?(id1)
  end

  # Checks if two abilities have the exact same effects
  def self.same_effects?(head_id, body_id)
    return true if head_id == body_id
    return true if @equivalent_abilities[head_id]&.include?(body_id)
    return false
  end

  # Checks if an ability is blacklisted for fusion
  def self.blacklisted_single?(ability_id)
    @blacklisted_singles.include?(ability_id)
  end

  # Checks if a specific pair of abilities is blacklisted for fusion
  def self.blacklisted_pair?(head_id, body_id)
    @blacklisted_pairs.any? { |pair| pair.include?(head_id) && pair.include?(body_id) }
  end

  # Checks if an ability affects the overworld
  def self.is_overworld_ability?(ability_id)
    return false if ability_id.nil?
    if ability_id.is_a?(Array)
      return ability_id.any? { |ab| OVERWORLD_ABILITIES.include?(ab) }
    end
    return OVERWORLD_ABILITIES.include?(ability_id)
  end

  def self.register_combo(head_id, body_id)
    combo_id = :"ASONE_#{head_id}_#{body_id}"
    return combo_id if @combo_registry.key?(combo_id)

    @combo_registry[combo_id] = [head_id, body_id]

    # Register visual ability for the UI if it hasn't been created yet
    unless GameData::Ability.exists?(combo_id)
      head_name = GameData::Ability.try_get(head_id)&.name || "Unknown"
      body_name = GameData::Ability.try_get(body_id)&.name || "Unknown"

      GameData::Ability.register({
        :id => combo_id,
        :name => "As One",
        :description => "Combines #{head_name} and #{body_name}."
      })
    end

    self.bind_combo_to_effects(combo_id, head_id, body_id)

    return combo_id
  end

  def self.get_components(combo_id)
    return @combo_registry[combo_id]
  end

  # Automatically register the fusion combo 
  def self.bind_combo_to_effects(combo_id, head_id, body_id)
    return if !defined?(Battle::AbilityEffects)

    Battle::AbilityEffects.constants.each do |const_name|
      handler_hash = Battle::AbilityEffects.const_get(const_name)
      next unless handler_hash.respond_to?(:add) && handler_hash.respond_to?(:[])

      has_head = handler_hash[head_id]
      has_body = handler_hash[body_id]

      if has_head || has_body
        handler_hash.add(combo_id, proc { |*args|
          res1 = has_head ? has_head.call(*args) : nil
          res2 = has_body ? has_body.call(*args) : nil

          next nil if res1.nil? && res2.nil?

          # Numeric / Math Hooks
          if res1.is_a?(Numeric) || res2.is_a?(Numeric)
            base_val = args.find { |arg| arg.is_a?(Numeric) } || 0.0
            val1 = res1.is_a?(Numeric) ? res1 : base_val
            val2 = res2.is_a?(Numeric) ? res2 : base_val

            if base_val == 0.0
              result = base_val + (val1 - base_val) + (val2 - base_val)
            else
              mod1 = val1.to_f / base_val
              mod2 = val2.to_f / base_val

              # If both components try to boost damage, scale down the secondary boost slightly
              mod2 = 1.0 + ((mod2 - 1.0) * 0.5) if mod2 > 1.0 && mod1 > 1.0

              result = base_val * mod1 * mod2
            end
            
            next (base_val.is_a?(Integer) && res1.is_a?(Integer)) ? result.round : result

          # Boolean & Object Hooks
          else
            next true if res1 == true || res2 == true
            next false if res1 == false && res2 == false
            next res1 if !res1.nil?
            next res2 if !res2.nil?
            next nil
          end
        })
      end
    end
  end
end

# Bind all registered combos once scripts are fully loaded
if defined?(Battle::AbilityEffects)
  FusedAbilities.instance_variable_get(:@combo_registry)&.each do |combo_id, comps|
    FusedAbilities.bind_combo_to_effects(combo_id, comps[0], comps[1])
  end
end

#==================================================================
# class FusedPokemon
#==================================================================
class FusedPokemon
  attr_accessor :ability_override

  # Override ability getter
  def ability
    return GameData::Ability.get(@ability_override) if defined?(@ability_override) && @ability_override
    return super unless fused?
    return super if !@original_head_data || !@original_body_data
    
    # Determine the ability index safely
    idx = self.ability_index || 0

    if @original_head_data.respond_to?(:ability_id)
      # Triggered by actual Pokemon objects (Player's fusions)
      head_sym = @original_head_data.ability_id
    else
      # Triggered by GameData::Species objects (Trainer / Wild battles)
      if idx >= 2 && !@original_head_data.hidden_abilities.empty?
        ha_idx = idx - 2
        head_sym = @original_head_data.hidden_abilities[ha_idx] || @original_head_data.hidden_abilities[0]
      else
        head_sym = @original_head_data.abilities[idx] || @original_head_data.abilities[0]
      end
    end

    if @original_body_data.respond_to?(:ability_id)
      # Triggered by actual Pokemon objects (Player's fusions)
      body_sym = @original_body_data.ability_id
    else
      # Triggered by GameData::Species objects (Trainer / Wild battles)
      if idx >= 2 && !@original_body_data.hidden_abilities.empty?
        ha_idx = idx - 2
        body_sym = @original_body_data.hidden_abilities[ha_idx] || @original_body_data.hidden_abilities[0]
      else
        body_sym = @original_body_data.abilities[idx] || @original_body_data.abilities[0]
      end
    end

    # Wrap the symbol in GameData::Ability.get() to pass objects to the engine
    head_abil = head_sym ? GameData::Ability.get(head_sym) : nil
    body_abil = body_sym ? GameData::Ability.get(body_sym) : nil
    
    # Fallback if a component lacks an ability
    return super if !head_abil || !body_abil

    # Duplicate Clause
    return GameData::Ability.get(head_abil) if FusedAbilities.same_effects?(head_abil, body_abil)
    
    # Blacklist Clause
    if FusedAbilities.blacklisted_single?(head_abil) || 
      FusedAbilities.blacklisted_single?(body_abil) || 
      FusedAbilities.blacklisted_pair?(head_abil, body_abil)
      return GameData::Ability.get(head_abil)
    end

    chosen_ability = head_abil
    
    # Register and return the combined ability proxy
    combo_id = FusedAbilities.register_combo(head_abil, body_abil)
    return GameData::Ability.get(combo_id) || GameData::Ability.get(chosen_ability)
  end

  def ability=(value)
    if fused?
      if value.is_a?(GameData::Ability)
        @ability_override = value.id
      elsif value.is_a?(Symbol) || value.is_a?(String)
        @ability_override = value.to_sym
      else
        @ability_override = value.respond_to?(:id) ? value.id : nil
      end
      calc_stats if respond_to?(:calc_stats)
    else
      super(value)
    end
  end

  def ability_id
    return ability.id if fused?
    return super
  end
end

#==================================================================
# class Pokemon
#==================================================================
class Pokemon
  alias_method :fusion_hasAbility?, :hasAbility? unless method_defined?(:fusion_hasAbility?)

  def hasAbility?(value = nil)
    current_ability = self.ability_id
    return false if current_ability.nil?
    return true if value.nil?

    # Check Fused Components
    components = FusedAbilities.get_components(current_ability)
    
    if components
      # If the game is checking for a map/field effect, enforce the "One Effect" rule
      if FusedAbilities.is_overworld_ability?(value)
        head_has_ow = FusedAbilities.is_overworld_ability?(components[0])
        body_has_ow = FusedAbilities.is_overworld_ability?(components[1])
        
        # Head Component > Body Component > None
        active_ow_comp = head_has_ow ? components[0] : (body_has_ow ? components[1] : nil)
        
        if value.is_a?(Array)
          return value.include?(active_ow_comp)
        else
          return active_ow_comp == value
        end
      end
      
      # For all non-overworld checks allow both components
      if value.is_a?(Array)
        return true if value.any? { |ab| components.include?(ab) }
      else
        return true if components.include?(value)
      end
    end

    # Standard non-fused fallback check
    return fusion_hasAbility?(value)
  end
end

#==================================================================
# module GameData class Ability
#==================================================================
module GameData
  class Ability
    # Alias the original name method to preserve standard functionality
    alias fusion_name name unless method_defined?(:fusion_name)
    
    def name
      # Intercept dynamically created fusion abilities
      return "As One" if @id.to_s.start_with?("ASONE_")
      
      # Return normal message file names for everything else
      return fusion_name
    end

    # Alias the original description method
    alias fusion_description description unless method_defined?(:fusion_description)
    
    def description
      if @id.to_s.start_with?("ASONE_")
        components = FusedAbilities.get_components(@id)
        if components
          # Safely fetch the names of both component abilities
          head_name = GameData::Ability.try_get(components[0])&.name || "Unknown"
          body_name = GameData::Ability.try_get(components[1])&.name || "Unknown"
          return "Combines #{head_name} and #{body_name}."
        end
      end
      
      # Return normal message file descriptions for everything else
      return fusion_description
    end
  end
end

#==================================================================
# class Battle::Battler
#==================================================================
class Battle::Battler
  alias fusion_hasActiveAbility? hasActiveAbility? unless method_defined?(:fusion_hasActiveAbility?)

  def hasActiveAbility?(check_ability = nil, ignore_fainted = false)
    return false if fainted? && !ignore_fainted
    return false if @effects[PBEffects::GastroAcid]
    
    # Neutralizing Gas Infinite Loop Protection
    if check_ability != :NEUTRALIZINGGAS
      @is_checking_ng = true unless defined?(@is_checking_ng)
      if !@is_checking_ng
        @is_checking_ng = true
        has_ng = @battle.pbCheckGlobalAbility(:NEUTRALIZINGGAS)
        @is_checking_ng = false
        return false if has_ng
      end
    end

    current_ability = self.ability_id
    return false if current_ability.nil?

    # Check Fused Components
    combo = FusedAbilities.get_components(current_ability)
    if combo
      if check_ability.is_a?(Array)
        return true if check_ability.any? { |ab| combo.include?(ab) }
      elsif check_ability
        return true if combo.include?(check_ability)
      else
        return true # General check: "Does this battler have any active ability?"
      end
    end

    # Standard non-fused fallback check
    if check_ability.is_a?(Array)
      return check_ability.include?(current_ability)
    elsif check_ability
      return current_ability == check_ability
    end

    return true
  end
end

#==================================================================
# module Battle::AbilityEffects
#==================================================================
module Battle::AbilityEffects
  class << self
    alias_method :fusion_trigger, :trigger unless method_defined?(:fusion_trigger)

    def trigger(hash, *args, ret: false)
      ability = args[0]
      components = FusedAbilities.get_components(ability)
      
      # If this is not a fused ability, proceed with the normal engine logic
      return fusion_trigger(hash, *args, ret: ret) if components.nil?

      # Create argument copies for both the Head and Body components
      args1 = args.dup
      args1[0] = components[0]
      
      args2 = args.dup
      args2[0] = components[1]

      # Trigger both component abilities independently
      res1 = fusion_trigger(hash, *args1, ret: ret)
      res2 = fusion_trigger(hash, *args2, ret: ret)

      # Duck Typing Math Hooks
      if ret.is_a?(Numeric)
        res1 = ret if res1.is_a?(TrueClass) || res1.is_a?(FalseClass)
        res2 = ret if res2.is_a?(TrueClass) || res2.is_a?(FalseClass)

        base_val = ret.to_f
        
        if base_val == 0.0
          # Additive Math (e.g., Priority Bracket adjustments usually return 0)
          result = ret + (res1 - ret) + (res2 - ret)
        else
          # Multiplicative Math (e.g., SpeedCalc, Damage Multipliers)
          mod1 = res1.to_f / base_val
          mod2 = res2.to_f / base_val
          result = base_val * mod1 * mod2
        end
        
        # Preserve native Integer or Float data types for the engine
        return ret.is_a?(Integer) ? result.round : result

      # Boolean & Object Hooks
      else
        # If either component successfully triggered (returned true), the whole ability triggers
        return true if res1 == true || res2 == true
        
        # If both explicitly failed or didn't trigger, safely return false
        return false if res1 == false && res2 == false
        
        # For object-returning hooks (like ModifyMoveBaseType returning a :TYPE symbol)
        return res1 if res1 != ret
        return res2 if res2 != ret
        
        # Fallback to the default return
        return ret
      end
    end
  end
end