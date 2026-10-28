#================================================================================================
# Pokémon Fused Fates Utilities/Encoding - 002_Hex.rb
#================================================================================================

#==================================================================
# module Hex
#==================================================================
# @brief Hexadecimal encoding and checksums.
module Hex
  module_function

  # @brief Encodes binary data as lowercase hex.
  # @param bin [String]
  # @return [String]
  def encode(bin)
    return bin.unpack1("H*")
  end

  # @brief Decodes hex (either case) back to binary data.
  # @param str [String]
  # @return [String]
  # @raise [ArgumentError] If str contains non-hex characters or has an odd length.
  def decode(str)
    raise ArgumentError, "invalid hex string" if str.length.odd? || str =~ /[^0-9a-fA-F]/
    return [str].pack("H*")
  end

  # @brief CRC32 checksum of a string.
  # @param str [String]
  # @return [Integer]
  def crc32(str)
    return Zlib.crc32(str)
  end
end

#==================================================================
# class Color
#==================================================================
class Color
  # @brief Formats the color as "#RRGGBB", or "#RRGGBBAA" if it is translucent.
  # @param include_alpha [Boolean] Always add the alpha byte.
  # @return [String]
  def to_hex(include_alpha = false)
    ret = format("#%02X%02X%02X", self.red.to_i, self.green.to_i, self.blue.to_i)
    ret += format("%02X", self.alpha.to_i) if include_alpha || self.alpha.to_i < 255
    return ret
  end

  # @brief Parses "#RGB", "#RRGGBB" or "#RRGGBBAA" (the "#" is optional).
  # @param str [String]
  # @return [Color]
  # @raise [ArgumentError] If str is not a hex color.
  def self.from_hex(str)
    hex = str.to_s.delete_prefix("#")
    hex = hex.chars.map { |c| c * 2 }.join if hex.length == 3
    raise ArgumentError, "invalid hex color: #{str}" if ![6, 8].include?(hex.length) || hex =~ /[^0-9a-fA-F]/
    values = hex.scan(/../).map { |pair| pair.to_i(16) }
    return Color.new(values[0], values[1], values[2], values[3] || 255)
  end
end
