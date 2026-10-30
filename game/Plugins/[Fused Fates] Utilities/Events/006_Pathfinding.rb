#================================================================================================
# Pokémon Fused Fates Utilities/Events - 006_Pathfinding.rb
#================================================================================================

#==================================================================
# module EventPathfinder
#==================================================================
# @brief A* pathfinding for characters on their own map, using 4-direction steps.
# Each step is checked with the character's own passability (Game_Character#can_move_from_coordinate?),
# so tile passages, other events, the player and the character's size are all taken into account.
# Moving events count as obstacles where they stand at the moment the path is worked out.
module EventPathfinder
  DIRECTIONS = [2, 4, 6, 8].freeze
  DX = { 2 => 0, 4 => -1, 6 => 1, 8 => 0 }.freeze
  DY = { 2 => 1, 4 => 0, 6 => 0, 8 => -1 }.freeze

  module_function

  # @brief Works out the shortest path from a character's position to a tile.
  # @param chara [Game_Character]
  # @param x [Integer] Target X on the character's map.
  # @param y [Integer] Target Y on the character's map.
  # @param adjacent [Boolean] Stop on a tile next to the target instead of on it
  #   (for walking up to another character).
  # @param max_nodes [Integer] Most tiles to look at before giving up.
  # @return [Array<Integer>, nil] Directions (2/4/6/8) to step in, empty if already there,
  #   or nil if the target can't be reached.
  def find_path(chara, x, y, adjacent: false, max_nodes: UtilitySettings::PATHFIND_MAX_NODES)
    map = chara.map
    width = map.width
    start = [chara.x, chara.y]
    goal = adjacent ? ->(px, py) { (px - x).abs + (py - y).abs == 1 } : ->(px, py) { px == x && py == y }
    heuristic = lambda do |px, py|
      dist = (px - x).abs + (py - y).abs
      next adjacent ? [dist - 1, 0].max : dist
    end
    return [] if goal.call(*start)
    start_key = (start[1] * width) + start[0]
    came_from = { start_key => nil }   # Tile key => [previous key, direction]
    cost = { start_key => 0 }
    open = MinHeap.new
    open.push(heuristic.call(*start), start_key)
    closed = {}
    until open.empty?
      key = open.pop
      next if closed[key]   # A stale copy of a tile already reached more cheaply
      closed[key] = true
      cx = key % width
      cy = key / width
      return rebuild(came_from, key) if goal.call(cx, cy)
      return nil if closed.length > max_nodes
      DIRECTIONS.each do |dir|
        nx = cx + DX[dir]
        ny = cy + DY[dir]
        next if !map.valid?(nx, ny)
        next_key = (ny * width) + nx
        new_cost = cost[key] + 1
        next if cost.key?(next_key) && cost[next_key] <= new_cost
        next if !chara.can_move_from_coordinate?(cx, cy, dir)
        cost[next_key] = new_cost
        came_from[next_key] = [key, dir]
        open.push(new_cost + heuristic.call(nx, ny), next_key)
      end
    end
    return nil
  end

  # @brief Follows came_from links back to the start.
  # @return [Array<Integer>] Directions from the start to key.
  def rebuild(came_from, key)
    dirs = []
    while (link = came_from[key])
      key, dir = link
      dirs.unshift(dir)
    end
    return dirs
  end

  # @brief Builds a move route that walks a path.
  # @param dirs [Array<Integer>] As returned by find_path.
  # @param direction [Integer, nil] Direction (2/4/6/8) to turn to at the end.
  # @param skippable [Boolean] false waits at a blocked step until it clears; true skips it.
  # @return [RPG::MoveRoute]
  def route_for(dirs, direction: nil, skippable: false)
    moves = { 2 => PBMoveRoute::DOWN, 4 => PBMoveRoute::LEFT, 6 => PBMoveRoute::RIGHT, 8 => PBMoveRoute::UP }
    turns = { 2 => PBMoveRoute::TURN_DOWN, 4 => PBMoveRoute::TURN_LEFT,
              6 => PBMoveRoute::TURN_RIGHT, 8 => PBMoveRoute::TURN_UP }
    route = RPG::MoveRoute.new
    route.repeat    = false
    route.skippable = skippable
    route.list.clear
    dirs.each { |dir| route.list.push(RPG::MoveCommand.new(moves[dir])) }
    route.list.push(RPG::MoveCommand.new(turns[direction])) if turns[direction]
    route.list.push(RPG::MoveCommand.new(0))
    return route
  end

  #==================================================================
  # class EventPathfinder::MinHeap
  #==================================================================
  # @brief A small binary heap used as A*'s open list. Equal priorities come out in the order
  # they were pushed, which keeps paths straight instead of zig-zagging.
  class MinHeap
    def initialize
      @items = []   # [priority, order, value]
      @order = 0
    end

    # @return [Boolean]
    def empty?
      return @items.empty?
    end

    # @param priority [Numeric] Lower comes out first.
    # @param value [Object]
    def push(priority, value)
      @items.push([priority, @order, value])
      @order += 1
      i = @items.length - 1
      while i > 0
        parent = (i - 1) / 2
        break if (@items[parent] <=> @items[i]) <= 0
        @items[parent], @items[i] = @items[i], @items[parent]
        i = parent
      end
    end

    # @return [Object, nil] The value with the lowest priority.
    def pop
      return nil if @items.empty?
      top = @items[0]
      last = @items.pop
      if !@items.empty?
        @items[0] = last
        i = 0
        loop do
          left = (i * 2) + 1
          right = left + 1
          smallest = i
          smallest = left if left < @items.length && (@items[left] <=> @items[smallest]) < 0
          smallest = right if right < @items.length && (@items[right] <=> @items[smallest]) < 0
          break if smallest == i
          @items[smallest], @items[i] = @items[i], @items[smallest]
          i = smallest
        end
      end
      return top[2]
    end
  end
