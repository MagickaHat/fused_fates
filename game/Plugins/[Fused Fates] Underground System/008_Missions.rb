#================================================================================================
# Pokémon Fused Fates Underground System - 008_Missions.rb
#================================================================================================

#==================================================================
# module Underground
#==================================================================
module Underground
  # @brief Mission list.
  # :intro  - shown while the mission is active
  # :done   - shown when it is turned in
  # :check  - proc(data) returning true once complete
  # :reward - proc(data) applying the reward
  MISSIONS = [
    { # 0
      intro:  "Try digging at one of the sparkling spots on the walls!",
      done:   "You found something! Here, take this desk for your trouble.",
      check:  proc { |d| d.stats[:digs] >= 1 },
      reward: proc { |d| d.goods[:GOODDESK] += 1 }
    },
    { # 1 - common wall statues unlock from here
      intro:  "Traders will swap goods for spheres. Go make a trade!",
      done:   "Nice trade! Keep an eye out for statues in the walls now.",
      check:  proc { |d| d.stats[:trades] >= 1 },
      reward: proc { |d| d.spheres[:red] += 10 }
    },
    { # 2
      intro:  "Pokémon live in the hideaways. Catch one!",
      done:   "Great catch! You've earned a Secret Base of your own.",
      check:  proc { |d| d.stats[:hideaway_catches] >= 1 },
      reward: proc { |d|
        d.base_size = :small
        Underground.grant_statue(:STATUEPIKACHU)
      }
    },
    { # 3
      intro:  "Put a statue on a pedestal in your base. Watch what it attracts!",
      done:   "Looking good! Here's a planter for growing spheres.",
      check:  proc { |d| d.placed_statues.any? },
      reward: proc { |d| d.goods[:GOODPLANTER] += 1 }
    },
    { # 4
      intro:  "The other diggers have flags in their bases. Grab one!",
      done:   "You got a flag! Time for a bigger base. And the Oreburgh Line carts are running again!",
      check:  proc { |d| d.stats[:flags] >= 1 },
      reward: proc { |d|
        d.base_size = :medium
        d.repaired_lines.push(:oreburgh) unless d.repaired_lines.include?(:oreburgh)
      }
    },
    { # 5
      intro:  "Bury a sphere in your planter and let it grow.",
      done:   "Look how big it got! Take this... it's a strange one.",
      check:  proc { |d| d.stats[:spheres_grown] >= 1 },
      reward: proc { |_d| Underground.grant_statue(:STATUEFUSEDSHINXGIBLE) }
    },
    { # 6 - rare wall statues unlock from here
      intro:  "The leader of the diggers wants to meet you at their base.",
      done:   "You beat the leader! The deepest hideaway is open to you now.",
      check:  proc { |d| d.stats[:rival_leader] >= 1 },
      reward: proc { |d|
        d.base_size = :large
        Underground.grant_statue(:STATUEFUSEDBUNEARYRIOLU)
        [:veilstone, :deep].each do |line|
          d.repaired_lines.push(line) unless d.repaired_lines.include?(line)
        end
      }
    }
    # Stage 7 (no mission left) - fused statues appear in trader stock.
  ]
end

# @brief Talks to the Underground Man: turns in a completed mission
# or repeats the current one.
def pbUndergroundMan
  d = Underground.data
  mission = Underground::MISSIONS[d.mission_stage]
  if mission.nil?
    pbMessage(_INTL("You've mastered the Underground!"))
    return
  end
  unless mission[:check].call(d)
    pbMessage(_INTL(mission[:intro]))
    return
  end
  pbMessage(_INTL(mission[:done]))
  mission[:reward].call(d)
  d.mission_stage += 1
  next_mission = Underground::MISSIONS[d.mission_stage]
  pbMessage(_INTL(next_mission[:intro])) if next_mission
end
