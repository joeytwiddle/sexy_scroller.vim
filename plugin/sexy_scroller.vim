" sexy_scroller.vim - Smooth animation of the cursor and the page whenever they move
" By joeytwiddle, inspired by Terry Ma's smooth_scroll.vim

" ISSUES:
" - I have disabled smooth horizontal animation of the cursor because I cannot see the cursor moving, so it's pointless!
" - It looks odd after you perform a search with 'incsearch' because Vim has already taken us to the target line.  We jump back to where we started, and then scroll forwards to the target!  There is no event hook to handle this.

if !has("float")
  echo "smooth_scroller requires the +float feature, which is missing"
  finish
endif

if !exists("g:SexyScroller_CursorTime")
  let g:SexyScroller_CursorTime = 10
endif

if !exists("g:SexyScroller_ScrollTime")
  let g:SexyScroller_ScrollTime = 20
endif

if !exists("g:SexyScroller_MaxTime")
  let g:SexyScroller_MaxTime = 400
endif

if !exists("g:SexyScroller_Debug")
  let g:SexyScroller_Debug = 0
endif

augroup Smooth_Scroller
  autocmd!
  autocmd CursorMoved * call s:CheckForJump()
augroup END

function! s:CheckForJump()
  let w:newPosition = winsaveview()
  let w:newBuffer = bufname('%')
  if exists("w:oldPosition") && exists("w:oldBuffer") && w:newBuffer==w:oldBuffer "&& mode()=='n'
    if s:differ("topline",3) || s:differ("leftcol",3) || s:differ("lnum",2) " || s:differ("col",2)
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
  let minTimePerLine = 20.0
  let numLinesToTravel = abs( a:end["lnum"] - a:start["lnum"] )
  let numLinesToScroll = abs( a:end["topline"] - a:start["topline"] )
  let numColumnsToTravel = 0   " abs( a:end["col"] - a:start["col"] )   " No point easing cursor movement because I can't see the cursor during animation!
  let numColumnsToScroll = abs( a:end["leftcol"] - a:start["leftcol"] )
  let timeForCursorMove = g:SexyScroller_CursorTime * s:hypot(numLinesToTravel, numColumnsToTravel)
  let timeForScroll = g:SexyScroller_ScrollTime * s:hypot(numLinesToScroll, numColumnsToScroll)
  let totalTime = max([timeForCursorMove,timeForScroll])
  "let totalTime = timeForCursorMove + timeForScroll
  if g:SexyScroller_Debug
    "echo printf('%g',numLinesToTravel)." lines will take ".printf('%g',totalTime)."ms"
    echo "cursor=".timeForCursorMove." (".numLinesToTravel.",".numColumnsToTravel.") scroll=".timeForScroll." (".numLinesToScroll.",".numColumnsToScroll.")"
  endif
  let totalTime = 1.0 * min([g:SexyScroller_MaxTime,max([0,totalTime])])

  if totalTime < 1
    return
  endif

  let startTime = reltime()
  let current = copy(a:start)
  while 1
    let elapsed = s:get_ms_since(startTime)
    let thruTime = elapsed * 1.0 / totalTime
    if elapsed >= totalTime
      let thruTime = 1.0
    endif
    " Easing
    let thru = 0.5 + 0.5 * cos( pi * 1.0 / 2.0 * (-1 + thruTime) )
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

