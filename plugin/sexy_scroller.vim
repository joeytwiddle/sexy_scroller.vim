" sexy_scroller.vim - Smooth animation of the cursor and the page whenever they move
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
" Power users may want this a little lower.  Set it higher for eye candy.
"
" Set the easing style:
"
"   let g:SexyScroller_EasingStyle = 1
"
" where 1 = start fast, end slow
"       2 = start slow, get faster, end slow
"       3 = constant

" ISSUES:
" - It looks odd after you perform a search with 'incsearch' because Vim has already taken us to the target line.  We jump back to where we started, and then scroll forwards to the target!  There is no event hook to handle this.
" - I have disabled smooth horizontal animation of the cursor because I cannot see the cursor moving, even with 'cursorcolumn' enabled, so it's pointless!  In fact the cursor is also invisible durinv vertical scrolling, but 'cursorline' can show the cursor line moving.
" - If more movement actions are keyed whilst we are still scrolling (e.g. hit PageDown 10 times), these will each be animated separately.  Even without easing, a pause is visible between animations.  Ideally after a keystroke, we would re-target the final destination.
" - The cursor animates after a mouse click, which does not seem quite right.
" - Although we have mapped |CTRL-E| and |CTRL-Y| we have not yet handled the z commands under |scroll-cursor|.  They are hard to map and do not fire any events.  An undesired animation will eventually fire when the cursor moves.

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

if !exists("g:SexyScroller_Debug")
  let g:SexyScroller_Debug = 0
endif

command! SexyScrollerToggle call s:ToggleEnabled()

augroup Smooth_Scroller
  autocmd!
  autocmd CursorMoved * call s:CheckForChange(1)
  autocmd InsertLeave * call s:CheckForChange(0)
augroup END

" |CTRL-E| and |CTRL-Y| do not fire any events for us to detect, but they do scroll the window.
if maparg("<C-E>", 'n') == ""
  nnoremap <silent> <C-E> <C-E>:call <SID>CheckForChange(1)<CR>
endif
if maparg("<C-Y>", 'n') == ""
  nnoremap <silent> <C-Y> <C-Y>:call <SID>CheckForChange(1)<CR>
endif

function! s:CheckForChange(actIfChange)
  let w:newPosition = winsaveview()
  let w:newBuffer = bufname('%')
  if a:actIfChange && g:SexyScroller_Enabled
        \ && exists("w:oldPosition")
        \ && exists("w:oldBuffer") && w:newBuffer==w:oldBuffer "&& mode()=='n'
    if s:differ("topline",3) || s:differ("leftcol",3) || s:differ("lnum",2) || s:differ("col",2)
      call s:smooth_scroll(w:oldPosition, w:newPosition)
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
    echo "totalTime=".totalTime." cursor=".timeForCursorMove." (".numLinesToTravel.",".numColumnsToTravel.") scroll=".timeForScroll." (".numLinesToScroll.",".numColumnsToScroll.")"
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
    if elapsed >= totalTime
      break
    endif
    exec "sleep 15m"
  endwhile
  call winrestview(a:end)
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

