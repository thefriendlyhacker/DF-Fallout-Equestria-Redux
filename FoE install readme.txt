To install Fallout Equestria Redux:
1. Download/unzip a fresh installation of Dwarf Fortress 44.10
2. Install dfhack
3. Install your graphics pack.  Fallout Equestria's sprites are designed to match the style of phoebus, but it is ultimately up to you.  If you do choose a different pack, then you will need to change init.txt after you copy Fallout Equestria Redux across (see below).
4. Delete raw/objects
5. Copy the contents of the DF FoE Redux folder into your dwarf fortress installation, with the exception of the TWBT folder.  When asked, merge and replace everything.
6. Run the Dwarf Fortress executable and enjoy.

If you don't like graphics and prefer to experience FoE in all it's DF ascii glory, just delete everything in the raw/graphics folder.  If you want to be able to distinguish between earth and unicorn ponies, deleting just graphics_generalzoi_pony.txt and graphics_generalzoi_pony_stable.txt will revert ponies to "u" and "e" sprites without affecting anything else. 

If you are using a graphics pack other than Phoebus, you will need to change the tileset in init.txt.  Go to data/init/init.txt, and find the four lines that look something like this:[FULLFONT:Phoebus_16x16_text.png], and change them to your graphics pack's tileset (or [FULLFONT:curses_800x600.png] for the vanilla tileset).  Your graphics pack will either come with it's own init file that you can copy the correct .png file name(s) from, or it will have it's own instructions that you can follow.  If you prefer your pack's tileset to True Type Font, you can also disable TTF in the init file while you are at it (or just toggle it with f12 ingame).  If you are using TWBT with your graphics pack, add FoE's TWBT specific content before dealing with your graphics pack's init file (see below).

Oh, and consider downloading the Dwarf Therapist utility.  It makes things like identifying spellcasters *much* easier, and can sort ponies by caste (i.e. separating unicorns from earth ponies).

Using with TWBT
If installing Text will be Text (TWBT) alongside Fallout Equestria Redux, follow the steps above, then copy the contents of the TWBT folder into your dwarf fortress installation, overwriting everything when prompted.  TWBT FoE has it's own init file, so if you are using a different graphics set, you will need to modify the new data/init/init.txt file as above.

Because TWBT doesn't include an install guide, and is generally included with other mods instead of requiring separate installation, I am including an installation guide for TWBT, correct as of 03/09/2018.
1. copy the twbt.plug.dll file inside the dfhack version folder into hack/plugins
2. copy all .pngs except the spacefox files into data/art
3. copy colors.lua into hack/scripts
4. copy overrides.txt into data/init (your graphics pack will probably have a replacement for this)
