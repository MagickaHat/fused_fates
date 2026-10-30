#================================================================================================
# Pokémon Fused Fates Events/Intro - 001_Intro.rb
#================================================================================================

#==================================================================
# module Introduction
#==================================================================
module Introduction
  # Picture slots used by the intro
  PIC_BG        = 1
  PIC_PROFESSOR = 2
  PIC_POKEMON   = 3
  PIC_RIVAL     = 4
  PIC_REPORT    = 5
  PIC_TV        = 6
 
  module_function

  # Plays the intro sequence, call it from the event's Script command.
  def run
    cutscene do
      # Prepare for transition: background and professor starts fully transparent
      Events.show_picture(PIC_BG, "introbg", 0, 0, opacity: 0)
      Events.show_picture(PIC_PROFESSOR, "introRowan", 172, 64, opacity: 0)

      # Play Professor BGM
      pbBGMPlay("Professor Rowan")

      # Execute transition: fade the background and professor in over 1 second, then hold
      Events.move_picture(PIC_BG, 1.0, 0, 0, opacity: 255, wait: true)
      Events.move_picture(PIC_PROFESSOR, 3.0, 172, 64, opacity: 255, wait: true)
      pbWait(0.5)
      pbMessage(_INTL("My name is Rowan."))
      pbMessage(_INTL("However, everyone just calls me the Pokémon Professor."))

      #show starly shinx fusion
      pbMessage(_INTL("This world is widely inhabited by creatures known as Pokémon."))
      pbMessage(_INTL("We humans live alongside Pokémon as friends."))
      pbMessage(_INTL("At times we play together, and at other times we work together."))
      pbMessage(_INTL("Some people use their Pokémon to battle and develop closer bonds with them."))
      # Erase the Pokémon, show the professor
      pbMessage(_INTL("What do I do?"))
      pbMessage(_INTL("I conduct research so that we may learn more about Pokémon."))
      pbMessage(_INTL("Now, why don't you tell me a little bit about yourself?"))
      pbMessage(_INTL("What do you look like?"))

      #character customization comes here
      # Player name entry
      pbMessage(_INTL("And what is your name?"))
      loop do
        pbTrainerName()
        break if pbConfirmMessage(_INTL("So your name is {1}?", $player.name))
        pbMessage(_INTL("Oh? Then tell me again, what is your name?"))
      end
      pbMessage(_INTL("A fine name that is!"))

      # Hide the professor, show the rival
      Events.move_picture(PIC_PROFESSOR, 1.0, 172, 64, opacity: 0, wait: true)
      Events.show_picture(PIC_RIVAL, "introBarry", 172, 64, opacity: 0)
      Events.move_picture(PIC_RIVAL, 1.0, 172, 64, opacity: 255, wait: true)
      pbMessage(_INTL("Now, this boy here. I believe he's your friend."))
      pbMessage(_INTL("If I can recall his name..."))
      pbWait(0.5)
      pbMessage(_INTL("Ah yes. This boy's name is Barry!"))

      # Erase the rival, show the professor
      Events.move_picture(PIC_RIVAL, 1.0, 172, 64, opacity: 0, wait: true)
      Events.erase_picture(PIC_RIVAL)
      Events.move_picture(PIC_PROFESSOR, 1.0, 172, 64, opacity: 255, wait: true)
      pbMessage(_INTL("All right, \\PN, the time has come."))
      pbMessage(_INTL("Your very own tale of grand adventure is about to unfold."))
      pbMessage(_INTL("On your journey, you will meet countless Pokémon and people."))
      pbMessage(_INTL("I'm sure that along the way you will discover many things, perhaps even something about yourself."))
      pbMessage(_INTL("Now, go on, leap into the world of Pokémon!"))

      # Erase the professor and background
      Events.fade_to_black(3.0, wait: true)
      Events.erase_picture(PIC_BG)
      Events.erase_picture(PIC_PROFESSOR)
      pbBGMFade(1.0)

      # Show TV background and report
      Events.show_picture(PIC_TV, "introTV", 0, 0, opacity: 255)
      Events.show_picture(PIC_REPORT, "introTVreport", 0, 0, opacity: 255)
      Events.fade_to_black(0)

      # Play TV Report BGM and fade in
      pbBGMPlay("TV Report")
      Events.fade_from_black(1.0)

      pbMessage(_INTL("It has now been over two years since Silph Co. introduced the DNA Splicers into the global markets."))
      pbMessage(_INTL("Ever since, trainers around the world have taken advantage of the fusion phenomenon, further connecting man and Pokémon."))
      pbMessage(_INTL("Fused Pokémon are now growing to become commonplace amongst many Pokémon leagues worldwide."))
      pbMessage(_INTL("There has also been an increased number of wild fused Pokémon sightings, leading many to criticize the very ethics of Pokémon fusion as a whole."))
      pbMessage(_INTL("How exactly will Pokémon fusion hold up for the future? Only time will tell."))

      # Erase the TV background and report
      Events.fade_to_black(3.0, wait: true)
      Events.erase_picture(PIC_TV)
      Events.erase_picture(PIC_REPORT)

      # Transfer player
      Events.transfer_player(3, 25, 7, direction: 8, fade: false)
      pbBGMStop(0)

      Events.fade_from_black(1.0)

      # Flip Self Switch A
      EventUtils.set_self_switch(1, "A", true, 1)
    end
  end
end