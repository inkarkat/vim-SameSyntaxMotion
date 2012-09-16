" SameSyntaxMotion.vim: Motions to the borders of the same syntax highlighting.
"
" DEPENDENCIES:
"   - CountJump.vim autoload script, version 1.80 or higher
"
" Copyright: (C) 2012 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"	005	16-Sep-2012	Optimization: Speed up iteration by performing
"				the synID()-lookup only once on each position
"				and by caching the result of the
"				synstack()-search for each current synID. Even
"				though this contributed only 40% to the runtime
"				(the other 40% is for synID(), 10% for the
"				searchpos()), it somehow also reduces the time
"				for synID() lookups dramatically.
"	004	15-Sep-2012	Replace s:Jump() with generic implementation by
"				CountJump, CountJump#CountJumpFunc().
"	003	14-Sep-2012	Implement text object. Factor out s:Jump() to
"				allow passing in the original syntaxId and
"				hlgroupId; it may be different at the text
"				object begin and therefore may adulterate the
"				end match.
"	002	13-Sep-2012	Implement the full set of the four begin/end
"				forward/backward mappings.
"				Implement skipping over unhighlighted
"				whitespace when its surrounded by the same
"				syntax area on both sides.
"				Handle situations where due to :syntax hs=s+1 or
"				contained groups (like vimCommentTitle contained
"				in vimLineComment) the same highlighting may
"				start only later in the syntax area, while still
"				skipping over contained "subsyntaxes" (like that
"				quote here) inside the syntax area.
"	001	12-Sep-2012	file creation
let s:save_cpo = &cpo
set cpo&vim

function! s:GetHlgroupId( synID )
    return synIDtrans(a:synID)
endfunction
function! s:GetCurrentSyntaxAndHlgroupIds()
    let l:currentSyntaxId = synID(line('.'), col('.'), 1)
    return [l:currentSyntaxId, s:GetHlgroupId(l:currentSyntaxId)]
endfunction
function! s:IsSynIDHere( line, col, synID, currentSyntaxId, synstackCache )
    if ! has_key(a:synstackCache, a:currentSyntaxId)
	let a:synstackCache[a:currentSyntaxId] = (index(synstack(a:line, a:col), a:synID) != -1)
    endif
    return a:synstackCache[a:currentSyntaxId]
endfunction
function! s:IsWithoutHighlighting( synID )
    return empty(
    \   filter(
    \       map(['fg', 'bg', 'sp'], 'synIDattr(a:synID, "v:val")'),
    \       '! empty(v:val)'
    \   )
    \)
endfunction
function! s:IsUnhighlightedWhitespaceHere( line, currentSyntaxId )
    if search('\%#\s', 'cnW', a:line) == 0
	" No whitespace under the cursor.
	return 0
    endif

    if synIDtrans(a:currentSyntaxId) == 0
	" No effective syntax group here.
	return 1
    endif

    if s:IsWithoutHighlighting(a:currentSyntaxId)
	" The syntax group has no highlighting defined.
	return 1
    endif

    return 0
endfunction
function! SameSyntaxMotion#SearchFirstOfSynID( flags, synID, hlgroupId )
    let l:originalPosition = getpos('.')[1:2]
    let l:hasLeft = 0
    let l:synstackCache = {}

    while 1
	let l:matchPosition = searchpos('.', a:flags.'W')
	if l:matchPosition == [0, 0]
	    " We've arrived at the buffer's border.
	    call setpos('.', [0] + l:originalPosition + [0])
	    return l:matchPosition
	endif

	let [l:currentSyntaxId, l:currentHlgroupId] = s:GetCurrentSyntaxAndHlgroupIds()
	if l:currentHlgroupId == a:hlgroupId
	    " We're still / again inside the same-colored syntax area.
	    if l:hasLeft
		" We've found a place in the next syntax area with the same
		" color.
		return l:matchPosition
	    endif
	elseif s:IsSynIDHere(l:matchPosition[0], l:matchPosition[1], a:synID, l:currentSyntaxId, l:synstackCache)
	    " We're still / again inside the syntax area.
	    " Progress until we also find the desired color in this syntax area.
	elseif s:IsUnhighlightedWhitespaceHere(l:matchPosition[0], l:currentSyntaxId)
	    " Tentatively progress; the same syntax area may continue after the
	    " plain whitespace. But if it doesn't, we do not include the
	    " whitespace.
	else
	    " We've just left the syntax area.
	    let l:hasLeft = 1
	    " Keep on searching for the next syntax area.
	endif
    endwhile
