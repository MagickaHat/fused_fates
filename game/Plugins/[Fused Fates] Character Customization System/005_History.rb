#================================================================================================
# Pokémon Fused Fates Character Customization System - 005_History.rb
#================================================================================================

#==================================================================
# class AppearanceHistory
#==================================================================
# @brief Undo, redo and revert for an appearance being edited.
# Make every change inside change { } so it can be undone; the snapshot taken when the history
# was created is what revert_all and dirty? compare against.
class AppearanceHistory
  attr_reader :appearance, :original

  # @brief Starts tracking an appearance.
  # @param appearance [PlayerAppearance] The appearance being edited (changed in place by undo/redo).
  def initialize(appearance)
    @appearance = appearance
    @original   = appearance.snapshot
    @undo       = []
    @redo       = []
  end

  # @brief Runs a change, recording it only if it actually changed something.
  # A new change clears the redo stack, as it starts a new branch of history.
  # @yield Makes the change to the appearance.
  # @return [Boolean] Whether the appearance changed.
  def change
    before = @appearance.snapshot
    yield
    return false if @appearance == before
    @undo.push(before)
    @undo.shift while @undo.length > CustomizationSettings::HISTORY_LIMIT
    @redo.clear
    return true
  end

  # @return [Boolean]
  def can_undo?
    return !@undo.empty?
  end

  # @return [Boolean]
  def can_redo?
    return !@redo.empty?
  end

  # @brief Steps back one change.
  # @return [Boolean] false if there was nothing to undo.
  def undo
    return false if @undo.empty?
    @redo.push(@appearance.snapshot)
    @appearance.restore(@undo.pop)
    return true
  end

  # @brief Steps forward one undone change.
  # @return [Boolean] false if there was nothing to redo.
  def redo
    return false if @redo.empty?
    @undo.push(@appearance.snapshot)
    @appearance.restore(@redo.pop)
    return true
  end

  # @brief Goes back to the appearance as it was when editing started (can be undone).
  # @return [Boolean] false if nothing had changed.
  def revert_all
    return change { @appearance.restore(@original) }
  end

  # @brief Puts one slot back the way it was when editing started (can be undone).
  # @param slot [Symbol]
  # @return [Boolean] false if the slot hadn't changed.
  def revert_slot(slot)
    return change do
      old = @original.part_for(slot)
      if !old
        @appearance.unequip(slot)
      else
        @appearance.equip(slot, old.id)
        (1..old.color_slots).each do |r|
          color = @original.color_for(slot, r)
          @appearance.set_color(slot, r, color.swatch, color.adjust)
        end
      end
    end
  end

  # @brief Puts one slot's colors back to its part's defaults (can be undone).
  # @param slot [Symbol]
  # @return [Boolean] false if the colors were already the defaults.
  def reset_colors(slot)
    return change { @appearance.reset_colors(slot) }
  end

  # @return [Boolean] Whether the appearance differs from when editing started.
  def dirty?
    return !(@appearance == @original)
  end
end
