#================================================================================================
# Pokémon Fused Fates Utilities/Graphics - 005_BitmapLRU.rb
#================================================================================================

#==================================================================
# class BitmapLRU
#==================================================================
# @brief A least-recently-used cache of ref-counted bitmaps (BitmapWrapper).
# The cache holds one reference to each bitmap and fetch adds one for the caller, who
# releases it with dispose as usual. When the cache is over capacity it drops its reference
# to the oldest bitmaps; a bitmap still on screen stays alive until its last user disposes it.
class BitmapLRU
  attr_reader :hits, :misses

  # @brief Creates a cache.
  # @param capacity [Integer, nil] Fixed capacity. Pass a block instead to read it each time
  #   (e.g. { FusionSettings::SPRITE_CACHE_SIZE }), so changing a setting takes effect live.
  def initialize(capacity = nil, &capacity_proc)
    @capacity      = capacity
    @capacity_proc = capacity_proc
    @entries       = {}   # Key => BitmapWrapper (oldest first)
    @hits          = 0
    @misses        = 0
  end

  # @return [Integer] Most bitmaps kept once nothing else uses them.
  def capacity
    return [(@capacity_proc ? @capacity_proc.call : @capacity).to_i, 0].max
  end

  # @brief Returns the cached bitmap for a key, building it with the block if needed.
  # A reference is added for the caller, who releases it with dispose.
  # @param key [Object]
  # @yieldreturn [BitmapWrapper, nil] A newly built bitmap, or nil if it can't be made.
  # @return [BitmapWrapper, nil]
  def fetch(key)
    bmp = @entries.delete(key)
    bmp = nil if bmp&.disposed?
    if bmp
      @hits += 1
    else
      @misses += 1
      bmp = yield
      return nil if !bmp
    end
    @entries[key] = bmp   # Re-inserting marks it as the most recently used
    bmp.addRef
    trim
    return bmp
  end

  # @param key [Object]
  # @return [Boolean] Whether a live bitmap is cached for the key.
  def include?(key)
    bmp = @entries[key]
    return !bmp.nil? && !bmp.disposed?
  end

  # @brief Drops the cache's reference to one bitmap.
  # @param key [Object]
  def delete(key)
    bmp = @entries.delete(key)
    bmp.dispose if bmp && !bmp.disposed?
  end

  # @brief Drops the oldest bitmaps beyond capacity.
  def trim
    while @entries.length > capacity
      _key, old = @entries.shift
      old.dispose if old && !old.disposed?
    end
  end

  # @brief Drops every bitmap and resets the statistics.
  def clear
    @entries.each_value { |bmp| bmp.dispose if !bmp.disposed? }
    @entries.clear
    @hits = 0
    @misses = 0
  end

  # @return [Integer] Number of cached bitmaps.
  def size
    return @entries.length
  end

  # @return [Hash] :size, :capacity, :hits and :misses.
  def stats
    return { size: size, capacity: capacity, hits: @hits, misses: @misses }
  end
end
