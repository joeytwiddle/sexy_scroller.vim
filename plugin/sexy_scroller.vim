" sexy_scroller.vim - Smooth animation of the cursor and the page whenever they move, with easing.
" By joeytwiddle, inspired by Terry Ma's smooth_scroll.vim (although there are many others)

" Options:
"
" Instead of specifying the scrolling *speed*, SexyScroller asks you to
" specify how *slow* you want scrolling to be.  You can store these options in
" your .vimrc once you are happy with them.
"
"   :let g:SexyScroller_CursorTime = 5
"
"       Sets the time taken to move the cursor one line (in milliseconds), or
"       set it to 0 to never scroll the cursor.  However, you may not see the
"       cursor during animation, in which case you can   :set cursorline
"
"   :let g:SexyScroller_ScrollTime = 10
"
"       Sets the time taken to scroll the buffer one line.  (I like to pretend
"       the buffer is "heavier" than the cursor.)
"
"   :let g:SexyScroller_MaxTime = 500
"
"       Sets the maximum time for long scrolls.
"
"   :let g:SexyScroller_EasingStyle = 1
"
"       Sets the easing style (how scrolling accelerates and decelerates),
"       where:
"
"              1 = start fast, finish slowly            (practical)
"
"              2 = start slow, get faster, end slowly   (sexiest)
"
"              3 = constant speed                       (dull)
"
"   :let g:SexyScroller_DetectPendingKeys = 1   /   0
"
"       Interrupts the animation if you press a key.  Should resume animation
"       if they key you pressed also causes scrolling, otherwise just jumps
"       directly to the destination.  This feature seems to be working ok now.
"       Resuming animation looks best with EasingStyle 1.
"
" For eye candy, set MaxTime to 1200 and EasingStyle to 2.
"
" Power users may prefer to lower MaxTime to 400, and set EasingStyle 1 or 3.

" ISSUES:
"
" - It looks odd after you perform a `/` search with 'incsearch' because Vim has already taken us to the target line.  When ending the search, we jump back to where we started from, and then scroll forwards to the target!  There is no event hook to handle this.  `n` and `N` work fine.  TODO: We could temporarily disable ourself when `/` or `?` are initiated (until the next CursorMove or CursorHold).
"
" CONSIDER TODO: Make a list of exclude keys, and map them so that they set w:SS_Ignore_Next_Movement .  For example this would apply to / and ? with 'hlsearch' enabled, and maybe also to d.
"
" - I have disabled smooth horizontal animation of the cursor because I cannot see the cursor moving, even with 'cursorcolumn' enabled, so it's pointless!  In fact the cursor is also invisible during vertical scrolling, but 'cursorline' can show the cursor line moving.  A workaround for this might be to split the requested movement into a sequence of smaller movements, rather than using winrestview.  (We would want to avoid re-triggering ourself on those CursorMove events!  Either with :noauto or with a flag.)
"
" - PageUp, PageDown, Ctrl-U and Ctrl-D do not always trigger a getchar(), so DetectPendingKeys does not always work for them.  This may be system-dependent.  Simpler keystrokes like { and } rarely fail.
"
" Although we have worked around |CTRL-E| and |CTRL-Y| with mappings below, we have not handled any of the z commands under |scroll-cursor|.  They are hard to map and do not fire any events.  These will not trigger animation, but an undesired animation will eventually fire later, when the cursor does move.
"
" - If the user has set their own mappings for scrolling (which do not move the cursor), then like C-E and C-Y, these will not fire a CursorMoved event, and will not initiate animation.  One workaround for this is for the user to add a couple of keystrokes to the end of their mapping, that *will* initiate a CursorMoved and a check for animation.  For example, add <BS><Space> at the end of the mappings (which will work everywhere except the first char in the document).
"
" - Plugins and such which use :noauto (TagList for example) will not fire CursorMoved when it actually happens, leading to an animation occurring later, from a long-gone source to a long-sat-on destination.
"
" - Resizing the window may cause the cursor to move but CursorMoved will not be fired until later??
"
" - The cursor animates after a mouse click, which does not feel quite right.  But also doesn't bother me enough to fix it.
"
" - Animation does not work at all well with mouse scrolling.  I can't think of any way to work around this.  If you scroll with the mouse more than the keys, this plugin might not be for you.
"
" - This is very nice as a general purpose page scroller, but as mentioned in the second issue above, it does not display the cursor when scrolling.  This is not really an issue if cursorline is enabled, but users without cursorline probably will not see the cursor animating (at least I don't see it on my system).  If we *really* want to achieve this, we could fire/feed keyboard events instead of calling winrestview when the cursor should scroll but not the page.  (I.e. winrestview(a:start) followed by a bunch of movement actions (perhaps through feedkeys), following by winrestview(a:end) just to make sure.)  Alternatively, we can just say that we don't care much about cursor scrolling; this plugin is mainly for animating page scrolling, and cursor movement was an afterthought (or rather a neccessity!).
"
" CONSIDER TODO: We could optionally enable cursorline whilst scrolling.  (Reproducing the functionality of highlight_line_after_jump.vim)
"
" TODO: We should really store and restore lazyredraw if we are going to continue to clobber it.

