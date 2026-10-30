#================================================================================================
# Pokémon Fused Fates Events - 001_EventCommands.rb
#================================================================================================

#==================================================================
# module Events
#==================================================================
# @brief Module that holds the command helpers related to events.
module Events
  module_function

  #----------------------------------------------------------------
  # Pictures
  #----------------------------------------------------------------
  # @brief Gets a picture slot, offset the same way the event commands do in battle.
  # @param number [Integer] Picture number (1-100).
  # @return [Game_Picture]
  def picture(number)
    return $game_screen.pictures[number + ($game_temp.in_battle ? 50 : 0)]
  end

  # @brief Shows a picture from Graphics/Pictures.
  # @param number [Integer] Picture number (1-100).
  # @param name [String] File name in Graphics/Pictures, without extension.
  # @param x [Numeric] Screen x.
  # @param y [Numeric] Screen y.
  # @param origin [Integer] 0 = top-left, 1 = centre.
  # @param zoom [Numeric] Zoom percentage, applied to both axes.
  # @param opacity [Integer] 0-255.
  # @param blend [Integer] 0 = normal, 1 = add, 2 = subtract.
  def show_picture(number, name, x, y, origin: 0, zoom: 100, opacity: 255, blend: 0)
    picture(number).show(name, origin, x, y, zoom, zoom, opacity, blend)
  end

  # @brief Moves/fades/zooms a picture to new values over time.
  # @param number [Integer] Picture number.
  # @param seconds [Numeric] How long the move takes.
  # @param wait [Boolean] Block until the move finishes.
  def move_picture(number, seconds, x, y, origin: 0, zoom: 100, opacity: 255, blend: 0, wait: false)
    picture(number).move(seconds * 20, origin, x, y, zoom, zoom, opacity, blend)
    pbWait(seconds) if wait
  end

  # @brief Changes a picture's colour tone over time.
  # @param tone [Tone] Target tone.
  # @param seconds [Numeric] How long the change takes (0 = instant).
  # @param wait [Boolean] Block until the change finishes.
  def tone_picture(number, tone, seconds, wait: false)
    picture(number).start_tone_change(tone, seconds * 20)
    pbWait(seconds) if wait && seconds > 0
  end

  # @brief Removes a picture from the screen.
  def erase_picture(number)
    picture(number).erase
  end

  #----------------------------------------------------------------
  # Transfers
  #----------------------------------------------------------------
  # @brief Moves the player to another map (or another spot on this one), like the Transfer Player command.
  # @param map_id [Integer] Destination map ID (the number shown in RMXP's map list).
  # @param x [Integer] Destination tile x.
  # @param y [Integer] Destination tile y.
  # @param direction [Integer] 2 = down, 4 = left, 6 = right, 8 = up, 0 = keep current facing.
  # @param fade [Boolean] Fade to black and back around the transfer.
  # @yield Optional block run while the screen is black (e.g. to erase pictures).
  def transfer_player(map_id, x, y, direction: 2, fade: true)
    return if !$scene.is_a?(Scene_Map)
    move = proc do
      yield if block_given?
      $game_temp.player_new_map_id    = map_id
      $game_temp.player_new_x         = x
      $game_temp.player_new_y         = y
      $game_temp.player_new_direction = direction
      pbCancelVehicles
      $scene.transfer_player
      $game_map.autoplay
      $game_map.refresh
    end
    fade ? pbFadeOutIn { move.call } : move.call
  end

  #----------------------------------------------------------------
  # Screen
  #----------------------------------------------------------------
  # @brief Tints the map and all pictures to black over time, and leaves them black.
  # @param seconds [Numeric] How long the fade takes (0 = instant).
  # @param wait [Boolean] Block until the fade finishes.
  def fade_to_black(seconds = 1.0, wait: true)
    pbToneChangeAll(Tone.new(-255, -255, -255, 0), seconds * 20)
    pbWait(seconds) if wait && seconds > 0
  end

  # @brief Brings the map and all pictures back from a fade_to_black.
  # @param seconds [Numeric] How long the fade takes (0 = instant).
  # @param wait [Boolean] Block until the fade finishes.
  def fade_from_black(seconds = 1.0, wait: true)
    pbToneChangeAll(Tone.new(0, 0, 0, 0), seconds * 20)
    pbWait(seconds) if wait && seconds > 0
  end
end