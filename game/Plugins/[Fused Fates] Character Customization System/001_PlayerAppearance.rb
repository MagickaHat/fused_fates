#================================================================================================
# Pokémon Fused Fates Character Customization System - 001_PlayerAppearance.rb
#================================================================================================

#==================================================================
# class RegionColor
#==================================================================
# @brief The color chosen for one color region of a worn part: a swatch plus a fine-tune.
class RegionColor
  attr_accessor :swatch, :adjust

  # @brief Creates a region color.
  # @param swatch [Symbol, nil] A GameData::PlayerColor id; nil leaves the art uncolored.
  # @param adjust [ColorAdjust] Hue/saturation/value fine-tune applied after the swatch.
  def initialize(swatch = nil, adjust = ColorAdjust.new)
    @swatch = swatch
    @adjust = adjust
  end

  # @brief The swatch definition, if it still exists.
  # @return [GameData::PlayerColor, nil]
  def swatch_data
    return (@swatch && GameData::PlayerColor.exists?(@swatch)) ? GameData::PlayerColor.get(@swatch) : nil
  end

  # @brief Checks whether this color leaves the art unchanged.
  # @return [Boolean]
  def plain?
    return swatch_data.nil? && @adjust.identity?
  end

  # @brief A stable string identifying this color (used in cache keys).
  # @return [String]
  def key
    return "#{@swatch}/#{@adjust.key}"
  end

  # @return [RegionColor] An independent copy.
  def dup
    return RegionColor.new(@swatch, ColorAdjust.new(@adjust.hue, @adjust.saturation, @adjust.value))
  end

  # @return [Boolean]
  def ==(other)
    return other.is_a?(RegionColor) && key == other.key
  end
end