if !has("float")
  echo "smooth_scroller requires the +float feature, which is missing"
  finish
endif

if !exists("g:SexyScroller_Enabled")
  let g:SexyScroller_Enabled = 1
endif

" We can only really see the cursor moving if 'cursorline' is enabled
if !exists("g:SexyScroller_CursorTime")
  let g:SexyScroller_CursorTime = ( &cursorline || exists("g:hiline") && g:hiline ? 5 : 0 )
endif

" By default, scrolling the buffer is slower then moving the cursor, because a page of text is "heavier" than the cursor.  :)
if !exists("g:SexyScroller_ScrollTime")
  let g:SexyScroller_ScrollTime = 10
endif

if !exists("g:SexyScroller_MaxTime")
  let g:SexyScroller_MaxTime = 500
endif

if !exists("g:SexyScroller_EasingStyle")
  let g:SexyScroller_EasingStyle = 1
endif

if !exists("g:SexyScroller_DetectPendingKeys")
  let g:SexyScroller_DetectPendingKeys = 1
endif

if !exists("g:SexyScroller_Debug")
  let g:SexyScroller_Debug = 0
endif

command! SexyScrollerToggle call s:ToggleEnabled()

augroup Smooth_Scroller
  autocmd!
  autocmd CursorMoved * call s:CheckForChange(1)
  autocmd InsertLeave * call s:CheckForChange(0)
  " Unfortunately we would like to fire on other occasions too, e.g.
  " BufferScrolled, but Vim does not offer enough events for us to hook to!
augroup END

" |CTRL-E| and |CTRL-Y| scroll the window, but do not fire any events for us to detect.
" If the user has not made a custom mapping for them, we will map them to fix this.
if maparg("<C-E>", 'n') == ''
  nnoremap <silent> <C-E> <C-E>:call <SID>CheckForChange(1)<CR>
endif
if maparg("<C-Y>", 'n') == ''
  nnoremap <silent> <C-Y> <C-Y>:call <SID>CheckForChange(1)<CR>
endif

function! s:CheckForChange(actIfChange)
  let w:newPosition = winsaveview()
  let w:newBuffer = bufname('%')
  if a:actIfChange && g:SexyScroller_Enabled
        \ && exists("w:oldPosition")
        \ && exists("w:oldBuffer") && w:newBuffer==w:oldBuffer "&& mode()=='n'
    if s:differ("topline",3) || s:differ("leftcol",3) || s:differ("lnum",2) || s:differ("col",2)
        \ || exists("w:interruptedAnimationAt")
      if s:smooth_scroll(w:oldPosition, w:newPosition)
        return
      endif
    endif
  endif
  let w:oldPosition = w:newPosition
  let w:oldBuffer = w:newBuffer
endfunction

function! s:differ(str,amount)
  return abs( w:newPosition[a:str] - w:oldPosition[a:str] ) > a:amount
endfunction

