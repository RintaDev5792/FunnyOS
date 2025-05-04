# Contribution Guidelines

This document outlines the guidelines for contributing to FunnyOS 2 or any  
associated programs/plugins.

## NO GENAI

Pretty much what this one says on the tin. It is fairly obvious when an AI made  
something and if you really want to help, the least you can do is bother to help  
with your own efforts.

## Please Use camelCase and Tables

Variables in FunnyOS 2 are usually declared using camelCase in which the first  
character is lowercase, no underscores are used, and subsequent words are capitalised.  
  
I'm sure some variables in the program currently do not follow this standard,  
but please do not try to fix them as you will probably screw something up.  

## UX and User Preference

FunnyOS is generally very scattered when it comes to programming, but when it comes  
to user preferences and UX, some basic guidelines must be followed.  

 - All rectangles must be drawn as rounded rectangles. Any large ui elements must use configVars.cornerradius to determine the radius of corners drawn with rounded rectangles.
 - All large ui elements except those that are either meant to obscure someone's view of what is behind it or meant to show text must have dithering options in FunnyConfig. Possible dithering values must be 0, 0.25, 0.5, 0.75, and 1. This must be placed in the three tables in main.lua that determine these in FOS Options (configVarOptions, configVarDefaults, and configVarOptionsOrder).
 - All large ui elements (or even smaller ones if you value choice) must have a boolean value controlling whether they should be drawn "inverted" (whether with drawModeFill or drawModeFillWhite). Non-inverted must use black as the base color, inverted must use white.
 - Any "actions" that someone could do (one button press that causes a single action to occur that isn't changing an option) must be located in the "Actions Menu" in the control center. Any action causing irreversible change must use a popup so that users can press B to decline the change.
 - Any "options" that a user could change must be located in "FunnyOS Options" in the control center.
 - Button combinations as shown in "Controls Help" cannot be changed. 
 - If you are on the line of what UI decision to make or what feature to have, make an option for it.
 - Line width must follow configVars.linewidth.
 - User customization is key, and anything that makes a user feel less at home is not welcome in FOS.

## Provide meaningful commit messages

It is preferred that you list everything that a commit does in detail so that I  
know where to make sure everything works. Example:  

Title: Updated Label Spacing

Content: Changed label spacing in aesthetics.lua so that labels look more cohesive and clean.