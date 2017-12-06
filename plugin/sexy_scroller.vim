

if !has("float")
  echo "smooth_scroller requires the +float feature, which is missing"
  finish
endif



" == Options == "

if !exists("g:SexyScroller_Enabled")
  let g:SexyScroller_Enabled = 1
endif

if !exists("g:SexyScroller_AutocmdsEnabled")
  let g:SexyScroller_AutocmdsEnabled = 1
endif

" We can only really see the cursor moving if 'cursorline' is enabled (or my hiline plugin is running)
if !exists("g:SexyScroller_CursorTime")
  let g:SexyScroller_CursorTime = ( &cursorline || exists("g:hiline") && g:hiline ? 8 : 0 )
endif

" By default, scrolling the buffer is slower then moving the cursor, because a page of text is "heavier" than the cursor.  :)
if !exists("g:SexyScroller_ScrollTime")
  let g:SexyScroller_ScrollTime = 10
endif

if !exists("g:SexyScroller_MaxTime")
  let g:SexyScroller_MaxTime = 200
endif

if !exists("g:SexyScroller_EasingStyle")
  let g:SexyScroller_EasingStyle = 2
endif

if !exists("g:SexyScroller_DetectPendingKeys")
  let g:SexyScroller_DetectPendingKeys = 1
endif

if !exists("g:SexyScroller_MinLines")
  let g:SexyScroller_MinLines = 3
endif

if !exists("g:SexyScroller_MinColumns")
  let g:SexyScroller_MinColumns = 3
endif

if !exists("g:SexyScroller_Debug")
  let g:SexyScroller_Debug = 0
endif

if !exists("g:SexyScroller_DebugInterruption")
  let g:SexyScroller_DebugInterruption = 0
endif

if !exists("g:SexyScroller_Disabled_FileTypes")
  let g:SexyScroller_Disabled_FileTypes = ['unite']
endif


" == Setup == "

command! SexyScrollerToggle call s:ToggleEnabled()

augroup Smooth_Scroller
  autocmd!
  " Wrap all commands (as strings) with the cmd wrapper so they can be
  " turned on or off with the g:SexyScroller_AutcmdsEnabled option
  autocmd CursorMoved * call s:AutocmdCmdWrapper("call s:CheckForChange(1)")
  autocmd CursorMovedI * call s:AutocmdCmdWrapper("call s:CheckForChange(1)")
  autocmd InsertLeave * call s:AutocmdCmdWrapper("call s:CheckForChange(0)")
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

" Map some of the z commands similarly.
if maparg("zt", 'n') == ''
  nnoremap <silent> zt zt:call <SID>CheckForChange(0)<CR>
endif
if maparg("zz", 'n') == ''
  nnoremap <silent> zz zz:call <SID>CheckForChange(0)<CR>
endif
if maparg("zb", 'n') == ''
  nnoremap <silent> zb zb:call <SID>CheckForChange(0)<CR>
endif



" == Functions == "

" Globally exposed function, so other scripts may call us.
" Checks if the position of the cursor has changed.
" If 0 is passed, it will do nothing, but will register the new position.
" If 1 (or no argument) is passed and the position has changed, it will scroll smoothly to the new position.
function! g:SexyScroller_ScrollToCursor(...)
  let actIfChange = a:0 >= 1 ? a:1 : 1
  call s:CheckForChange(actIfChange)
endfunction

function! s:CheckForChange(actIfChange)
  let w:newPosition = winsaveview()
  let w:newBuffer = bufname('%')
  if a:actIfChange && g:SexyScroller_Enabled
        \ && index(g:SexyScroller_Disabled_FileTypes, &ft) == -1
        \ && exists("w:oldPosition")
        \ && exists("w:oldBuffer") && w:newBuffer==w:oldBuffer "&& mode()=='n'
    if s:differ("topline",g:SexyScroller_MinLines+1) || s:differ("leftcol",g:SexyScroller_MinColumns+1) || s:differ("lnum",g:SexyScroller_MinLines) || s:differ("col",g:SexyScroller_MinColumns)
        \ || exists("w:interruptedAnimationAt")
      if s:smooth_scroll(w:oldPosition, w:newPosition)
        return   " Do not save the new position if the scroll was interrupted
      endif
    endif
  endif
  let w:oldPosition = w:newPosition
  let w:oldBuffer = w:newBuffer
endfunction

function! s:differ(str,amount)
  return abs( w:newPosition[a:str] - w:oldPosition[a:str] ) > a:amount
endfunction