end

#==================================================================
# module EventUtils (pathfinding)
#==================================================================
module EventUtils
  STEP_METHODS = { 2 => :move_down, 4 => :move_left, 6 => :move_right, 8 => :move_up }.freeze
  TURN_METHODS = { 2 => :turn_down, 4 => :turn_left, 6 => :turn_right, 8 => :turn_up }.freeze

  module_function

  # @brief Walks a character (an event or the player) to a tile on its map, finding the way itself.
  # If something blocks the path partway, a new path is worked out from where the character stands,
  # up to UtilitySettings::PATHFIND_RETRIES times.
  #
  #   EventUtils.walk_to("Rival", 12, 7)
  #   EventUtils.walk_to(-1, 5, 3, direction: 8)   # Walk the player there and face up
  #
  # @param ref [Integer, String, Regexp, Game_Character] Who walks (see EventUtils).
  # @param x [Integer]
  # @param y [Integer]
  # @param adjacent [Boolean] Stop next to the tile instead of on it.
  # @param direction [Integer, nil] Direction (2/4/6/8) to face on arrival.
  # @param wait [Boolean] true walks step by step and returns on arrival. false starts a move route
  #   and returns at once; that route waits at blocked steps and doesn't re-path.
  # @return [Boolean] Whether the character got there (with wait: false, whether a path was found).
  def walk_to(ref, x, y, adjacent: false, direction: nil, wait: true)
    chara = character!(ref)
    return false if !chara
    path = EventPathfinder.find_path(chara, x, y, adjacent: adjacent)
    if !path
      DevLog.warn("EventUtils.walk_to: #{describe(chara)} can't reach (#{x}, #{y})")
      return false
    end
    if !wait
      chara.force_move_route(EventPathfinder.route_for(path, direction: direction))
      return true
    end
    arrived = follow_path(chara, path, x, y, adjacent)
    chara.send(TURN_METHODS[direction]) if arrived && TURN_METHODS[direction]
    $PokemonMap&.addMovedEvent(chara.id) if chara.is_a?(Game_Event) && chara.map_id == $game_map.map_id
    return arrived
  end

  # @brief Walks a character up to another one and turns them to face each other.
  # @param ref [Integer, String, Regexp, Game_Character] Who walks.
  # @param target [Integer, String, Regexp, Game_Character] Who to walk up to; -1 is the player.
  # @param face_both [Boolean] Also turn the target toward the walker.
  # @return [Boolean] Whether the character got there.
  def walk_to_event(ref, target = -1, face_both: false)
    chara = character!(ref)
    other = character!(target)
    return false if !chara || !other
    arrived = walk_to(chara, other.x, other.y, adjacent: true)
    return false if !arrived
    face_both ? face_each_other(chara, other) : face(chara, other)
    return true
  end

  # @brief Takes the steps of a path one at a time, re-pathing when a step is blocked.
  # @return [Boolean] Whether the character reached the target.
  def follow_path(chara, path, x, y, adjacent)
    retries = UtilitySettings::PATHFIND_RETRIES
    loop do
      wait_for_moves(chara)
      return true if path.empty?
      dir = path.first
      if chara.can_move_in_direction?(dir)
        chara.send(STEP_METHODS[dir])
        path.shift
        next
      end
      return false if retries <= 0
      retries -= 1
      wait_seconds(UtilitySettings::PATHFIND_RETRY_WAIT)
      path = EventPathfinder.find_path(chara, x, y, adjacent: adjacent)
      return false if !path
    end
  end

  # @brief Waits while keeping the map updated.
  # @param seconds [Float]
  def wait_seconds(seconds)
    start = System.uptime
    update_frame while System.uptime - start < seconds
  end

  # @brief A short description of a character for log messages.
  # @return [String]
  def describe(chara)
    return "the player" if chara == $game_player
    return "event #{chara.id} (#{chara.name})" if chara.is_a?(Game_Event)
    return chara.class.name
  end
end
