#================================================================================================
# Pokémon Fused Fates Fusion System - 005_FusedAbilities.rb
#================================================================================================

#==================================================================
# module FusedAbilities
#==================================================================
module FusedAbilities
  @combo_registry = {}
  @equivalent_abilities = {}

  # Hash lookups for abilities checked on every overworld/battle query
  OVERWORLD_LOOKUP   = FusionSettings::OVERWORLD_ABILITIES.to_h { |id| [id, true] }.freeze
  BLACKLIST_LOOKUP   = FusionSettings::BLACKLISTED_ABILITIES.to_h { |id| [id, true] }.freeze

  # Kept for compatibility with code referencing the old location
  OVERWORLD_ABILITIES = FusionSettings::OVERWORLD_ABILITIES

  def self.combo_registry
    @combo_registry
  end

  # Register custom pairs of different abilities that share the exact same effects
  # @param id1 [Symbol] first ability ID
  # @param id2 [Symbol] second ability ID
  def self.register_equivalent_ability(id1, id2)
    (@equivalent_abilities[id1] ||= []) << id2 unless @equivalent_abilities[id1]&.include?(id2)
    (@equivalent_abilities[id2] ||= []) << id1 unless @equivalent_abilities[id2]&.include?(id1)
  end

  # Checks if two abilities have the exact same effects
  # @param head_id [Symbol] head ability ID
  # @param body_id [Symbol] body ability ID
  # @return [Boolean]
  def self.same_effects?(head_id, body_id)
    return true if head_id == body_id
    return @equivalent_abilities[head_id]&.include?(body_id) || false
  end

  # Checks if an ability is blacklisted for fusion
  # @param ability_id [Symbol]
  # @return [Boolean]
  def self.blacklisted_single?(ability_id)
    return BLACKLIST_LOOKUP.key?(ability_id)
  end

  # Checks if a specific pair of abilities is blacklisted for fusion
  # @param head_id [Symbol] head ability ID
  # @param body_id [Symbol] body ability ID
  # @return [Boolean]
  def self.blacklisted_pair?(head_id, body_id)
    return FusionSettings::BLACKLISTED_ABILITY_PAIRS.any? { |pair| pair.include?(head_id) && pair.include?(body_id) }
  end

  # Checks if an ability (or any ability in an array) affects the overworld
  # @param ability_id [Symbol, Array<Symbol>, nil]
  # @return [Boolean]
  def self.is_overworld_ability?(ability_id)
    return false if ability_id.nil?
    return ability_id.any? { |ab| OVERWORLD_LOOKUP.key?(ab) } if ability_id.is_a?(Array)
    return OVERWORLD_LOOKUP.key?(ability_id)
  end

  # Picks the ability a fusion should have from its two component abilities
  # @param head_id [Symbol] head ability ID
  # @param body_id [Symbol] body ability ID
  # @return [Symbol] either the head's ability or a combined "As One" ability
  def self.resolve(head_id, body_id)
    return head_id if same_effects?(head_id, body_id)
    return head_id if blacklisted_single?(head_id) || blacklisted_single?(body_id) ||
                      blacklisted_pair?(head_id, body_id)
    return register_combo(head_id, body_id)
  end

  # @return [Symbol] ID of the combined ability
  def self.register_combo(head_id, body_id)
    combo_id = :"ASONE_#{head_id}_#{body_id}"
    return combo_id if @combo_registry.key?(combo_id)

    @combo_registry[combo_id] = [head_id, body_id].freeze

    # Register visual ability for the UI if it hasn't been created yet
    unless GameData::Ability.exists?(combo_id)
      head_name = GameData::Ability.try_get(head_id)&.name || "Unknown"
      body_name = GameData::Ability.try_get(body_id)&.name || "Unknown"

      GameData::Ability.register({
        :id          => combo_id,
        :name        => "As One",
        :description => "Combines #{head_name} and #{body_name}."
      })
    end

    bind_combo_to_effects(combo_id, head_id, body_id)

    return combo_id
  end

  # @return [Array<Symbol>, nil] the [head, body] abilities of a combined ability
  def self.get_components(combo_id)
    return @combo_registry[combo_id]
  end

  # Registers the combo in every ability handler hash used by either component.
  # Needed because many engine triggers (damage calc, switch-in, AI checks) read the
  # handler hashes directly rather than going through Battle::AbilityEffects.trigger.
  def self.bind_combo_to_effects(combo_id, head_id, body_id)
    return if !defined?(Battle::AbilityEffects)

    Battle::AbilityEffects.constants.each do |const_name|
      handler_hash = Battle::AbilityEffects.const_get(const_name)
      next unless handler_hash.respond_to?(:add) && handler_hash.respond_to?(:[])

      has_head = handler_hash[head_id]
      has_body = handler_hash[body_id]
      next unless has_head || has_body

      handler_hash.add(combo_id, proc { |*args|
        res1 = has_head ? has_head.call(*args) : nil
        res2 = has_body ? has_body.call(*args) : nil

        next nil if res1.nil? && res2.nil?

        # Numeric / Math Hooks
        if res1.is_a?(Numeric) || res2.is_a?(Numeric)
          base_val = args.find { |arg| arg.is_a?(Numeric) } || 0.0
          val1 = res1.is_a?(Numeric) ? res1 : base_val
          val2 = res2.is_a?(Numeric) ? res2 : base_val

          if base_val == 0
            result = val1 + val2 - base_val
          else
            mod1 = val1.to_f / base_val
            mod2 = val2.to_f / base_val

            # If both components try to boost the value, scale down the secondary boost
            mod2 = 1.0 + ((mod2 - 1.0) * FusionSettings::SECONDARY_BOOST_SCALE) if mod2 > 1.0 && mod1 > 1.0

            result = base_val * mod1 * mod2
          end

          next (base_val.is_a?(Integer) && res1.is_a?(Integer)) ? result.round : result
        end

        # Boolean & Object Hooks
        next true if res1 == true || res2 == true
        next false if res1 == false && res2 == false
        next res1.nil? ? res2 : res1
      })
    end
  end
