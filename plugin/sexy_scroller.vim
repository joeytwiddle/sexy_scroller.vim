" smooth_scroller.vim by joeytwiddle
" Inspired by smooth_scroll.vim by Terry Ma

if !has("float")
  echo "smooth_scroller requires the +float feature, which is missing"
  finish
endif

let w:oldState = winsaveview()

augroup Smooth_Scroller
  autocmd!
  autocmd CursorMoved * call s:CheckForJump()
augroup END

function! s:CheckForJump()
  let w:newState = winsaveview()
  if exists("w:oldState")
    " TODO: Do not act if we have just changed buffer, or window size, etc. etc.
    if s:differ("topline") || s:differ("leftcol") || s:differ("lnum") || s:differ("col")
      call s:smooth_scroll(w:oldState, w:newState)
    endif
  endif
  let w:oldState = w:newState
endfunction

function! s:differ(str)
  return abs( w:newState[a:str] - w:oldState[a:str] ) > 1
endfunction

function! s:smooth_scroll(start, end)
  let pi = acos(-1)
  "echo "Going from ".a:start["topline"]." to ".a:end["topline"]." with lnum from ".a:start["lnum"]." to ".a:end["lnum"]
  echo "Target offset: ".(a:end["lnum"] - a:end["topline"])
  "redraw
  let startTime = reltime()
  "let totalTime = 300.0   " MUST BE A FLOAT!
  let minTimePerLine = 20.0
  let numLinesToTravel = abs( a:end["lnum"] - a:start["lnum"] )
  let numLinesToScroll = abs( a:end["topline"] - a:start["topline"] )
  let useLinesToTravel = max([numLinesToTravel,numLinesToScroll]) * 1.0
  let timeWeShouldTake = minTimePerLine * useLinesToTravel
  "echo printf('%g',numLinesToTravel)." lines will take ".printf('%g',timeWeShouldTake)."ms"
  let totalTime = timeWeShouldTake
  if totalTime > 500.0
    let totalTime = 500.0
  endif
  if totalTime < 1.0
    let totalTime = 1.0
  endif
  let current = copy(a:start)
  while 1
    let elapsed = s:get_ms_since(startTime)
    let thruTime = elapsed * 1.0 / totalTime
    if elapsed >= totalTime
      let thruTime = 1.0
    endif
    " Easing
    let thru = 0.5 - 0.5 * cos(pi * thruTime)
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

