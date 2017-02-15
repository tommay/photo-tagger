Some quick doc so I don't forget how to use this.

# Usage

tagger [file|directory]...

If no files or directories are given, the current directory "." is
used.

The up/down arrows move to the prev/next argument.  If an argument is
a directory, the left/right arrows move to the prev/next file in the
directory.

# Finding the .db file

Check TAGGER\_DB in the environment.  If not set, search up the
directory tree from the current directory for a .taggerdb file to tell
us what sqlite file to use.  If no .taggerdb is found, use tags,db in
the current directory.  TAGGER\_DB in the environment overrides this.

# Navigation

* The left and right arrows move to the previous and next photos in the
current photo's directory.  Photos are sorted alphabetically by name,
with numbers within filenames sorted by value, not alphabetically, so
"photo\_9.jpg" will sort before "photo\_10.jpg".

* The up and down arrows move to the previous or next argument, which is
either a file or a directory.

* C-0 moves to the first file in the directory.

* C-u moves to the next untagged photo in the directory.

* A-u moves to the next unrated photo in the directory.

* C-d switches to/from .daleted.

* C-n/C-p moves to the next/previous directory in the file system.

* C-spc sets the "mark" to the current photo.  This is useful to mark the first
of a bunch of photos, then go through and tage them, then C-x back to the
marked photo at the beginning to rate them.

* C-x switches between the current and marked photos.  The current photo
  becomes the marked photo, so another C-x will switch back.

* A-x switches to the marked photo without changing the mark to the current
  photo.

* C-b/C-f move backward and forward in the history of photos viewed.
  This is really useful when you move somewhere weird.  C-b will
  get you right back.
  _What happens with deleted/renamed files in the history list?_

* C-s saves the current photo across sessions.  Quitting the program
also does this so maybe this keystroke isn't so useful.

* C-r goes to the file saved by C-s in this or a previous session.

* C-u move to the next untagged photo in the directory.

* A-u move to the next unrated photo in the directory.

* C-0 moves to the first file in a directory.

# Operations:

* C-< losslessly rotates 90 degrees counter-clockwise.

* C-> losslessly rotates 90 degrees clockwise.

* C-6 losslessly crops a photo taken by my 6mm lens so the circular
  portion fills the frame.

# File management

* Delete deletes the current photo as well as any files with the same
  basename, so raw files and xmp files and whatever else are all
  deleted together.  After deleting, it moves to either the next file
  in the directory or the next argument, according to whether the last
  navigation used the left/right arrows or the up/down arrows.  This allows
  working with a set of files in a dorectory or a set of files given
  as arguments.

  Deleted files are just moved the the .deleted subdirctory.  They can
  be reviewed by navigating to the .deleted subdirectory with C-d.
  Deleting from .deleted undeletes by moving the files back up a
  level.

* C-m moves the photo to a new directory.  A dialog pops up to
  enter the new directory name.  If the most recent file C-m'd in
  thie session was moved from the current photo's directory, then the
  directory it was moved to is used as the default.  Otherwise the
  current photo's directory is used as the default.  If the default
  contains a date like "2016-08-23" it is replaced with the current
  photo's date.  When entering the new directory name, C-d will
  insert the current photo's date if it's known.

* Alt-m moves the current photo to a new directory without asking
  where to move it.  It uses C-m's default directory, including any
  date string substitution.  This can be used to rapidly move a
  sequence of photos to the same directory or a set of directories
  with the same name but varying dates.

* C-v pops up a dialog to rename the current directory.

* C-z is undo.  It will undo rotate, crop, and delete.  If a file
  has been rotated multiple times it will undo to the original
  rotation.

* C-e creates a sidecar export file for the current photo.

* C-w copies the current filename ot the clipboard for pasting into Windows.

# Pan and zoom

* Double-click to zoom in on the click point.

* Drag the photo to pan.

* 9 sets the zoom to 1:1.

* 0 fits the whole photo to the window.

When navigating to a different photo, the current zoom and scroll
settings are kept if possible.  This allows viewing the same portion
of a sequence of photos as they are navigated through.



# Tagging

The tags are on the left side of the window.  The top section shows
the tags applied to the image.  In the center is a text entry box for
typing tags to add.  The bottom section contains a list of tags, with
three tabs to choose which tags are in the list.  The space allocated to
this list can be changed by dragging just above the tabs.

The tabs are:

* *Dir* shows all the tags from photos in the same directory.  This is
useful for having a small list of likely tags to add, and is also
useful to see the tags used by the directory you've just navigated to.

* *Rec* shows recently added tags in this session.

* *All* shows all the tags in the entire database.

Typing a tag in the text entry uses auto-completion from the selected
list.

Click a tag in the bottom section to add it.  Click a tag in the top
section to remove it.

It would be nice to figure out how to make a click in the auto-complete
list actualy add the tag instead of just auto-completing the text box.

* *<* selects the previous set of tags applied to a photo.  It's useful
  if you want to give a photo the same tags as the previous photo, or the
  one before that, or if you just want to use those tags as a starting point.

* *>* goes the other way in the list of applied tags.

Note that tags are applied or removed immediately.  What you see in
the top section is that the photo's tags _are_, not what they will be.
_There is currently no easy way to get a photo's original tags if you
mess them up._

# Rating

Photos may be rated 1 to 5 stars, or unrated.  The rating shows in the
light gray area above the tag list as 1 to 5 asterisks, or no
asterisks.

To rate a photo, press a key 1 to 5.  The rating will be applied and
the next unrated photo will be selected.  To stay on the current photo,
use C-1 to C-5.

The "next" photo depends on how you navigated to the current photo.
If you used left/right to navigate within a directory, the next photo
is the next photo in the current directory if there is next photo.  If
you used up/down to navigate withing the argument list, the next photo
is the next argument, if any.  This could probably use a bit more
explanation.  Especially because at startup it defaults to next in
directory, and when working in a .delete directory it is always
next in directory.

To remove the rating on a photo use the *-* (minus) key.
