#================================================================================================
# Pokémon Fused Fates Utilities/Events - 005_Movement.rb
#================================================================================================

#==================================================================
# module EventUtils (movement)
#==================================================================
module EventUtils
  module_function

  # @brief Updates the map until every given character has finished moving, jumping and
  # running its forced move route.
  # @param refs [Array] Characters (see EventUtils); none means the player.
  # @param timeout [Float, nil] Give up after this many seconds; nil waits forever.
  # @return [Boolean] false if it timed out.
  def wait_for_moves(*refs, timeout: nil)
    refs = [-1] if refs.empty?
    charas = refs.flatten.filter_map { |ref| character(ref) }
    start = System.uptime
    while charas.any? { |c| busy?(c) }
      return false if timeout && System.uptime - start >= timeout
      update_frame
    end
    return true
  end

  # @brief Checks whether a character is still moving or running a forced move route.
  # @param chara [Game_Character]
  # @return [Boolean]
  def busy?(chara)
    return chara.moving? || chara.jumping? || chara.move_route_forcing
  end

  # @brief Waits one frame while keeping the map updated.
  def update_frame
    Graphics.update
    Input.update
    pbUpdateSceneMap
  end

  # @brief pbMoveRoute that accepts a name or any other ref.
  # @param ref [Integer, String, Regexp, Game_Character]
  # @param commands [Array] PBMoveRoute commands and their parameters.
  # @param wait [Boolean] Wait for the route to finish.
  # @return [RPG::MoveRoute, nil] nil if the character wasn't found.
  def move(ref, *commands, wait: false)
    chara = character!(ref)
    return nil if !chara
    route = pbMoveRoute(chara, commands.flatten)
    wait_for_moves(chara) if wait
    return route
  end

  # @brief Turns one character to face another.
  # @param ref [Integer, String, Regexp, Game_Character] Character that turns.
  # @param target [Integer, String, Regexp, Game_Character] Character to face; -1 is the player.
  def face(ref, target = -1)
    chara = character!(ref)
    other = character!(target)
    pbTurnTowardEvent(chara, other) if chara && other
  end

  # @brief Turns two characters to face each other.
  # @param a [Integer, String, Regexp, Game_Character]
  # @param b [Integer, String, Regexp, Game_Character] -1 (the default) is the player.
  def face_each_other(a, b = -1)
    chara_a = character!(a)
    chara_b = character!(b)
    return if !chara_a || !chara_b
    pbTurnTowardEvent(chara_a, chara_b)
    pbTurnTowardEvent(chara_b, chara_a)
  end
end