endfunction
function! SameSyntaxMotion#SearchLastOfSynID( flags, synID, hlgroupId )
    let l:originalPosition = getpos('.')[1:2]
    let l:goodPosition = [0, 0]
    let l:synstackCache = {}

    while 1
	let l:matchPosition = searchpos('.', a:flags.'W')
	if l:matchPosition == [0, 0]
	    " We've arrived at the buffer's border.
	    break
	endif

	let [l:currentSyntaxId, l:currentHlgroupId] = s:GetCurrentSyntaxAndHlgroupIds()
	if l:currentHlgroupId == a:hlgroupId
	    " We're still / again inside the same-colored syntax area.
	    let l:goodPosition = l:matchPosition
	elseif s:IsSynIDHere(l:matchPosition[0], l:matchPosition[1], a:synID, l:currentSyntaxId, l:synstackCache)
	    " We're still inside the syntax area.
	    " Tentatively progress; we may again find the desired color in this
	    " syntax area.
	elseif s:IsUnhighlightedWhitespaceHere(l:matchPosition[0], l:currentSyntaxId)
	    " Tentatively progress; the same syntax area may continue after the
	    " plain whitespace. But if it doesn't, we do not include the
	    " whitespace.
	elseif l:goodPosition != [0, 0]
	    " We've just left the syntax area.
	    break
	endif
	" Keep on searching for the next syntax area.
    endwhile

    call setpos('.', [0] + (l:goodPosition == [0, 0] ? l:originalPosition : l:goodPosition) + [0])
    return l:goodPosition
endfunction
function! SameSyntaxMotion#Jump( count, SearchFunction, isBackward )
    let [l:currentSyntaxId, l:currentHlgroupId] = s:GetCurrentSyntaxAndHlgroupIds()
    return  CountJump#CountJumpFunc(a:count, a:SearchFunction, (a:isBackward ? 'b' : ''), l:currentSyntaxId, l:currentHlgroupId)
endfunction

function! SameSyntaxMotion#BeginForward( mode )
    call CountJump#JumpFunc(a:mode, function('SameSyntaxMotion#Jump'), function('SameSyntaxMotion#SearchFirstOfSynID'), 0)
endfunction
function! SameSyntaxMotion#BeginBackward( mode )
    call CountJump#JumpFunc(a:mode, function('SameSyntaxMotion#Jump'), function('SameSyntaxMotion#SearchLastOfSynID'), 1)
endfunction
function! SameSyntaxMotion#EndForward( mode )
    call CountJump#JumpFunc(a:mode, function('SameSyntaxMotion#Jump'), function('SameSyntaxMotion#SearchLastOfSynID'), 0)
endfunction
function! SameSyntaxMotion#EndBackward( mode )
    call CountJump#JumpFunc(a:mode, function('SameSyntaxMotion#Jump'), function('SameSyntaxMotion#SearchFirstOfSynID'), 1)
endfunction

function! SameSyntaxMotion#TextObjectBegin( count, isInner )
    let [g:CountJump_Context.syntaxId, g:CountJump_Context.hlgroupId] = s:GetCurrentSyntaxAndHlgroupIds()

    " Move one character to the right, so that we do not jump to the previous
    " syntax area when we're at the start of a syntax area. CountJump will
    " restore the original cursor position should there be no proper text
    " object.
    call search('.', 'W')

    return CountJump#CountJumpFunc(a:count, function('SameSyntaxMotion#SearchLastOfSynID'), 'b', g:CountJump_Context.syntaxId, g:CountJump_Context.hlgroupId)
endfunction
function! SameSyntaxMotion#TextObjectEnd( count, isInner )
    return CountJump#CountJumpFunc(a:count, function('SameSyntaxMotion#SearchLastOfSynID'), '' , g:CountJump_Context.syntaxId, g:CountJump_Context.hlgroupId)
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
