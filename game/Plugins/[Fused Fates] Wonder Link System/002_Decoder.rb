#================================================================================================
# Pokémon Fused Fates Wonder Link System - 002_Decoder.rb
#================================================================================================
require 'zlib'

#==================================================================
# module WonderLink
#==================================================================
# @brief Reading codes back: unpacking, legality checks and rebuilding Pokémon.
module WonderLink
  #==================================================================
  # class ByteReader
  #==================================================================
  # @brief Reads values written by ByteWriter, raising InvalidCode instead of reading past the end.
  class ByteReader
    # @param data [String] Binary data.
    def initialize(data)
      @data = data.b
      @pos  = 0
    end

    # @brief Whether every byte has been read.
    # @return [Boolean]
    def eof?
      return @pos >= @data.bytesize
    end

    # @brief Reads raw bytes.
    # @param count [Integer]
    # @return [String]
    # @raise [InvalidCode] If fewer bytes are left.
    def bytes(count)
      raise InvalidCode, "code ends early" if @pos + count > @data.bytesize
      ret = @data.byteslice(@pos, count)
      @pos += count
      return ret
    end

    # @return [Integer]
    def u8;  return bytes(1).unpack1("C"); end

    # @return [Integer]
    def u16; return bytes(2).unpack1("n"); end

    # @return [Integer]
    def u32; return bytes(4).unpack1("N"); end

    # @return [Boolean]
    def bool; return u8 != 0; end

    # @brief Reads a length-prefixed UTF-8 string.
    # @return [String]
    # @raise [InvalidCode] If the text isn't valid UTF-8.
    def str
      ret = bytes(u8).force_encoding(Encoding::UTF_8)
      raise InvalidCode, "text is not valid UTF-8" if !ret.valid_encoding?
      return ret
    end

    # @brief Reads an ID written with ByteWriter#sym.
    # @return [Symbol, nil] nil for an empty name.
    # @raise [InvalidCode] If the name has characters IDs never use.
    def sym
      name = str
      return nil if name.empty?
      raise InvalidCode, "bad ID #{name.inspect}" if name !~ /\A[A-Za-z0-9_]+\z/
      return name.to_sym
    end
  end

  module_function

  #----------------------------------------------------------------
  # Decode
  #----------------------------------------------------------------
  # @brief Decodes a code. Never raises.
  # @param code [String]
  # @return [Hash, nil] The decoded code (see decode!), or nil if it is invalid.
  def decode(code)
    return decode!(code)
  rescue InvalidCode => e
    DevLog.info("Wonder Link: rejected code (#{e.message})")
    return nil
  rescue StandardError => e
    DevLog.warn("Wonder Link: error while decoding a code: #{e.class}: #{e.message}")
    return nil
  end

  # @brief Decodes and checks a code.
  # @param code [String]
  # @return [Hash] { type:, digest:, owner: { name:, id:, gender:, trainer_type: }, and then
  #   party: [records], signature: [species] for profile codes, or
  #   nonce:, pokemon: record for trade and gift codes }
  # @raise [InvalidCode] With a reason the player can be shown (see #reason_text).
  def decode!(code)
    text = code.to_s.gsub(/\s+/, "")
    raise InvalidCode, "empty" if text.empty?
    raise InvalidCode, "too long" if text.length > WonderLinkSettings::MAX_CODE_LENGTH
    raise InvalidCode, "not a code" if !text.start_with?(WonderLinkSettings::CODE_PREFIX)
    text = text[WonderLinkSettings::CODE_PREFIX.length..]
    begin
      compressed = Base64.urlsafe_decode64(text)
      body = Zlib::Inflate.inflate(compressed).b
    rescue ArgumentError, Zlib::Error
      raise InvalidCode, "damaged"
    end
    raise InvalidCode, "damaged" if body.bytesize < MAGIC.bytesize + 6
    raise InvalidCode, "not a code" if body.byteslice(0, MAGIC.bytesize) != MAGIC
    signed = body.byteslice(0, body.bytesize - 4)
    raise InvalidCode, "damaged" if body.byteslice(-4, 4).unpack1("N") != signature(signed)
    r = ByteReader.new(signed.byteslice(MAGIC.bytesize, signed.bytesize - MAGIC.bytesize))
    version = r.u8
    raise InvalidCode, "version" if version != WonderLinkSettings::CODE_VERSION
    type = TYPES.key(r.u8)
    raise InvalidCode, "unknown type" if !type
    ret = { type: type, digest: format("%08x", Zlib.crc32(signed)), owner: read_owner(r) }
    if type == :party
      count = r.u8
      raise InvalidCode, "bad party size" if count < 1 || count > Settings::MAX_PARTY_SIZE
      ret[:party] = Array.new(count) { read_pokemon(r) }
      ret[:signature] = Array.new(r.u8) { r.sym }.compact
    else
      ret[:nonce]   = r.u32
      ret[:pokemon] = read_pokemon(r)
    end
    raise InvalidCode, "extra data" if !r.eof?
    Legality.check_code!(ret)
    return ret
  end

  # @brief Player-facing explanation for an InvalidCode reason.
  # @param reason [String] InvalidCode#message.
  # @return [String]
  def reason_text(reason)
    case reason
    when "empty"      then return _INTL("There's no Wonder Link code to read!")
    when "not a code" then return _INTL("That isn't a Wonder Link code.")
    when "version"    then return _INTL("That Wonder Link code is from a different version of the game.")
    when "too long", "damaged", "code ends early", "extra data"
      return _INTL("That Wonder Link code is incomplete or damaged. Try copying it again.")
    end
    return _INTL("That Wonder Link code contains a Pokémon that can't exist in this game.") if reason.start_with?("illegal")
    return _INTL("That Wonder Link code couldn't be read.")
  end

  # @brief Reads the sharer's identity written by write_owner.
  # @param r [ByteReader]
  # @return [Hash]
  def read_owner(r)
    return { name: r.str, id: r.u32, gender: r.u8, trainer_type: r.sym }
  end

  # @brief Reads a record written by write_pokemon.
  # @param r [ByteReader]
  # @return [Hash] Same keys as pokemon_record.
  def read_pokemon(r)
    flags = r.u8
    rec = {}
    rec[:species]       = r.sym
    rec[:form]          = r.u8
    rec[:level]         = r.u8
    rec[:item]          = r.sym
    rec[:nature]        = r.sym
    rec[:ability]       = r.sym
    rec[:ability_index] = r.u8
    rec[:gender]        = r.u8
    rec[:happiness]     = r.u8
    rec[:ball]          = r.sym
    rec[:personal_id]   = r.u32
    rec[:ot_name]       = r.str
    rec[:ot_id]         = r.u32
    rec[:ot_gender]     = r.u8
    rec[:shiny]         = (flags & FLAG_SHINY) != 0
    rec[:super_shiny]   = (flags & FLAG_SUPER_SHINY) != 0
    rec[:nickname]      = ((flags & FLAG_NICKNAMED) != 0) ? r.str : nil
    rec[:moves]         = Array.new(r.u8) { [r.sym, r.u8] }
    rec[:iv]            = Array.new(STAT_IDS.length) { r.u8 }
    rec[:ev]            = Array.new(STAT_IDS.length) { r.u8 }
    rec[:ribbons]       = Array.new(r.u8) { r.sym }
    rec[:fusion]        = nil
    if (flags & FLAG_FUSED) != 0
      rec[:fusion] = {
        head: r.sym, head_form: r.u8, body: r.sym, body_form: r.u8,
        head_ability: r.sym, body_ability: r.sym
      }
    end
    return rec
  end

  #----------------------------------------------------------------
  # Rebuilding Pokémon
  #----------------------------------------------------------------
  # @brief Creates a Pokémon from a checked record.
  # @param rec [Hash] A record that passed Legality.check.
  # @return [Pokemon] A Pokemon, or a FusedPokemon for fusions. Fully healed.
  def build_pokemon(rec)
    if rec[:fusion]
      pkmn = build_fusion(rec)
    else
      pkmn = Pokemon.new(rec[:species], rec[:level], $player, false)
      pkmn.form_simple = rec[:form] if rec[:form] > 0
    end
    pkmn.personalID    = rec[:personal_id]
    pkmn.owner         = Pokemon::Owner.new(rec[:ot_id], rec[:ot_name], rec[:ot_gender], 2)
    pkmn.item          = rec[:item]
    pkmn.nature        = rec[:nature]
    pkmn.ability_index = rec[:ability_index]
    apply_ability(pkmn, rec)
    pkmn.gender        = rec[:gender]
    pkmn.shiny         = rec[:shiny]
    pkmn.super_shiny   = rec[:super_shiny] if rec[:super_shiny]
    pkmn.happiness     = rec[:happiness]
    pkmn.poke_ball     = rec[:ball]
    pkmn.name          = rec[:nickname] if rec[:nickname]
    pkmn.moves = rec[:moves].map do |move_id, ppup|
      move = Pokemon::Move.new(move_id)
      move.ppup = ppup
      move.pp   = move.total_pp
      next move
    end
    STAT_IDS.each_with_index do |stat, i|
      pkmn.iv[stat] = rec[:iv][i]
      pkmn.ev[stat] = rec[:ev][i]
    end
    pkmn.ribbons = rec[:ribbons].dup
    pkmn.calc_stats
    pkmn.heal
    return pkmn
  end

  # @brief Creates the FusedPokemon for a fusion record, the same way trainers.txt fusions are made.
  # @param rec [Hash]
  # @return [FusedPokemon]
  def build_fusion(rec)
    f = rec[:fusion]
    pkmn = FusedPokemon.new(f[:head], rec[:level], f[:head], f[:body])
    pkmn.fusion_head        = f[:head]
    pkmn.fusion_body        = f[:body]
    pkmn.original_head_data = GameData::Species.get_species_form(f[:head], f[:head_form])
    pkmn.original_body_data = GameData::Species.get_species_form(f[:body], f[:body_form])
    pkmn.instance_variable_set(:@form, f[:head_form])
    pkmn.invalidate_fusion_caches
    return pkmn
  end

  # @brief Gives a rebuilt Pokémon the exact ability it had in the sharer's game.
  # @param pkmn [Pokemon]
  # @param rec [Hash]
  def apply_ability(pkmn, rec)
    if rec[:fusion]
      f = rec[:fusion]
      if f[:head_ability] && f[:body_ability] && rec[:ability] == Legality.combo_ability(f)
        FusedAbilities.register_combo(f[:head_ability], f[:body_ability])
      end
      pkmn.ability_override = rec[:ability]
    else
      pkmn.ability = rec[:ability] if rec[:ability] != pkmn.ability_id
    end
  end

  # @brief Decodes a profile code into ready-to-battle Pokémon.
  # @param decoded [Hash] A decoded :party code.
  # @return [Array<Pokemon>]
  def import_party(decoded)
    return decoded[:party].map { |rec| build_pokemon(rec) }
  end

  #----------------------------------------------------------------
  # Reading codes from the player
  #----------------------------------------------------------------
  # @brief Gets a code from the player: the clipboard if it holds one, otherwise typed text.
  # @param prompt [String, nil] Message shown first.
  # @return [String, nil] The code text, or nil if the player cancelled.
  def read_code_input(prompt = nil)
    pbMessage(prompt) if prompt
    clip = read_clipboard
    if clip && clip.gsub(/\s+/, "").start_with?(WonderLinkSettings::CODE_PREFIX)
      return clip if pbConfirmMessage(_INTL("A Wonder Link code was found on your clipboard. Use it?"))
    end
    text = pbMessageFreeText(_INTL("Enter a Wonder Link code."), "", false,
                             WonderLinkSettings::MAX_CODE_LENGTH, Graphics.width)
    return nil if !text || text.strip.empty?
    return text.strip
  end

  # @brief Gets and decodes a code from the player, explaining any problem.
  # @param prompt [String, nil] Message shown first.
  # @param types [Array<Symbol>, nil] Code types allowed here; nil allows any.
  # @return [Hash, nil] The decoded code with the code text added as :code, or nil if
  #   cancelled or invalid.
  def ask_for_code(prompt = nil, types = nil)
    text = read_code_input(prompt)
    return nil if !text
    begin
      decoded = decode!(text)
    rescue InvalidCode => e
      DevLog.info("Wonder Link: rejected code (#{e.message})")
      pbMessage(reason_text(e.message))
      return nil
    end
    if types && !types.include?(decoded[:type])
      pbMessage(wrong_type_text(decoded[:type]))
      return nil
    end
    if !WonderLinkSettings::ALLOW_OWN_CODES && decoded[:owner][:id] == $player.id
      pbMessage(_INTL("That's your own Wonder Link code! Share it with someone else instead."))
      return nil
    end
    decoded[:code] = text
    return decoded
  end

  # @brief Message for a code used in the wrong place.
  # @param type [Symbol] The code's actual type.
  # @return [String]
  def wrong_type_text(type)
    case type
    when :trade then return _INTL("That's a trade code. It can be redeemed at a Wonder Link trade terminal.")
    when :gift  then return _INTL("That's a gift code. It can be redeemed at a Wonder Link gift terminal.")
    end
    return _INTL("That's a trainer's Wonder Link code, not a trade or gift code.")
  end

  # @brief Reads text from the system clipboard where the engine supports it.
  # @return [String, nil]
  def read_clipboard
    return nil if !Input.respond_to?(:clipboard)
    return DevLog.guard("Wonder Link: could not read the clipboard") { Input.clipboard.to_s.strip }
  end

  #==================================================================
  # module Legality
  #==================================================================
  # @brief Rejects codes holding Pokémon that couldn't legitimately exist in this game.
  module Legality
    module_function

    # @brief Checks every Pokémon and the Safari species in a decoded code.
    # @param decoded [Hash]
    # @raise [InvalidCode] "illegal: <reason>" for the first problem found.
    def check_code!(decoded)
      list = (decoded[:type] == :party) ? decoded[:party] : [decoded[:pokemon]]
      list.each do |rec|
        problem = check(rec)
        raise InvalidCode, "illegal: #{problem}" if problem
      end
      (decoded[:signature] || []).each do |species|
        # Unknown Safari species are only ignored, so codes from games with other pools still work
        next if GameData::Species.exists?(species)
        DevLog.info("Wonder Link: ignoring unknown Safari species #{species}")
      end
      decoded[:signature]&.select! { |species| GameData::Species.exists?(species) }
      name = decoded[:owner][:name]
      raise InvalidCode, "illegal: owner name" if name.length > 32 || name =~ /[\x00-\x1F]/
    end

    # @brief Checks one record.
    # @param rec [Hash] As returned by read_pokemon.
    # @return [String, nil] What is wrong, or nil if the record is legal.
    def check(rec)
      species = species_form(rec[:species], rec[:form])
      return "species #{rec[:species]} form #{rec[:form]}" if !species
      return "level #{rec[:level]}" if !rec[:level].between?(1, Settings::MAXIMUM_LEVEL)
      return "item #{rec[:item]}" if rec[:item] && !GameData::Item.exists?(rec[:item])
      return "nature #{rec[:nature]}" if !rec[:nature] || !GameData::Nature.exists?(rec[:nature])
      return "ball #{rec[:ball]}" if !rec[:ball] || !GameData::Item.exists?(rec[:ball]) ||
                                     !GameData::Item.get(rec[:ball]).is_poke_ball?
      return "gender #{rec[:gender]}" if rec[:gender] > 2
      return "IVs" if rec[:iv].any? { |v| v > Pokemon::IV_STAT_LIMIT }
      return "EVs" if rec[:ev].any? { |v| v > Pokemon::EV_STAT_LIMIT } || rec[:ev].sum > Pokemon::EV_LIMIT
      problem = check_moves(rec[:moves])
      return problem if problem
      return "ribbons" if rec[:ribbons].any? { |r| !r || !GameData::Ribbon.exists?(r) } ||
                          rec[:ribbons].uniq.length != rec[:ribbons].length
      return "nickname" if rec[:nickname] && (rec[:nickname].length > Pokemon::MAX_NAME_SIZE ||
                                              rec[:nickname] =~ /[\x00-\x1F]/)
      return "OT name" if rec[:ot_name].length > 32 || rec[:ot_name] =~ /[\x00-\x1F]/
      return check_fusion(rec, species) if rec[:fusion]
      return check_ability(rec, species)
    end

    # @brief Form-specific species data, if the species and form both exist.
    # @param species [Symbol, nil]
    # @param form [Integer]
    # @return [GameData::Species, nil]
    def species_form(species, form)
      return nil if !species || !GameData::Species.exists?(species)
      return nil if GameData::Species.get(species).form != 0   # Must be a base species ID
      data = GameData::Species.get_species_form(species, form)
      return (data && data.form == form) ? data : nil
    end

    # @param moves [Array<Array(Symbol, Integer)>] [move ID, PP Ups] pairs.
    # @return [String, nil] What is wrong, or nil.
    def check_moves(moves)
      return "no moves" if moves.empty?
      return "too many moves" if moves.length > Pokemon::MAX_MOVES
      return "duplicate moves" if moves.map(&:first).uniq.length != moves.length
      moves.each do |move, ppup|
        return "move #{move}" if !move || !GameData::Move.exists?(move)
        return "PP Ups" if ppup > 3
      end
      return nil
    end

    # @brief Abilities a species form can have, natural and hidden.
    # @param data [GameData::Species]
    # @return [Array<Symbol>]
    def abilities_of(data)
      return (data.abilities + data.hidden_abilities).compact
    end

    # @param rec [Hash]
    # @param data [GameData::Species]
    # @return [String, nil] What is wrong, or nil.
    def check_ability(rec, data)
      return "ability index" if rec[:ability_index] > 1 + data.hidden_abilities.length
      return "ability #{rec[:ability]}" if !rec[:ability] || !abilities_of(data).include?(rec[:ability])
      return nil
    end

    # @brief The "As One" ability ID a fusion's two component abilities combine into.
    # @param fusion [Hash] The record's :fusion hash.
    # @return [Symbol]
    def combo_ability(fusion)
      return :"ASONE_#{fusion[:head_ability]}_#{fusion[:body_ability]}"
    end

    # @param rec [Hash]
    # @param head [GameData::Species] Head form data (also the record's species).
    # @return [String, nil] What is wrong, or nil.
    def check_fusion(rec, head)
      return "fusions aren't supported" if !defined?(FusedPokemon)
      f = rec[:fusion]
      return "fusion head" if f[:head] != rec[:species] || f[:head_form] != rec[:form]
      body = species_form(f[:body], f[:body_form])
      return "fusion body #{f[:body]}" if !body
      restricted = FusionSettings::RESTRICTED_ALT_FORMS
      return "fusion form" if (restricted.include?(f[:head]) && f[:head_form] > 0) ||
                              (restricted.include?(f[:body]) && f[:body_form] > 0)
      return "head ability" if f[:head_ability] && !abilities_of(head).include?(f[:head_ability])
      return "body ability" if f[:body_ability] && !abilities_of(body).include?(f[:body_ability])
      allowed = abilities_of(head) + abilities_of(body)
      allowed.push(combo_ability(f)) if f[:head_ability] && f[:body_ability]
      return "ability #{rec[:ability]}" if !rec[:ability] || !allowed.include?(rec[:ability])
      return nil
    end
  end
end