" This used to return 1 if the scroll was interrupted by a keypress, but now that is indicated by setting w:interruptedAnimationAt
function! s:smooth_scroll(start, end)

  let pi = 3.141593

  "if g:SexyScroller_Debug
    "echo "Going from ".a:start["topline"]." to ".a:end["topline"]." with lnum from ".a:start["lnum"]." to ".a:end["lnum"]
    "echo "Target offset: ".(a:end["lnum"] - a:end["topline"])
  "endif

  let numLinesToTravel = abs( a:end["lnum"] - a:start["lnum"] )
  let numLinesToScroll = abs( a:end["topline"] - a:start["topline"] )
  let numColumnsToTravel = 0   " abs( a:end["col"] - a:start["col"] )   " No point animating horizontal cursor movement because I can't see the cursor during animation!
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

  " If we have *just* interrupted a previous animation, then continue from where we left off.
  if exists("w:interruptedAnimationAt")
    let timeSinceInterruption = s:get_ms_since(w:interruptedAnimationAt)
    if g:SexyScroller_DebugInterruption
      echo "Checking interrupted animation, timeSince=".float2nr(timeSinceInterruption)." remaining=".float2nr(w:interruptedAnimationTimeRemaining)
    endif
    if timeSinceInterruption < 50
      let start = w:interruptedAnimationFrom
      if g:SexyScroller_DebugInterruption
        echo "Continuing interrupted animation with ".float2nr(w:interruptedAnimationTimeRemaining)." remaining, from ".start["topline"]
      endif
      " Secondary keystrokes should not make the animation finish sooner than it would have!
      if totalTime < w:interruptedAnimationTimeRemaining
        let totalTime = w:interruptedAnimationTimeRemaining
      endif
      " We could add the times together.  Not sure how I feel about this.
      "let totalTime = 1.0 * min([g:SexyScroller_MaxTime,float2nr(totalTime + w:interruptedAnimationTimeRemaining)])
    endif
    unlet w:interruptedAnimationAt
  endif

  " Although we did this check earlier in CheckForChange, this function can also be called if w:interruptedAnimationAt is set, and it may sometimes be called unneccessarily, when we are already right next to the destination!  (Without checking, this would cause motion to slow down when I am holding a direction with a very fast keyboard repeat set.  To reproduce, hold keys near a long wrapped line or some folded lines, and you will see interruptedAnimationAt keeps firing.)
  if numLinesToTravel<g:SexyScroller_MinLines && numLinesToScroll<g:SexyScroller_MinLines && numColumnsToTravel<g:SexyScroller_MinColumns && numColumnsToScroll<g:SexyScroller_MinColumns
    return
  endif

  if g:SexyScroller_Debug
    echo "Travelling ".numLinesToTravel."/".numLinesToScroll." over ".float2nr(totalTime)."ms"
  endif

  while 1

    let elapsed = s:get_ms_since(startTime) + 8
    " +8 renders the position we should be in half way through the sleep 15m below.
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
      let c    = cos( 0.5 * pi * (-1.0 + thruTime) )
      let thru = sqrt(sqrt(c))                               " very fast -> very slow
    elseif g:SexyScroller_EasingStyle == 3
      let thru = 0.5 + 0.5 * cos( pi * (-1.0 + thruTime) )   " slow -> fast -> slow
    elseif g:SexyScroller_EasingStyle == 4
      let cpre = cos( pi * (-1.0 + thruTime) )
      let thru = 0.5 + 0.5 * sqrt(sqrt(abs(cpre))) * ( cpre > 0 ? +1 : -1 )    " very slow -> very fast -> very slow
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

    " Break out of the current animation if the user presses a new key.
    " Set some vars so that we can resume this animation from where it was interrupted, if the pending keys trigger further motion.
    " If they don't trigger another motion, the animation will simply jump to the destination.
    if g:SexyScroller_DetectPendingKeys && getchar(1)
      let w:oldPosition = a:end
      let w:interruptedAnimationAt = reltime()
      let w:interruptedAnimationFrom = current
      let w:interruptedAnimationTimeRemaining = totalTime * (1.0 - thruTime)
      if g:SexyScroller_DebugInterruption
        echo "Pending keys detected at ".reltimestr(reltime())." remaining=".float2nr(w:interruptedAnimationTimeRemaining)
      endif
      " We must now jump to a:end, to be in the right place to process the next keypress, regardless whether it is a movement or edit command.
      " If we do end up resuming this animation, this winrestview will cause flicker, unless we set lazyredraw to prevent it.
      set lazyredraw
      call winrestview(a:end)
      return 0
      " Old approach:
      "let w:oldPosition = current
      "return 1
    endif

  endwhile

  call winrestview(a:end)

  return 0

endfunction

function! s:get_ms_since(time)   " Ta Ter
  let cost = split(reltimestr(reltime(a:time)), '\.')
  return str2nr(cost[0])*1000 + str2nr(cost[1])/1000.0
endfunction

function! s:hypot(x, y)
  "return max([a:x,a:y])
  return float2nr( sqrt(1.0*a:x*a:x + 1.0*a:y*a:y) )
endfunction

function! s:ToggleEnabled()
  let g:SexyScroller_Enabled = !g:SexyScroller_Enabled
  echo "Sexy Scroller is " . ( g:SexyScroller_Enabled ? "en" : "dis" ) . "abled"
endfunction

" Conditionally run a command
function! s:AutocmdCmdWrapper(cmd)
    if g:SexyScroller_AutocmdsEnabled == 1
        execute a:cmd
    endif
endfunction




" vim: wrap textwidth=0 wrapmargin=0
