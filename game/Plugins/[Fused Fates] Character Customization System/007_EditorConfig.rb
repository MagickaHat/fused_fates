#================================================================================================
# Pokémon Fused Fates Character Customization System - 007_EditorConfig.rb
#================================================================================================

#==================================================================
# class CustomizationConfig
#==================================================================
# @brief Describes one character editor session: what the player may change, what is offered
# and what it costs. The same editor serves every place the player's look can change; only
# the config differs.
#
# Presets:
#   CustomizationConfig.mirror               - every slot, unlocked parts, free (the default)
#   CustomizationConfig.intro                - body basics, can't be cancelled
#   CustomizationConfig.boutique(stock)      - try on and buy parts; buying unlocks them forever
#   CustomizationConfig.stylist(slots, fee:) - change only some slots, optionally for a fee
#   CustomizationConfig.debug                - every slot and every part, locked or not
#
# Any preset can be tweaked before use, e.g.
#   config = CustomizationConfig.stylist([:Hair], fee: 300, title: _INTL("Barber"))
#   config.allow_fine_tune = false
#   pbCustomizeCharacter(config)
class CustomizationConfig
  # Every command the editor knows, in the order they are listed under the slots
  ALL_COMMANDS = [:undo, :redo, :revert, :outfits, :share, :done].freeze

  # Ways a session can charge the player
  PRICING = [:none, :purchase, :fee].freeze

  # @return [String, nil] Shown in the header; nil shows no title.
  attr_accessor :title
  # @return [Array<Symbol>] Slots the player may change, in CustomizationSettings::SLOT_ORDER order.
  attr_reader   :slots
  # @return [Array<Symbol>, nil] Part ids on offer; nil offers every part the player may wear.
  attr_reader   :stock
  # @return [Symbol] :none, :purchase (unowned parts are bought on leaving) or :fee (a flat fee
  #   is charged if the look changed).
  attr_reader   :pricing
  # @return [Integer] Flat fee charged by :fee sessions.
  attr_accessor :fee
  # @return [Array<Symbol>] Commands listed under the slots (see ALL_COMMANDS). :outfits and
  #   :share replace the whole look, so only offer them when every slot is editable.
  attr_reader   :commands
  # @return [Boolean] Whether the player may leave without keeping changes.
  attr_accessor :allow_cancel
  # @return [Boolean] Whether colors can be changed.
  attr_accessor :allow_colors
  # @return [Boolean] Whether colors can be fine-tuned (also needs CustomizationSettings::ALLOW_CUSTOM_COLOR).
  attr_accessor :allow_fine_tune
  # @return [Boolean] Whether color regions can be linked.
  attr_accessor :allow_link
  # @return [Boolean] Whether parts can be taken off.
  attr_accessor :allow_remove
  # @return [Boolean] Whether parts the player hasn't unlocked are offered (boutiques, debug).
  attr_accessor :include_locked
  # @return [String, nil] Asked before Done takes effect; nil asks nothing.
  attr_accessor :confirm_text
  # @return [Symbol, nil] Preview context shown first; nil uses the first of CustomizationSettings::CONTEXTS.
  attr_accessor :start_context

  # @brief Creates a session config. Unset options take the mirror's values.
  # @param options [Hash] Any attribute of this class, e.g. title:, slots:, fee:.
  def initialize(**options)
    @title           = nil
    @slots           = CustomizationSettings::SLOT_ORDER.dup
    @stock           = nil
    @pricing         = :none
    @fee             = 0
    @commands        = ALL_COMMANDS.dup
    @allow_cancel    = true
    @allow_colors    = true
    @allow_fine_tune = true
    @allow_link      = true
    @allow_remove    = true
    @include_locked  = false
    @confirm_text    = nil
    @start_context   = nil
    options.each do |key, value|
      raise ArgumentError, "Unknown CustomizationConfig option: #{key}" if !respond_to?("#{key}=")
      send("#{key}=", value)
    end
  end

  #----------------------------------------------------------------
  # Presets
  #----------------------------------------------------------------
  # @brief The full editor: every slot and command, unlocked parts only, free.
  # @return [CustomizationConfig]
  def self.mirror
    return new
  end

  # @brief Character creation during the intro: body basics only and no way to cancel.
  # Asks nothing on Done; the intro asks whether the player is happy and reopens the editor if not.
  # @return [CustomizationConfig]
  def self.intro
    return new(title:         _INTL("Your appearance"),
               slots:         CustomizationSettings::INTRO_SLOTS,
               commands:      CustomizationSettings::INTRO_COMMANDS,
               allow_cancel:  false,
               start_context: CustomizationSettings::SHOWCASE_CONTEXT)
  end

  # @brief A cosmetics shop. Every part in stock can be tried on; leaving while wearing parts
  # the player doesn't own offers to buy them, which unlocks them for good.
  # @param stock [Array<Symbol>] Part ids for sale. Unknown ids are ignored.
  # @param title [String, nil] Shop name shown in the header.
  # @return [CustomizationConfig]
  def self.boutique(stock, title: nil)
    ids = stock.filter_map { |id| GameData::PlayerPart.try_get(id)&.id }.uniq
    slots = ids.flat_map { |id| GameData::PlayerPart.get(id).all_slots }
    return new(title:          title || _INTL("Boutique"),
               slots:          slots,
               stock:          ids,
               pricing:        :purchase,
               commands:       CustomizationSettings::SERVICE_COMMANDS,
               include_locked: true,
               start_context:  CustomizationSettings::SHOWCASE_CONTEXT)
  end

  # @brief A service that restyles some slots (a hair salon, a tailor...) using parts the
  # player already owns. A fee, if any, is only charged when the look actually changed.
  # @param slots [Array<Symbol>] Slots the service handles.
  # @param fee [Integer] Flat fee; 0 is free.
  # @param title [String, nil] Service name shown in the header.
  # @return [CustomizationConfig]
  def self.stylist(slots, fee: 0, title: nil)
    return new(title:    title,
               slots:    slots,
               pricing:  (fee > 0) ? :fee : :none,
               fee:      fee,
               commands: CustomizationSettings::SERVICE_COMMANDS)
  end

  # @brief Every slot, command and part (locked or not), free.
  # @return [CustomizationConfig]
  def self.debug
    return new(title: _INTL("Debug editor"), include_locked: true)
  end

  #----------------------------------------------------------------
  # Setters that validate
  #----------------------------------------------------------------
  # @param value [Array<Symbol>] Unknown slots are dropped; order follows CustomizationSettings::SLOT_ORDER.
  def slots=(value)
    @slots = CustomizationSettings::SLOT_ORDER & value.map(&:to_sym)
  end

  # @param value [Array<Symbol>, nil]
  def stock=(value)
    @stock = value&.map(&:to_sym)
  end

  # @param value [Symbol] One of PRICING.
  def pricing=(value)
    raise ArgumentError, "Unknown pricing: #{value}" if !PRICING.include?(value)
    @pricing = value
  end

  # @param value [Array<Symbol>] Unknown commands are dropped; :done is always kept.
  def commands=(value)
    @commands = ALL_COMMANDS & (value.map(&:to_sym) | [:done])
  end

  #----------------------------------------------------------------
  # Queries
  #----------------------------------------------------------------
  # @param slot [Symbol]
  # @return [Boolean] Whether the player may change this slot.
  def editable?(slot)
    return @slots.include?(slot)
  end

  # @return [Boolean] Whether this session can cost money.
  def paid?
    return @pricing != :none
  end

  # @return [Boolean] Whether the header (title and money) should be shown.
  def show_header?
    return !@title.nil? || paid?
  end

  # @brief Checks whether the editor lists a part for its slot.
  # A part is left out if it isn't in stock, isn't available to the player, or wearing it
  # would take off a part in a slot this session can't change (e.g. a dress in a hat shop).
  # @param part [GameData::PlayerPart]
  # @param appearance [PlayerAppearance] The appearance being edited.
  # @return [Boolean]
  def part_offered?(part, appearance)
    return false if !editable?(part.slot)
    return false if @stock && !@stock.include?(part.id)
    return false if !@include_locked && !$player.part_selectable?(part.id)
    return appearance.conflicts_with(part.id).all? { |slot| editable?(slot) }
  end

  # @param part [GameData::PlayerPart]
  # @return [Boolean] Whether the part has to be bought before it can be kept.
  def for_sale?(part)
    return @pricing == :purchase && !$player.part_unlocked?(part.id)
  end

  # @brief Worn parts from this shop's stock that must be paid for before the player can
  # leave wearing them.
  # @param appearance [PlayerAppearance]
  # @return [Array<GameData::PlayerPart>]
  def unpaid_parts(appearance)
    return appearance.worn_parts.select do |part|
      next for_sale?(part) && (!@stock || @stock.include?(part.id))
    end
  end

  # @return [Boolean] Whether fine-tuning is offered in this session.
  def fine_tune?
    return @allow_colors && @allow_fine_tune && CustomizationSettings::ALLOW_CUSTOM_COLOR
  end

  # @return [Boolean] Whether there is anything to do from the swatch grid's "more" button.
  def color_options?
    return fine_tune? || @allow_link
  end
end
