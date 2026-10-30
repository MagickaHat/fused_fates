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

  module_function

  # Plays the intro sequence, call it from the event's Script command.
  def run
    cutscene do
      # Prepare for transition: background starts fully transparent
      #show_picture(PIC_BG, "introbg", 0, 0, opacity: 0)

      # Execute transition: fade the background in over 1 second, then hold
      #move_picture(PIC_BG, 1.0, 0, 0, opacity: 255, wait: true)
      pbWait(0.5)
      #pbBGMPlay("Professor Rowan")
      pbMessage(_INTL("My name is Rowan."))
      pbMessage(_INTL("However, everyone just calls me the Pokémon Professor."))
      #show starly shinx fusion
      pbMessage(_INTL("This world is widely inhabited by creatures known as Pokémon."))
      pbMessage(_INTL("We humans live alongside Pokémon as friends."))
      pbMessage(_INTL("At times we play together, and at other times we work together."))
      pbMessage(_INTL("Some people use their Pokémon to battle and develop closer bonds with them."))
      pbMessage(_INTL("What do I do?"))
      pbMessage(_INTL("I conduct research so that we may learn more about Pokémon."))
      pbMessage(_INTL("Now, why don't you tell me a little bit about yourself?"))
      pbMessage(_INTL("What do you look like? And what is your name?"))
      #character customization comes here
      pbTrainerName()
      pbMessage(_INTL("A fine name that is!"))
      # hide professor, show rival
      pbMessage(_INTL("Now, this boy here. I believe he's your friend."))
      pbMessage(_INTL("If I can recall his name..."))
      pbWait(0.5)
      pbMessage(_INTL("Ah yes. This boy's name is Barry!"))
      pbMessage(_INTL("All right, \\PN, the time has come."))
      pbMessage(_INTL("Your very own tale of grand adventure is about to unfold."))
      pbMessage(_INTL("On your journey, you will meet countless Pokémon and people."))
      pbMessage(_INTL("I'm sure that along the way you will discover many things, perhaps even something about yourself."))
      pbMessage(_INTL("Now, go on, leap into the world of Pokémon!"))
      # hide professor, show player
      # shrink player down, fade to black
    end
  end
end