function! s:smooth_scroll(start, end)

  let pi = acos(-1)

  "if g:SexyScroller_Debug
    "echo "Going from ".a:start["topline"]." to ".a:end["topline"]." with lnum from ".a:start["lnum"]." to ".a:end["lnum"]
    "echo "Target offset: ".(a:end["lnum"] - a:end["topline"])
  "endif

  let numLinesToTravel = abs( a:end["lnum"] - a:start["lnum"] )
  let numLinesToScroll = abs( a:end["topline"] - a:start["topline"] )
  let numColumnsToTravel = 0   " abs( a:end["col"] - a:start["col"] )   " No point animating cursor movement because I can't see the cursor during animation!
  let numColumnsToScroll = abs( a:end["leftcol"] - a:start["leftcol"] )
  let timeForCursorMove = g:SexyScroller_CursorTime * s:hypot(numLinesToTravel, numColumnsToTravel)
  let timeForScroll = g:SexyScroller_ScrollTime * s:hypot(numLinesToScroll, numColumnsToScroll)
  let totalTime = max([timeForCursorMove,timeForScroll])
  "let totalTime = timeForCursorMove + timeForScroll

  "if g:SexyScroller_Debug
    "echo "totalTime=".totalTime." cursor=".timeForCursorMove." (".numLinesToTravel.",".numColumnsToTravel.") scroll=".timeForScroll." (".numLinesToScroll.",".numColumnsToScroll.")"
  "endif

  let totalTime = 1.0 * min([g:SexyScroller_MaxTime,max([0,totalTime])])

  if totalTime < 1
    return
  endif

  let startTime = reltime()
  let current = copy(a:end)

  " Because arguments are immutable
  let start = a:start

  " If we have *just* interrupted a previous animation, then we continue from where he left off.
  if exists("w:interruptedAnimationAt")
    let timeSinceInterruption = s:get_ms_since(w:interruptedAnimationAt)
    if g:SexyScroller_Debug
      echo "Checking interrupted animation, timeSince=".float2nr(timeSinceInterruption)." remaining=".float2nr(w:interruptedAnimationTimeRemaining)
    endif
    if timeSinceInterruption < 20
      let start = w:interruptedAnimationFrom
      if g:SexyScroller_Debug
        echo "Continuing interrupted animation with ".float2nr(w:interruptedAnimationTimeRemaining)." remaining, from ".start["topline"]
      endif
      " Secondary keystrokes should not make the animation finish sooner than it would have!
      " But I don't think we should add the times together.
      if totalTime < w:interruptedAnimationTimeRemaining
        let totalTime = w:interruptedAnimationTimeRemaining
      endif
    endif
    unlet w:interruptedAnimationAt
  endif

  while 1

    let elapsed = s:get_ms_since(startTime) + 15
    " GVim is a bit laggy, so +15 renders the position we should be in at the end of the sleep below.
    let thruTime = elapsed * 1.0 / totalTime
    if elapsed >= totalTime
      let thruTime = 1.0
    endif
    if elapsed >= totalTime
      break
    endif

    " Easing
    if g:SexyScroller_EasingStyle == 1
      let thru = cos( 0.5 * pi * (-1.0 + thruTime) )         " fast->slow
    elseif g:SexyScroller_EasingStyle == 2
      let thru = 0.5 + 0.5 * cos( pi * (-1.0 + thruTime) )   " slow->fast->slow
    else
      let thru = thruTime
    endif

    let notThru = 1.0 - thru
    let current["topline"] = float2nr( notThru*start["topline"] + thru*a:end["topline"] + 0.5 )
    let current["leftcol"] = float2nr( notThru*start["leftcol"] + thru*a:end["leftcol"] + 0.5 )
    let current["lnum"] = float2nr( notThru*start["lnum"] + thru*a:end["lnum"] + 0.5 )
    let current["col"] = float2nr( notThru*start["col"] + thru*a:end["col"] + 0.5 )
    "echo "thruTime=".printf('%g',thruTime)." thru=".printf('%g',thru)." notThru=".printf('%g',notThru)." topline=".current["topline"]." leftcol=".current["leftcol"]." lnum=".current["lnum"]." col=".current["col"]

    call winrestview(current)
    redraw

    exec "sleep 15m"

    " Stop the current animation if the user presses a new key.
    " We must jump to the end position, to process the key correctly, but by returning 1 we will not clobber oldPosition.  This means if the pending keys also cause animation, it will continue scrolling from our current position.  Unfortunately it also means if the pending keys do *not* cause animation, we will leave a dirty oldPosition that will cause an unwanted animation later.
    " To avoid that, we could set a time after which oldPosition should be stored without causing an animation.  Or better, work the other way: set oldPosition to a:end, but set temporary 'doingAnimationFrom' and 'doingAnimationAtTime' vars, which can be picked up if another animation key is detected before the timestamp times out.
    " Anyway even when it does "work", the transition from one animation to the next is not very smooth, because the easing function will no doubt start with a different speed from the current speed.  We would need to retain currentSpeed and make a new easing function based on it.
    " For some reason, PageDown does not always trigger a value in getchar(), although { and } do.
    " If we hold a scrolling key down, with easing style 2, we appear to go nowhere until we release.
    " Basically this was an afterthought, and the animation algorithm will need to change if we want to solve it properly.
    if g:SexyScroller_DetectPendingKeys && getchar(1)
      let w:oldPosition = a:end
      let w:interruptedAnimationAt = reltime()
      let w:interruptedAnimationFrom = current
      "let w:interruptedAnimationTimeRemaining = totalTime * notThru   " No because notThru is an eased value
      let w:interruptedAnimationTimeRemaining = totalTime * (1.0 - thruTime)
      "let w:interruptedAnimationTimeRemaining = totalTime - elapsed
      if g:SexyScroller_Debug
        echo "Pending keys detected at ".reltimestr(reltime())." remaining=".float2nr(w:interruptedAnimationTimeRemaining)
      endif
      "let w:oldPosition = current
      " We must set to a:end, to be in the right place to process the next char, whether it is further movement or an edit.
      " Causes flicker without lazyredraw enabled
      set lazyredraw
      call winrestview(a:end)
      "return 1
      return 0
    endif

  endwhile

  call winrestview(a:end)

  return 0

endfunction

function! s:get_ms_since(time)
  let cost = split(reltimestr(reltime(a:time)), '\.')
  return str2nr(cost[0])*1000 + str2nr(cost[1])/1000.0
endfunction

function! s:hypot(x, y)
  "return max([a:x,a:y])
  return float2nr( sqrt(a:x*a:x*1.0 + a:y*a:y*1.0) )
endfunction

function! s:ToggleEnabled()
  let g:SexyScroller_Enabled = !g:SexyScroller_Enabled
  echo "Sexy Scroller is " . ( g:SexyScroller_Enabled ? "en" : "dis" ) . "abled"
endfunction

