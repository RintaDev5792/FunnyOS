# FunnyOS
Grid-based playdate custom launcher based on the 3ds menu (with badges!)
Made for playdateOS 2.5.0

Features:
-grid-based icon system, different from the list-based default one, similar to the 3ds
-"badges" similar to those on the 3ds, that can be created from any square .pdi image
-labels system, letting you create and name "labels" on the grid that can be jumped between
-organize mode, letting you customize the placement of icons, badges, and labels, accessible from the main menu
-alphabetical organization by default to make it easier to find games when you first install it

Instructions:
 -Sideload the installer onto your playdate however you like
-Follow the instructions in the installer to install
-watch the cool animation rae made for indexos that I forgot to remove (it looks sick asf tho)

What will probably be FAQ:
Q: how does FunnyOS import badges that aren't perfectly square or 64x64?
A: Everything is square. If something isn't exactly 64x64 or 72x72, it will be scaled to 64x64 (if the original is less than or equal to 68 pixels wide) or 72x72 otherwise. 72x72 tiles tile perfectly (and can be used to create larger images out of multiple of them), while 64x64 is the normal icon size.
Q: how do I add badges?
A: just put any .pdi file (compiled with pdc from the Playdate SDK) into the "/Shared/FunnyOSBadges" folder on your playdate (accessible from data disk mode when connected to a computer). Other image formats will not work, so don't try to use .pngs or .jpegs or (ew) .webps.
Q: what happens when I add a new game or badge to my system?
A: it is placed at the end of your grid all the way to the right. I would recommend placing a label here called "end" or similar so that you can easily skip to it.
Q: I hate those borders on the icons! These were designed for list view, not to be confined! Please remove them!
A: toggle them off in the system menu
Q: how do I move stuff around?
A: check the "organize" checkbox in the system menu to enter organize mode. uncheck it to exit organize mode.
Q: what does this text at the bottom mean?
A: on the left, it details what button does what, and on the right it lists the name of the section you are currently looking in.
Q: I hate this
A: uninstall it using the installer
Q: It borked :(
A: repair it or uninstall it using the installer, then tell me what happened and how so I can fix it
Q: This isn't launching games! When i click a game it just shows me the card!
A: press the A button. It says it on the bottom of the screen.
Q: the installer isn't working!
A: this was made for playdate os version 2.5.0, and has to be updated for every version. Find a newer version, and if one isn't available, ping me repeatedly so I can bother scratchminer to make me a new installer
Q: my playdate is bootlooping/repeatedly crashing
A: hold A+B+MENU+LOCK then release A and B when told to hold MENU and LOCK. This resets your playdate to the stock launcher, but you will need to do a system update afterwards from settings.
