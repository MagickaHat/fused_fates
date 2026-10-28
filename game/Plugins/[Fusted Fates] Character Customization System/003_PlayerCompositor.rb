#================================================================================================
# Pokémon Fused Fates Fusion System - 003_PlayerCompositor.rb
#================================================================================================

#==================================================================
# module PlayerCompositor
#==================================================================
module PlayerCompositor
  ROOT = "Graphics/Characters/Custom/"
  SLOT_ORDER = [:Body, :Eyes, :Bottom, :Shoes, :Top, :Hair, :Hat, :Accessory]
  @cache = {}

  # @brief Returns the composited bitmap for a sprite context, building it is needed.
  # @param context [String] e.g. "walk", "surf", "front".
  # @return [Bitmap]
  def self.bitmap_for(context)
    @cache[context] = compose(context, $player.appearance) if !@cache[context] || @cache[context].disposed?
    return @cache[context]
  end
  
  # @brief Discards cached bitmaps; call after any appearance change.
  def self.refresh
    @cache.each_value { |bmp| bmp.dispose unless bmp.disposed? }
    @cache.clear
  end

  # @brief Stacks every equipped part into one bitmap.
  # @param context [String] Sprite context subfolder.
  # @param appearance [PlayerAppearance] The choices to render.
  # @return [Bitmap]
  def self.compose(context, appearance)
    parts = SLOT_ORDER.filter_map { |slot| appearance.part_for(slot) }
    body = Bitmap.new(ROOT + "#{context}/#{parts.first.graphic}_1")
    canvas = Bitmap.new(body.width, body.height)
    parts.each { |part| draw_part(canvas, context, part, appearance, "_back") }
    parts.each { |part| draw_part(canvas, context, part, appearance, "") }
    return canvas 
  end
end