#==================================================================
# class PlayerAppearance
#==================================================================
# @brief Everything the player has chosen: a part per slot, a color per part region and
# which regions are linked so they always share a color.
#
# Colors and links are keyed by [slot, region] (region numbers start at 1). A part can also
# occupy other slots (a dress fills Top and Bottom) and hide others while worn (a hood hides
# Hair); see GameData::PlayerPart#occupies and #hides.
class PlayerAppearance
  # Version of the share code format written by to_code
  CODE_VERSION = 1

  attr_reader :parts, :colors, :links

  # @brief Creates the default appearance from CustomizationSettings::DEFAULT_PARTS.
  def initialize
    @parts  = {}   # Slot => part id
    @colors = {}   # [slot, region] => RegionColor
    @links  = []   # Arrays of [slot, region] keys that share one color
    CustomizationSettings::DEFAULT_PARTS.each do |slot, id|
      equip(slot, id) if GameData::PlayerPart.exists?(id)
    end
  end

  #----------------------------------------------------------------
  # Parts and slot occupancy
  #----------------------------------------------------------------
  # @brief Gets the part definition equipped in a slot.
  # @param slot [Symbol] The slot to look up.
  # @return [GameData::PlayerPart, nil] nil if the slot is empty or its part no longer exists.
  def part_for(slot)
    id = @parts[slot]
    return (id && GameData::PlayerPart.exists?(id)) ? GameData::PlayerPart.get(id) : nil
  end

  # @brief Every worn part, in draw order.
  # @return [Array<GameData::PlayerPart>]
  def worn_parts
    return CustomizationSettings::SLOT_ORDER.filter_map { |slot| part_for(slot) }
  end

  # @brief The part that fills a slot, either worn in it or occupying it from another slot.
  # @param slot [Symbol]
  # @return [GameData::PlayerPart, nil]
  def occupant(slot)
    part = part_for(slot)
    return part if part
    return worn_parts.find { |p| p.occupies.include?(slot) }
  end

  # @brief Checks whether a slot is filled by a part worn in a different slot.
  # @param slot [Symbol]
  # @return [Boolean]
  def covered?(slot)
    occ = occupant(slot)
    return !occ.nil? && occ.slot != slot
  end

  # @brief Slots that worn parts hide, so they are not drawn.
  # @return [Array<Symbol>]
  def hidden_slots
    return worn_parts.flat_map(&:hides).uniq
  end

  # @brief Lists the slots whose parts would be removed by wearing a part.
  # @param id [Symbol] Part id.
  # @return [Array<Symbol>] Slots that currently hold a conflicting part.
  def conflicts_with(id)
    new_part = GameData::PlayerPart.try_get(id)
    return [] if !new_part
    taken = new_part.all_slots
    return @parts.keys.select do |slot|
      next false if slot == new_part.slot
      part = part_for(slot)
      next false if !part
      next taken.include?(slot) || (part.all_slots & taken).any?
    end
  end

  # @brief Wears a part, removing every part it conflicts with.
  # The part's color regions take the color of any linked region, otherwise its defaults.
  # @param slot [Symbol] The slot to fill; must match the part's slot.
  # @param id [Symbol] Part id.
  # @return [Array<Symbol>] Ids of the parts that were removed to make room.
  def equip(slot, id)
    part = GameData::PlayerPart.try_get(id)
    return [] if !part || part.slot != slot
    removed = conflicts_with(id).map do |other|
      old = @parts.delete(other)
      clear_colors(other)
      next old
    end
    clear_colors(slot) if @parts[slot] != id
    @parts[slot] = id
    (1..part.color_slots).each do |region|
      next if @colors[[slot, region]]
      linked = linked_keys([slot, region]).find { |k| k != [slot, region] && @colors[k] }
      @colors[[slot, region]] = linked ? @colors[linked].dup : RegionColor.new(part.default_color(region), part.default_adjust(region))
    end
    return removed
  end

  # @brief Empties a slot.
  # @param slot [Symbol]
  # @return [Boolean] false if the slot is required and can't be emptied.
  def unequip(slot)
    return false if CustomizationSettings::REQUIRED_SLOTS.include?(slot)
    @parts.delete(slot)
    clear_colors(slot)
    return true
  end

  # @brief Puts a slot's colors back to its part's defaults.
  # @param slot [Symbol]
  def reset_colors(slot)
    part = part_for(slot)
    return if !part
    (1..part.color_slots).each do |region|
      set_color(slot, region, part.default_color(region), part.default_adjust(region))
    end
  end

  #----------------------------------------------------------------
  # Colors and color linking
  #----------------------------------------------------------------
  # @brief The color of one region of a worn part.
  # @param slot [Symbol]
  # @param region [Integer] 1-based region number.
  # @return [RegionColor]
  def color_for(slot, region)
    return @colors[[slot, region]] || RegionColor.new
  end

  # @brief Colors a region, and every region linked to it.
  # @param slot [Symbol]
  # @param region [Integer] 1-based region number.
  # @param swatch [Symbol, nil] GameData::PlayerColor id.
  # @param adjust [ColorAdjust]
  def set_color(slot, region, swatch, adjust = ColorAdjust.new)
    color = RegionColor.new(swatch, adjust)
    linked_keys([slot, region]).each do |key|
      @colors[key] = color.dup if region_exists?(*key)
    end
  end

  # @brief Every region that shares a color with a region, including itself.
  # @param key [Array] [slot, region]
  # @return [Array<Array>]
  def linked_keys(key)
    group = @links.find { |g| g.include?(key) }
    return group ? group.dup : [key]
  end

  # @param key [Array] [slot, region]
  # @return [Boolean] Whether the region is linked to any other.
  def linked?(key)
    return linked_keys(key).length > 1
  end

  # @brief Links two regions so they always share a color; b takes a's color.
  # Linking regions that are already in different groups merges the groups.
  # @param a [Array] [slot, region]
  # @param b [Array] [slot, region]
  def link(a, b)
    return if a == b
    group_a = linked_keys(a)
    group_b = linked_keys(b)
    @links.reject! { |g| g.include?(a) || g.include?(b) }
    @links.push((group_a + group_b).uniq)
    color = color_for(*a)
    set_color(a[0], a[1], color.swatch, color.adjust)
  end

  # @brief Removes a region from its link group.
  # @param key [Array] [slot, region]
  def unlink(key)
    @links.each { |g| g.delete(key) }
    @links.reject! { |g| g.length < 2 }
  end

  # @brief Checks whether a region belongs to a worn part.
  # @param slot [Symbol]
  # @param region [Integer]
  # @return [Boolean]
  def region_exists?(slot, region)
    part = part_for(slot)
    return !part.nil? && region.between?(1, part.color_slots)
  end

  #----------------------------------------------------------------
  # Comparison, snapshots and validation
  #----------------------------------------------------------------
  # @brief A stable string describing everything that affects how the player looks.
  # @return [String]
  def signature
    parts = CustomizationSettings::SLOT_ORDER.filter_map do |slot|
      part = part_for(slot)
      next nil if !part
      regions = (1..part.color_slots).map { |r| color_for(slot, r).key }
      next "#{slot}=#{part.id}(#{regions.join(',')})"
    end
    return parts.join(";")
  end

  # @brief A short hexadecimal digest of the signature, safe for use in file paths.
  # @return [String]
  def digest
    return format("%08x", Hex.crc32(signature))
  end

  # @return [Boolean] Whether two appearances look the same and have the same links.
  def ==(other)
    return other.is_a?(PlayerAppearance) && signature == other.signature &&
           normalized_links == other.normalized_links
  end

  # @return [Array] Links in a comparable order.
  def normalized_links
    return @links.map { |g| g.sort_by(&:to_s) }.sort_by(&:to_s)
  end

  # @brief An independent deep copy.
  # @return [PlayerAppearance]
  def snapshot
    return Marshal.load(Marshal.dump(self))
  end

  # @brief Replaces this appearance's contents with a copy of another's.
  # @param other [PlayerAppearance]
  def restore(other)
    copy = other.snapshot
    @parts  = copy.parts
    @colors = copy.colors
    @links  = copy.links
  end

  # @brief Drops parts, colors and links that no longer exist in the game data.
  # Call after loading a save made with different PBS data.
  # @return [PlayerAppearance] self
  def sanitize!
    @parts.select! do |slot, id|
      part = GameData::PlayerPart.try_get(id)
      next !part.nil? && part.slot == slot
    end
    @colors.select! { |(slot, region), _color| region_exists?(slot, region) }
    @colors.each_value { |color| color.swatch = nil if color.swatch && !GameData::PlayerColor.exists?(color.swatch) }
    @links.each { |g| g.select! { |key| region_exists?(*key) } }
    @links.reject! { |g| g.length < 2 }
    return self
  end

  # @brief Removes every part the player can't select, keeping the given appearance's part instead.
  # @param player [Player]
  # @param fallback [PlayerAppearance] Supplies the parts kept in place of locked ones.
  # @return [Array<Symbol>] Ids of the locked parts that were removed.
  def strip_locked!(player, fallback)
    locked = @parts.reject { |_slot, id| player.part_selectable?(id) }
    locked.each_key do |slot|
      @parts.delete(slot)
      clear_colors(slot)
      old = fallback.part_for(slot)
      next if !old || !conflicts_with(old.id).empty?
      equip(slot, old.id)
      (1..old.color_slots).each do |r|
        color = fallback.color_for(slot, r)
        @colors[[slot, r]] = color.dup
      end
    end
    sanitize!
    return locked.values
  end

  #----------------------------------------------------------------
  # Share codes
  #----------------------------------------------------------------
  # @brief Packs this appearance into a short code players can share.
  # Ids are stored as CRC32 hashes, so codes stay valid when PBS entries are reordered.
  # @return [String]
  def to_code
    values = [CODE_VERSION]
    worn = CustomizationSettings::SLOT_ORDER.select { |slot| part_for(slot) }
    values.push(worn.length)
    worn.each do |slot|
      part = part_for(slot)
      values.push(CustomizationSettings::SLOT_ORDER.index(slot), *PlayerAppearance.pack_id(part.id), part.color_slots)
      (1..part.color_slots).each do |region|
        color = color_for(slot, region)
        values.push(*PlayerAppearance.pack_id(color.swatch), color.adjust.hue % 360, color.adjust.saturation, color.adjust.value)
      end
    end
    groups = @links.select { |g| g.length > 1 }
    values.push(groups.length)
    groups.each do |g|
      values.push(g.length)
      g.each { |slot, region| values.push(CustomizationSettings::SLOT_ORDER.index(slot), region) }
    end
    return Serializer.pack_code(values)
  end

  # @brief Rebuilds an appearance from a code made by to_code. Never raises.
  # Unknown parts and swatches are skipped; nothing is checked against what the player has unlocked.
  # @param code [String]
  # @return [PlayerAppearance, nil] nil if the code is invalid.
  def self.from_code(code)
    values = Serializer.unpack_code(code)
    return nil if !values || values.shift != CODE_VERSION
    return DevLog.guard("PlayerAppearance.from_code failed") do
      ret = PlayerAppearance.allocate
      ret.instance_variable_set(:@parts, {})
      ret.instance_variable_set(:@colors, {})
      ret.instance_variable_set(:@links, [])
      read = lambda do
        raise "code is truncated" if values.empty?
        next values.shift
      end
      parts = id_lookup(GameData::PlayerPart)
      swatches = id_lookup(GameData::PlayerColor)
      read.call.times do
        slot = CustomizationSettings::SLOT_ORDER[read.call]
        part_id = parts[unpack_id(read.call, read.call)]
        regions = read.call
        colors = Array.new(regions) do
          swatch = swatches[unpack_id(read.call, read.call)]
          next RegionColor.new(swatch, ColorAdjust.new(read.call % 360, read.call.clamp(-100, 100), read.call.clamp(-100, 100)))
        end
        next if !slot || !part_id || !ret.conflicts_with(part_id).empty?
        ret.equip(slot, part_id)
        colors.each_with_index do |color, i|
          ret.colors[[slot, i + 1]] = color if ret.region_exists?(slot, i + 1)
        end
      end
      read.call.times do
        group = Array.new(read.call) { [CustomizationSettings::SLOT_ORDER[read.call], read.call] }
        group.select! { |key| ret.region_exists?(*key) }
        ret.links.push(group.uniq) if group.uniq.length > 1
      end
      raise "code has trailing data" if !values.empty?
      next ret
    end
  end

  # @brief Splits an id's CRC32 into two signed 16-bit values (0, 0 for nil).
  # @param id [Symbol, nil]
  # @return [Array<Integer>]
  def self.pack_id(id)
    return [0, 0] if !id
    crc = Hex.crc32(id.to_s)
    return [(crc >> 16) - 32_768, (crc & 0xFFFF) - 32_768]
  end

  # @brief Reverses pack_id.
  # @return [Integer, nil] The CRC32, or nil for an empty id.
  def self.unpack_id(high, low)
    return nil if high == 0 && low == 0
    return ((high + 32_768) << 16) | (low + 32_768)
  end

  # @param game_data [Class] GameData::PlayerPart or GameData::PlayerColor.
  # @return [Hash{Integer => Symbol}] CRC32 of each id => id.
  def self.id_lookup(game_data)
    ret = {}
    game_data.each { |data| ret[Hex.crc32(data.id.to_s)] = data.id }
    return ret
  end

  private

  # @brief Forgets the colors of a slot's regions.
  # Link groups are kept, so a new part worn in the slot takes the linked color.
  def clear_colors(slot)
    @colors.reject! { |(s, _region), _color| s == slot }
  end
