sexy_scroller.vim - Smooth animation of the cursor and the page whenever they move, with easing.
By joeytwiddle, inspired by Terry Ma's smooth_scroll.vim (although there are many others)

Options:

Instead of specifying the scrolling *speed*, SexyScroller asks you to
specify how *slow* you want scrolling to be.  You can store these options in
your .vimrc once you are happy with them.

  :let g:SexyScroller_CursorTime = 5

      Sets the time taken to move the cursor one line (in milliseconds), or
      set it to 0 to never scroll the cursor.  However, you may not see the
      cursor during animation, in which case you can   :set cursorline

  :let g:SexyScroller_ScrollTime = 10

      Sets the time taken to scroll the buffer one line.  (I like to pretend
      the buffer is "heavier" than the cursor.)

  :let g:SexyScroller_MaxTime = 500

      Sets the maximum time for long scrolls.

  :let g:SexyScroller_EasingStyle = 1

      Sets the easing style (how scrolling accelerates and decelerates),
      where:

             1 = start fast, finish slowly            (practical)

             2 = start slow, get faster, end slowly   (sexiest)

             3 = constant speed                       (dull)

  :let g:SexyScroller_DetectPendingKeys = 1   /   0

      Interrupts the animation if you press a key.  Should resume animation
      if they key you pressed also causes scrolling, otherwise just jumps
      directly to the destination.  This feature seems to be working ok now.
      Resuming animation looks best with EasingStyle 1.

For eye candy, set MaxTime to 1200 and EasingStyle to 2.

Power users may prefer to lower MaxTime to 400, and set EasingStyle 1 or 3.

ISSUES:

- It looks odd after you perform a `/` search with 'incsearch' because Vim has already taken us to the target line.  When ending the search, we jump back to where we started from, and then scroll forwards to the target!  There is no event hook to handle this.  `n` and `N` work fine.  TODO: We could temporarily disable ourself when `/` or `?` are initiated (until the next CursorMove or CursorHold).

CONSIDER TODO: Make a list of exclude keys, and map them so that they set w:SS_Ignore_Next_Movement .  For example this would apply to / and ? with 'hlsearch' enabled, and maybe also to d.

- I have disabled smooth horizontal animation of the cursor because I cannot see the cursor moving, even with 'cursorcolumn' enabled, so it's pointless!  In fact the cursor is also invisible during vertical scrolling, but 'cursorline' can show the cursor line moving.  A workaround for this might be to split the requested movement into a sequence of smaller movements, rather than using winrestview.  (We would want to avoid re-triggering ourself on those CursorMove events!  Either with :noauto or with a flag.)

- PageUp, PageDown, Ctrl-U and Ctrl-D do not always trigger a getchar(), so DetectPendingKeys does not always work for them.  This may be system-dependent.  Simpler keystrokes like { and } rarely fail.

Although we have worked around |CTRL-E| and |CTRL-Y| with mappings below, we have not handled any of the z commands under |scroll-cursor|.  They are hard to map and do not fire any events.  These will not trigger animation, but an undesired animation will eventually fire later, when the cursor does move.

- If the user has set their own mappings for scrolling (which do not move the cursor), then like C-E and C-Y, these will not fire a CursorMoved event, and will not initiate animation.  One workaround for this is for the user to add a couple of keystrokes to the end of their mapping, that *will* initiate a CursorMoved and a check for animation.  For example, add <BS><Space> at the end of the mappings (which will work everywhere except the first char in the document).

- Plugins and such which use :noauto (TagList for example) will not fire CursorMoved when it actually happens, leading to an animation occurring later, from a long-gone source to a long-sat-on destination.

- Resizing the window may cause the cursor to move but CursorMoved will not be fired until later??

- The cursor animates after a mouse click, which does not feel quite right.  But also doesn't bother me enough to fix it.

- Animation does not work at all well with mouse scrolling.  I can't think of any way to work around this.  If you scroll with the mouse more than the keys, this plugin might not be for you.

- This is very nice as a general purpose page scroller, but as mentioned in the second issue above, it does not display the cursor when scrolling.  This is not really an issue if cursorline is enabled, but users without cursorline probably will not see the cursor animating (at least I don't see it on my system).  If we *really* want to achieve this, we could fire/feed keyboard events instead of calling winrestview when the cursor should scroll but not the page.  (I.e. winrestview(a:start) followed by a bunch of movement actions (perhaps through feedkeys), following by winrestview(a:end) just to make sure.)  Alternatively, we can just say that we don't care much about cursor scrolling; this plugin is mainly for animating page scrolling, and cursor movement was an afterthought (or rather a neccessity!).

CONSIDER TODO: We could optionally enable cursorline whilst scrolling.  (Reproducing the functionality of highlight_line_after_jump.vim)

TODO: We should really store and restore lazyredraw if we are going to continue to clobber it.


