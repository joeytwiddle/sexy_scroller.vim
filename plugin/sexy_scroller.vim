" sexy_scroller.vim - Smooth animation of the cursor and the page whenever they move, with easing
" By joeytwiddle, inspired by Terry Ma's smooth_scroll.vim

" Options:
"
" Set the number of milliseconds to move the cursor one line:
"
"   let g:SexyScroller_CursorTime = 5
"
" or set it to 0 to never scroll the cursor.
"
" Set the number of milliseconds to scroll the buffer one line:
"
"   let g:SexyScroller_ScrollTime = 10
"
" Set the maximum time for long scrolls.
"
"   let g:SexyScroller_MaxTime = 500
"
" Power users may want this a little lower.
"
" Set the easing style:
"
"   let g:SexyScroller_EasingStyle = 1
"
" where 1 = start fast, end slow
"       2 = start slow, get faster, end slow
"       3 = constant
"
" For eye candy, set MaxTime to 1200 and EasingStyle to 2
" Power users may prefer MaxTime a little lower, and EasingStyle 1 or 3

" ISSUES:
"
" - It looks odd after you perform a `/` search with 'incsearch' because Vim has already taken us to the target line.  At the end we jump back to where we started, and then scroll forwards to the target!  There is no event hook to handle this.
"
" - I have disabled smooth horizontal animation of the cursor because I cannot see the cursor moving, even with 'cursorcolumn' enabled, so it's pointless!  In fact the cursor is also invisible durinv vertical scrolling, but 'cursorline' can show the cursor line moving.
"
" - If more movement actions are keyed whilst we are still scrolling (e.g. hit PageDown 10 times), these will each be animated separately.  Even without easing, a small pause is noticeable between animations.  Ideally after a keystroke, we would re-target the final destination.  getchar() may be of use here.
"
" - The cursor animates after a mouse click, which does not seem quite right.
"
" - Although we have mapped |CTRL-E| and |CTRL-Y| we have not yet handled the z commands under |scroll-cursor|.  They are hard to map and do not fire any events.  An undesired animation will eventually fire when the cursor moves.
"
" - Resizing the window may cause the cursor to move but CursorMoved will not be fired until later.
"
" TODO: This is very nice as a general purpose page scroller, but does not handle cursor scrolling very well.  It works on my setup, which uses cursorline, but users without cursorline may not see the cursor animating.  If we *really* want to achieve this, we could fire keyboard events instead of calling winrestview when the cursor should scroll but not the page.  (I.e. winrestview(a:start) followed by a bunch of movement actions (perhaps through feedkeys), following by winrestview(a:end) just to make sure.)
"
" TODO: We should store/reset lazyredraw if we are going to continue to clobber it.

finish

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
  let g:SexyScroller_DetectPendingKeys = 0
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
  " BufferScrolled, but Vim does not fire enough events for us to hook to!
augroup END

" |CTRL-E| and |CTRL-Y| do not fire any events for us to detect, but they do scroll the window.
if maparg("<C-E>", 'n') == ""
  nnoremap <silent> <C-E> <C-E>:call <SID>CheckForChange(1)<CR>
endif
if maparg("<C-Y>", 'n') == ""
  nnoremap <silent> <C-Y> <C-Y>:call <SID>CheckForChange(1)<CR>
endif
" CONSIDER: We could let the user provide a list of other key mappings for which we want CheckForChange to run afterwards.  Alternatively, if he has custom mappings, he could just add a non-movement movement to them, to generate a CursorMoved event.
" TODO: Make a list of exclude keys, and map them so that they set w:SS_Ignore_Next_Movement .  For example this would apply to / and ? with 'hlsearch' enabled, and maybe also to d.

function! s:CheckForChange(actIfChange)
  let w:newPosition = winsaveview()
  let w:newBuffer = bufname('%')
  if a:actIfChange && g:SexyScroller_Enabled
        \ && exists("w:oldPosition")
        \ && exists("w:oldBuffer") && w:newBuffer==w:oldBuffer "&& mode()=='n'
    if s:differ("topline",3) || s:differ("leftcol",3) || s:differ("lnum",2) || s:differ("col",2)
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

  if g:SexyScroller_Debug
    "echo "totalTime=".totalTime." cursor=".timeForCursorMove." (".numLinesToTravel.",".numColumnsToTravel.") scroll=".timeForScroll." (".numLinesToScroll.",".numColumnsToScroll.")"
  endif

  let totalTime = 1.0 * min([g:SexyScroller_MaxTime,max([0,totalTime])])

  if totalTime < 1
    return
  endif

  let startTime = reltime()
  let current = copy(a:end)

  while 1

    let elapsed = s:get_ms_since(startTime)
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
    let current["topline"] = float2nr( notThru*a:start["topline"] + thru*a:end["topline"] + 0.5 )
    let current["leftcol"] = float2nr( notThru*a:start["leftcol"] + thru*a:end["leftcol"] + 0.5 )
    let current["lnum"] = float2nr( notThru*a:start["lnum"] + thru*a:end["lnum"] + 0.5 )
    let current["col"] = float2nr( notThru*a:start["col"] + thru*a:end["col"] + 0.5 )
    "echo "thruTime=".printf('%g',thruTime)." thru=".printf('%g',thru)." notThru=".printf('%g',notThru)." topline=".current["topline"]." leftcol=".current["leftcol"]." lnum=".current["lnum"]." col=".current["col"]

    call winrestview(current)
    redraw

    exec "sleep 15m"

    " Stop the current animation if the user presses a new key.
    " We jump to the end position, but by returning 1 we will not clobber oldPosition.  This means if the pending keys also cause animation, it will continue scrolling from our current position.  Unfortunately it also means if the pending keys do *not* cause animation, we will leave a dirty oldPosition that will cause an unwanted animation later.
    " To avoid that, we could set a time after which oldPosition should be stored without causing an animation.
    " Anyway even when it does "work", the transition from one animation to the next is not very smooth, because the easing function will no doubt start with a different speed from the current speed.  We would need to retain currentSpeed and make a new easing function based on it.
    " For some reason, PageDown does not always trigger a value in getchar(), although { and } do.
    " If we hold a scrolling key down, with easing style 2, we appear to go nowhere until we release.
    " Basically this was an afterthought, and the animation algorithm will need to change if we want to solve it properly.
    if g:SexyScroller_DetectPendingKeys && getchar(1)
      if g:SexyScroller_Debug
        echo "Pending keys detected at ".reltimestr(reltime())
      endif
      let w:oldPosition = current
      " We must set to a:end, to be in the right place to process the next char, whether it is further movement or an edit.
      " Causes flicker without lazyredraw enabled
      set lazyredraw
      call winrestview(a:end)
      return 1
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