end

#==================================================================
# class Player
#==================================================================
class Player
  # @brief The player's current appearance, created on first use.
  # @return [PlayerAppearance]
  def appearance
    @appearance ||= PlayerAppearance.new
    return @appearance
  end

  # @brief Replaces the player's appearance.
  # @param value [PlayerAppearance]
  def appearance=(value)
    @appearance = value
  end

  # @return [Hash{Symbol => true}] Ids of parts unlocked during play.
  def unlocked_parts
    @unlocked_parts ||= {}
    return @unlocked_parts
  end

  # @brief Checks whether the player may wear a part.
  # @param id [Symbol] Part id.
  # @return [Boolean]
  def part_unlocked?(id)
    part = GameData::PlayerPart.try_get(id)
    return false if !part
    return part.unlocked || unlocked_parts[part.id] == true
  end

  # @brief Checks whether the editor offers a part: unlocked parts only, unless
  # CustomizationSettings::ONLY_UNLOCKED is off or the game is in debug mode.
  # @param id [Symbol] Part id.
  # @return [Boolean]
  def part_selectable?(id)
    return GameData::PlayerPart.exists?(id) if $DEBUG || !CustomizationSettings::ONLY_UNLOCKED
    return part_unlocked?(id)
  end

  # @brief Makes a part available in the editor.
  # @param id [Symbol] Part id.
  # @return [Boolean] false if no such part exists.
  def unlock_part(id)
    part = GameData::PlayerPart.try_get(id)
    return false if !part
    unlocked_parts[part.id] = true
    return true
  end

  # @brief Makes a part unavailable again (a part being worn stays worn).
  # @param id [Symbol] Part id.
  def lock_part(id)
    unlocked_parts.delete(id)
  end
end

#==================================================================
# Script helpers
#==================================================================
# @brief Unlocks a part for the player (for use in events, shops and rewards).
# @param id [Symbol] Part id.
# @return [Boolean] false if no such part exists.
def pbUnlockPlayerPart(id)
  return $player.unlock_part(id)
end

# @brief Checks whether the player has unlocked a part (for use in event conditions).
# @param id [Symbol] Part id.
# @return [Boolean]
def pbPlayerPartUnlocked?(id)
  return $player.part_unlocked?(id)
end

# @brief Checks whether the player is wearing a part (for use in event conditions).
# @param id [Symbol] Part id.
# @return [Boolean]
def pbPlayerWearing?(id)
  return $player.appearance.worn_parts.any? { |part| part.id == id }
end
