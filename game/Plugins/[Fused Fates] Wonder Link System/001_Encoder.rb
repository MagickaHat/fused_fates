#================================================================================================
# Pokémon Fused Fates Wonder Link System - 001_Encoder.rb
#================================================================================================
require 'zlib'

#==================================================================
# module WonderLink
#==================================================================
# @brief Wonder Link codes: shareable text that carries a player's party or a single Pokémon
# into someone else's game.
#
# Code layout (before compression and Base64):
#   "WL" magic, version (u8), type (u8), payload, signature (u32)
# The signature is a CRC32 of CODE_SALT + everything before it, so damaged or hand-edited codes
# are rejected. The whole thing is deflated and written as URL-safe Base64 after CODE_PREFIX.
#
# Every ID (species, move, item...) is written by name rather than by index, so codes keep
# working after PBS files change. Payloads only ever contain integers and strings, never
# Marshal data, so a code can't create arbitrary objects in the redeemer's game.
module WonderLink
  include WonderLinkSettings

  # @brief Raised for any code that can't be read. Callers outside this module see nil instead.
  class InvalidCode < StandardError; end

  # Magic bytes at the start of every decoded code
  MAGIC = "WL".b.freeze

  # Code type byte values
  TYPES = { party: 1, trade: 2, gift: 3 }.freeze

  # Order IVs and EVs are written in
  STAT_IDS = [:HP, :ATTACK, :DEFENSE, :SPECIAL_ATTACK, :SPECIAL_DEFENSE, :SPEED].freeze

  # Bit flags at the start of every Pokémon record
  FLAG_FUSED       = 0x01
  FLAG_SHINY       = 0x02
  FLAG_SUPER_SHINY = 0x04
  FLAG_NICKNAMED   = 0x08

  #==================================================================
  # class ByteWriter
  #==================================================================
  # @brief Appends big-endian integers and length-prefixed strings to a binary string.
  class ByteWriter
    # @return [String] Binary data written so far.
    attr_reader :data

    def initialize
      @data = "".b
    end

    # @brief Writes an unsigned byte (values are clamped to 0-255).
    # @param value [Integer]
    def u8(value)
      @data << [value.to_i.clamp(0, 0xFF)].pack("C")
    end

    # @brief Writes an unsigned 16-bit integer (clamped).
    # @param value [Integer]
    def u16(value)
      @data << [value.to_i.clamp(0, 0xFFFF)].pack("n")
    end

    # @brief Writes an unsigned 32-bit integer (wrapped to 32 bits).
    # @param value [Integer]
    def u32(value)
      @data << [value.to_i & 0xFFFF_FFFF].pack("N")
    end

    # @brief Writes a boolean as one byte.
    # @param value [Boolean]
    def bool(value)
      u8(value ? 1 : 0)
    end

    # @brief Writes a UTF-8 string with a one-byte length (truncated to 255 bytes).
    # @param value [String, nil] nil is written as an empty string.
    def str(value)
      bytes = value.to_s.dup.force_encoding(Encoding::UTF_8).b
      bytes = bytes.byteslice(0, 255)
      u8(bytes.bytesize)
      @data << bytes
    end

    # @brief Writes an ID symbol by name. nil is written as an empty name.
    # @param value [Symbol, String, nil]
    def sym(value)
      str(value.nil? ? "" : value.to_s)
    end
  end

  module_function

  #----------------------------------------------------------------
  # Encode
  #----------------------------------------------------------------
  # @brief Wraps a payload into a finished, signed and compressed code.
  # @param type [Symbol] :party, :trade or :gift
  # @param payload [String] Binary data written with a ByteWriter.
  # @return [String] The shareable code.
  def encode(type, payload)
    raise ArgumentError, "unknown Wonder Link code type #{type}" if !TYPES[type]
    body = MAGIC + [CODE_VERSION, TYPES[type]].pack("CC") + payload.b
    body << [signature(body)].pack("N")
    compressed = Zlib::Deflate.deflate(body, Zlib::BEST_COMPRESSION)
    return CODE_PREFIX + Base64.urlsafe_encode64(compressed, padding: false)
  end

  # @brief Signature stored at the end of each code.
  # @param body [String] Everything before the signature.
  # @return [Integer]
  def signature(body)
    return Zlib.crc32(CODE_SALT.b + body.b)
  end

  # @brief Builds a profile code for a trainer.
  # @param trainer [Player] Usually $player.
  # @param signature_species [Array<Symbol>] The trainer's Safari species.
  # @return [String] The code.
  # @raise [ArgumentError] If the party has no Pokémon that can be shared.
  def party_code(trainer = $player, signature_species = nil)
    party = trainer.party.reject { |pkmn| !shareable?(pkmn) }
    raise ArgumentError, "no shareable Pokémon in the party" if party.empty?
    signature_species ||= WonderLink::Safari.signature
    w = ByteWriter.new
    write_owner(w, trainer)
    w.u8(party.length)
    party.each { |pkmn| write_pokemon(w, pokemon_record(pkmn)) }
    w.u8(signature_species.length)
    signature_species.each { |species| w.sym(species) }
    return encode(:party, w.data)
  end

  # @brief Builds a trade or gift code for one Pokémon.
  # @param type [Symbol] :trade or :gift
  # @param pkmn [Pokemon]
  # @param trainer [Player] The sharer, usually $player.
  # @return [String] The code.
  # @raise [ArgumentError] If the Pokémon can't be shared.
  def single_code(type, pkmn, trainer = $player)
    raise ArgumentError, "type must be :trade or :gift" if ![:trade, :gift].include?(type)
    raise ArgumentError, "#{pkmn&.name} can't be shared" if !shareable?(pkmn)
    w = ByteWriter.new
    write_owner(w, trainer)
    # A random number makes every trade/gift code unique, so each can be redeemed once
    w.u32(rand(2**32))
    write_pokemon(w, pokemon_record(pkmn))
    return encode(type, w.data)
  end

  # @brief Whether a Pokémon can be put into a code.
  # @param pkmn [Pokemon, nil]
  # @return [Boolean]
  def shareable?(pkmn)
    return false if !pkmn || pkmn.egg?
    return false if pkmn.respond_to?(:shadowPokemon?) && pkmn.shadowPokemon?
    return true
  end

  #----------------------------------------------------------------
  # Writing records
  #----------------------------------------------------------------
  # @brief Writes the sharer's identity.
  # @param w [ByteWriter]
  # @param trainer [Player]
  def write_owner(w, trainer)
    w.str(trainer.name)
    w.u32(trainer.id)
    w.u8(trainer.gender)
    w.sym(trainer.trainer_type)
  end

  # @brief Copies everything a code needs from a Pokémon into a plain hash.
  # Regular and fused Pokémon both work; for fusions the species is the head's.
  # @param pkmn [Pokemon]
  # @return [Hash] A record for write_pokemon.
  def pokemon_record(pkmn)
    rec = {
      species:       pkmn.species,
      form:          pkmn.form || 0,
      level:         pkmn.level,
      item:          pkmn.item_id,
      nature:        pkmn.nature_id,
      ability:       pkmn.ability_id,
      ability_index: pkmn.ability_index || 0,
      gender:        pkmn.gender || 0,
      shiny:         pkmn.shiny?,
      super_shiny:   pkmn.super_shiny?,
      happiness:     pkmn.happiness || 0,
      ball:          pkmn.poke_ball,
      personal_id:   pkmn.personalID || 0,
      ot_name:       pkmn.owner&.name.to_s,
      ot_id:         pkmn.owner&.id.to_i,
      ot_gender:     pkmn.owner&.gender.to_i,
      nickname:      pkmn.nicknamed? ? pkmn.name : nil,
      moves:         pkmn.moves.compact.first(Pokemon::MAX_MOVES).map { |m| [m.id, m.ppup || 0] },
      iv:            STAT_IDS.map { |s| pkmn.iv[s] || 0 },
      ev:            STAT_IDS.map { |s| pkmn.ev[s] || 0 },
      ribbons:       (pkmn.ribbons || []).first(255),
      fusion:        nil
    }
    if pkmn.respond_to?(:fused?) && pkmn.fused?
      rec[:fusion] = {
        head:         pkmn.fusion_head,
        head_form:    pkmn.component_form(:head),
        body:         pkmn.fusion_body,
        body_form:    pkmn.component_form(:body),
        head_ability: pkmn.component_ability_id(:head),
        body_ability: pkmn.component_ability_id(:body)
      }
    end
    return rec
  end

  # @brief Writes a record made by pokemon_record.
  # @param w [ByteWriter]
  # @param rec [Hash]
  def write_pokemon(w, rec)
    flags = 0
    flags |= FLAG_FUSED       if rec[:fusion]
    flags |= FLAG_SHINY       if rec[:shiny]
    flags |= FLAG_SUPER_SHINY if rec[:super_shiny]
    flags |= FLAG_NICKNAMED   if rec[:nickname] && !rec[:nickname].empty?
    w.u8(flags)
    w.sym(rec[:species])
    w.u8(rec[:form])
    w.u8(rec[:level])
    w.sym(rec[:item])
    w.sym(rec[:nature])
    w.sym(rec[:ability])
    w.u8(rec[:ability_index])
    w.u8(rec[:gender])
    w.u8(rec[:happiness])
    w.sym(rec[:ball])
    w.u32(rec[:personal_id])
    w.str(rec[:ot_name])
    w.u32(rec[:ot_id])
    w.u8(rec[:ot_gender])
    w.str(rec[:nickname]) if (flags & FLAG_NICKNAMED) != 0
    w.u8(rec[:moves].length)
    rec[:moves].each do |move, ppup|
      w.sym(move)
      w.u8(ppup)
    end
    rec[:iv].each { |v| w.u8(v) }
    rec[:ev].each { |v| w.u8(v) }
    w.u8(rec[:ribbons].length)
    rec[:ribbons].each { |ribbon| w.sym(ribbon) }
    if rec[:fusion]
      f = rec[:fusion]
      w.sym(f[:head])
      w.u8(f[:head_form])
      w.sym(f[:body])
      w.u8(f[:body_form])
      w.sym(f[:head_ability])
      w.sym(f[:body_ability])
    end
  end

  #----------------------------------------------------------------
  # Exporting (player facing)
  #----------------------------------------------------------------
  # @brief Copies the player's profile code (their whole party) to the clipboard.
  # @return [Boolean] Whether a code was made.
  def export_party
    if $player.party.none? { |pkmn| shareable?(pkmn) }
      pbMessage(_INTL("You don't have any Pokémon in your party to share!"))
      return false
    end
    code = DevLog.guard("Wonder Link: could not build a profile code") { party_code }
    return deliver_code(code, _INTL("Your Wonder Link code"))
  end

  # @brief Lets the player pick a party Pokémon and copies a trade code for it.
  # The player keeps the Pokémon; the code lets one other player trade for a copy of it.
  # @return [Boolean] Whether a code was made.
  def export_trade
    return export_single(:trade, _INTL("Which Pokémon do you want to offer for trade?"))
  end

  # @brief Lets the player pick a party Pokémon and copies a gift code for it.
  # The player keeps the Pokémon; the code gives one other player a copy of it.
  # @return [Boolean] Whether a code was made.
  def export_gift
    return export_single(:gift, _INTL("Which Pokémon do you want to send as a gift?"))
  end

  # @brief Shared part of export_trade and export_gift.
  # @param type [Symbol] :trade or :gift
  # @param prompt [String] Message shown before the party screen.
  # @return [Boolean]
  def export_single(type, prompt)
    pbMessage(prompt)
    index = choose_party_pokemon(proc { |pkmn| shareable?(pkmn) })
    return false if index < 0
    pkmn = $player.party[index]
    code = DevLog.guard("Wonder Link: could not build a #{type} code") { single_code(type, pkmn) }
    label = (type == :trade) ? _INTL("A trade code for {1}", pkmn.name) : _INTL("A gift code for {1}", pkmn.name)
    return deliver_code(code, label)
  end

  # @brief Opens the party screen and returns the chosen index.
  # Unlike the pbChoosePokemon script command, no game variables are changed.
  # @param able_proc [Proc] Which Pokémon can be chosen.
  # @param tradable [Boolean] Also refuse Pokémon that can't be traded.
  # @return [Integer] Party index, or -1 if cancelled.
  def choose_party_pokemon(able_proc, tradable = false)
    chosen = -1
    pbFadeOutIn do
      scene  = PokemonParty_Scene.new
      screen = PokemonPartyScreen.new(scene, $player.party)
      chosen = tradable ? screen.pbChooseTradablePokemon(able_proc) : screen.pbChooseAblePokemon(able_proc)
    end
    return chosen
  end

  # @brief Copies a finished code to the clipboard and tells the player.
  # @param code [String, nil] nil if building the code failed.
  # @param label [String] What the code is, e.g. "Your Wonder Link code".
  # @return [Boolean] Whether there was a code to deliver.
  def deliver_code(code, label)
    if !code
      pbMessage(_INTL("Something went wrong while making the Wonder Link code."))
      return false
    end
    if copy_to_clipboard(code)
      pbMessage(_INTL("{1} was copied to your clipboard! Share it with a friend.", label))
      show_code(code) if SHOW_CODE_AFTER_EXPORT
    else
      pbMessage(_INTL("{1} couldn't be copied, so it will be shown instead.", label))
      show_code(code)
    end
    return true
  end

  # @brief Shows a code on screen (and in the console in debug mode).
  # @param code [String]
  def show_code(code)
    echoln("Wonder Link code: #{code}") if $DEBUG
    pbMessage(code.scan(/.{1,40}/).join("\n"))
  end

  # @brief Copies text to the system clipboard where the engine supports it.
  # @param text [String]
  # @return [Boolean] Whether the text was copied.
  def copy_to_clipboard(text)
    return false if !Input.respond_to?(:clipboard=)
    return DevLog.guard("Wonder Link: could not copy to the clipboard", false) do
      Input.clipboard = text
      next true
    end
  end
end
