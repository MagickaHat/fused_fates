#================================================================================================
# Pokémon Fused Fates Utilities/Encoding - 003_Serializer.rb
#================================================================================================

#==================================================================
# module Serializer
#==================================================================
# @brief Turns Ruby objects, integer lists and bitmaps into compact, checksummed strings.
#
# dump/load use Marshal, which can rebuild any object, so only load strings this game wrote
# itself (save data, caches, debug exports). Strings players paste in or share should use
# pack_code/unpack_code, which can only ever produce a list of integers.
module Serializer
  # Format version written in the header of dump strings
  VERSION = 1

  # Header flag: the payload is Zlib-compressed
  FLAG_COMPRESSED = 1

  module_function

  # @brief Serializes an object to a URL-safe string.
  # @param obj [Object] Anything Marshal can dump.
  # @param compress [Boolean] Deflate the data first (smaller for anything but tiny objects).
  # @return [String]
  def dump(obj, compress: true)
    data = Marshal.dump(obj)
    flags = 0
    if compress
      data = Zlib::Deflate.deflate(data)
      flags |= FLAG_COMPRESSED
    end
    header = [VERSION, flags, Zlib.crc32(data)].pack("CCN")
    return Base64.urlsafe_encode64(header + data, padding: false)
  end

  # @brief Restores an object made by dump. Never raises.
  # @param str [String]
  # @param fallback [Object] Returned if str is corrupt, from another version or not a dump string.
  # @return [Object]
  def load(str, fallback = nil)
    return DevLog.guard("Serializer.load failed", fallback) do
      payload = Base64.urlsafe_decode64(str.to_s.strip)
      raise "data is too short" if payload.bytesize < 6
      version, flags, crc = payload.unpack("CCN")
      raise "unsupported version #{version}" if version != VERSION
      data = payload.byteslice(6, payload.bytesize - 6)
      raise "checksum mismatch" if Zlib.crc32(data) != crc
      data = Zlib::Inflate.inflate(data) if (flags & FLAG_COMPRESSED) != 0
      next Marshal.load(data)
    end
  end

  # @brief Packs a list of integers into a short, checksummed, URL-safe code.
  # Safe to show to and accept from players (e.g. sharing a recolor).
  # @param values [Array<Integer>] Each from -32768 to 32767.
  # @return [String]
  def pack_code(values)
    data = values.map { |v| v.to_i.clamp(-32_768, 32_767) }.pack("s>*")
    return Base64.urlsafe_encode64([Zlib.crc32(data) & 0xFF].pack("C") + data, padding: false)
  end

  # @brief Unpacks a code made by pack_code. Never raises.
  # @param code [String]
  # @return [Array<Integer>, nil] nil if the code is invalid.
  def unpack_code(code)
    return DevLog.guard("Serializer.unpack_code failed") do
      payload = Base64.urlsafe_decode64(code.to_s.strip)
      next nil if payload.empty? || payload.bytesize.even?   # 1 checksum byte + 2 per value
      data = payload.byteslice(1, payload.bytesize - 1)
      next nil if (Zlib.crc32(data) & 0xFF) != payload.getbyte(0)
      next data.unpack("s>*")
    end
  end

  # @brief Serializes a bitmap's pixels (e.g. to cache a generated sprite on disk).
  # @param bitmap [Bitmap]
  # @return [String] Binary data; wrap it in Base64 if it must be text.
  def bitmap_to_string(bitmap)
    pixels = Pixels.read(bitmap).pack("C*")
    return [bitmap.width, bitmap.height].pack("NN") + Zlib::Deflate.deflate(pixels)
  end

  # @brief Rebuilds a bitmap made by bitmap_to_string.
  # @param str [String]
  # @param klass [Class] Bitmap class to create (BitmapWrapper for use with RPG::Cache-style ref counting).
  # @return [Bitmap, nil] nil if str is corrupt.
  def string_to_bitmap(str, klass = Bitmap)
    return DevLog.guard("Serializer.string_to_bitmap failed") do
      width, height = str.unpack("NN")
      pixels = Zlib::Inflate.inflate(str.byteslice(8, str.bytesize - 8)).unpack("C*")
      raise "pixel data does not match size #{width}x#{height}" if pixels.length != width * height * 4
      bitmap = klass.new(width, height)
      Pixels.write(bitmap, pixels)
      next bitmap
    end
  end
end