end

#==================================================================
# class FusedPokemon
#==================================================================
class FusedPokemon
  attr_reader :ability_override

  # @return [GameData::Ability, nil] the fusion's ability
  def ability
    return GameData::Ability.try_get(ability_id)
  end

  # Resolved once and cached until the fusion's components or ability index change
  # @return [Symbol, nil] the fusion's ability ID
  def ability_id
    return @ability_override if @ability_override
    return super unless fused? && @original_head_data && @original_body_data
    @_fusion_ability_id ||= resolve_fusion_ability_id
    return @_fusion_ability_id
  end

  # @param side [Symbol] :head or :body
  # @return [Symbol, nil] the ability the component contributes
  def component_ability_id(side)
    data = component(side)
    # Player fusions store Pokémon objects
    return data.ability_id if data.respond_to?(:ability_id)
    # Trainer / wild fusions store GameData::Species objects
    idx = ability_index || 0
    if idx >= 2 && !data.hidden_abilities.empty?
      return data.hidden_abilities[idx - 2] || data.hidden_abilities[0]
    end
    return data.abilities[idx] || data.abilities[0]
  end

  def resolve_fusion_ability_id
    head_id = component_ability_id(:head)
    body_id = component_ability_id(:body)
    # Fallback if a component lacks an ability
    return head_id || body_id unless head_id && body_id
    return FusedAbilities.resolve(head_id, body_id)
  end

  def ability=(value)
    return super(value) unless fused?
    @ability_override = case value
                        when GameData::Ability then value.id
                        when Symbol, String    then value.to_sym
                        else                        (value.respond_to?(:id)) ? value.id : nil
                        end
    invalidate_fusion_caches
    calc_stats
  end

  # @param value [Symbol, nil] ability that replaces the fusion's resolved ability
  def ability_override=(value)
    @ability_override = value
    invalidate_fusion_caches
  end

  def ability_index=(value)
    super(value)
    invalidate_fusion_caches
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
        # Head Component > Body Component > None
        active_ow_comp = components.find { |comp| FusedAbilities.is_overworld_ability?(comp) }
        return value.is_a?(Array) ? value.include?(active_ow_comp) : active_ow_comp == value
      end

      # For all non-overworld checks allow both components
      return true if value.is_a?(Array) ? value.any? { |ab| components.include?(ab) } : components.include?(value)
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
      return "As One" if FusedAbilities.get_components(@id)

      # Return normal message file names for everything else
      return fusion_name
    end

    # Alias the original description method
    alias fusion_description description unless method_defined?(:fusion_description)

    def description
      components = FusedAbilities.get_components(@id)
      if components
        # Safely fetch the names of both component abilities
        head_name = GameData::Ability.try_get(components[0])&.name || "Unknown"
        body_name = GameData::Ability.try_get(components[1])&.name || "Unknown"
        return "Combines #{head_name} and #{body_name}."
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
    components = FusedAbilities.get_components(@ability_id)

    # Normal abilities use the engine's own check
    if !components
      return abilityActive?(ignore_fainted) && !@ability_id.nil? if check_ability.nil?
      return fusion_hasActiveAbility?(check_ability, ignore_fainted)
    end

    # Fainting, Gastro Acid and Neutralizing Gas all suppress fused abilities too
    return false if !abilityActive?(ignore_fainted, check_ability)
    return true if check_ability.nil? # "Does this battler have any active ability?"
    return check_ability.any? { |ab| ab == @ability_id || components.include?(ab) } if check_ability.is_a?(Array)
    return check_ability == @ability_id || components.include?(check_ability)
  end
end

#==================================================================
# module Battle::AbilityEffects
#==================================================================
module Battle::AbilityEffects
  class << self
    alias_method :fusion_trigger, :trigger unless method_defined?(:fusion_trigger)

    def trigger(hash, *args, ret: false)
      components = FusedAbilities.get_components(args[0])

      # If this is not a fused ability, proceed with the normal engine logic
      return fusion_trigger(hash, *args, ret: ret) if components.nil?

      # Trigger both component abilities independently
      args1 = args.dup
      args1[0] = components[0]
      args2 = args.dup
      args2[0] = components[1]
      res1 = fusion_trigger(hash, *args1, ret: ret)
      res2 = fusion_trigger(hash, *args2, ret: ret)

      # Duck Typing Math Hooks
      if ret.is_a?(Numeric)
        res1 = ret unless res1.is_a?(Numeric)
        res2 = ret unless res2.is_a?(Numeric)

        if ret == 0
          # Additive Math (e.g., Priority Bracket adjustments usually return 0)
          result = res1 + res2 - ret
        else
          # Multiplicative Math (e.g., SpeedCalc, Damage Multipliers)
          result = ret.to_f * (res1.to_f / ret) * (res2.to_f / ret)
        end

        # Preserve native Integer or Float data types for the engine
        return ret.is_a?(Integer) ? result.round : result
      end

      # Boolean & Object Hooks
      # If either component successfully triggered (returned true), the whole ability triggers
      return true if res1 == true || res2 == true

      # If both explicitly failed or didn't trigger, safely return false
      return false if res1 == false && res2 == false

      # For object-returning hooks (like ModifyMoveBaseType returning a :TYPE symbol)
      return res1 if res1 != ret
      return res2 if res2 != ret
      return ret
    end
  end
end
