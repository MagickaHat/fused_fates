#================================================================================================
# Pokémon Fused Fates Utilities/Encoding - 001_Base64.rb
#================================================================================================

#==================================================================
# module Base64
#==================================================================
# @brief Base64 encoding compatible with Ruby's standard library module (absent in mkxp-z).
module Base64
  # @brief Encodes binary data with a newline every 60 characters (RFC 2045).
  # @param bin [String]
  # @return [String]
  def self.encode64(bin)
    [bin].pack("m")
  end

  # @brief Decodes data made by encode64, ignoring newlines and other non-alphabet characters.
  # @param str [String]
  # @return [String] Binary data.
  def self.decode64(str)
    str.unpack1("m")
  end

  # @brief Encodes binary data on a single line with no newlines (RFC 4648).
  # @param bin [String]
  # @return [String]
  def self.strict_encode64(bin)
    [bin].pack("m0")
  end

  # @brief Decodes data made by strict_encode64.
  # @param str [String]
  # @return [String] Binary data.
  # @raise [ArgumentError] If str is not valid strict Base64.
  def self.strict_decode64(str)
    str.unpack1("m0")
  end

  # @brief Encodes binary data with the URL/filename-safe alphabet ("-" and "_" instead of "+" and "/").
  # @param bin [String]
  # @param padding [Boolean] Whether to keep trailing "=" characters.
  # @return [String]
  def self.urlsafe_encode64(bin, padding: true)
    str = strict_encode64(bin).tr("+/", "-_")
    str.delete!("=") if !padding
    return str
  end

  # @brief Decodes data made by urlsafe_encode64, with or without padding.
  # @param str [String]
  # @return [String] Binary data.
  # @raise [ArgumentError] If str is not valid Base64.
  def self.urlsafe_decode64(str)
    str = str.tr("-_", "+/")
    str += "=" * ((4 - (str.length % 4)) % 4) if !str.end_with?("=")
    return strict_decode64(str)
  end
end
