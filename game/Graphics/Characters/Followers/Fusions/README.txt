Custom fusion follower sprites (Fused Fates Fusion System)

A charset here replaces the spliced follower for that fusion.
The "Followers shiny/Fusions" folder holds the shiny versions.

File names:  HEAD[_form]_BODY[_form].png
Examples:    PIKACHU_CHARMANDER.png
             RATTATA_1_GEODUDE.png

Format: a 4x4 charset like any other follower sprite
        (rows: down, left, right, up; columns: walking frames).

FusionSettings::FOLLOWER_SPRITE_MODE (000_Settings.rb) chooses how these are used:
  :auto   - custom file if present, otherwise splice head and body (default)
  :splice - always splice, ignoring this folder
  :custom - custom file if present, otherwise the head's own follower sprite
