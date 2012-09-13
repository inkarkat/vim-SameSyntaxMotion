" SameSyntaxMotion.vim: Motions to the borders of the same syntax highlighting.
"
" DEPENDENCIES:
"
" Copyright: (C) 2012 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
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
function! s:IsSynIDHere( line, col, synID )
    return (index(synstack(a:line, a:col), a:synID) != -1)
endfunction
function! s:IsHlgroupIdHere( line, col, hlgroupId )
    return (s:GetHlgroupId(synID(a:line, a:col, 1)) == a:hlgroupId)
endfunction
function! s:IsWithoutHighlighting( synID )
    return empty(
    \   filter(
    \       map(['fg', 'bg', 'sp'], 'synIDattr(a:synID, "v:val")'),
    \       '! empty(v:val)'
    \   )
    \)
endfunction
function! s:IsUnhighlightedWhitespaceHere( line, col )
    if search('\%#\s', 'cnW', a:line) == 0
	" No whitespace under the cursor.
	return 0
    endif

    let l:synID = synID(a:line, a:col, 1)
    if synIDtrans(l:synID) == 0
	" No effective syntax group here.
	return 1
    endif

    if s:IsWithoutHighlighting(l:synID)
	" The syntax group has no highlighting defined.
	return 1
    endif

    return 0
endfunction
function! s:SearchFirstOfSynID( synID, hlgroupId, flags )
    let l:originalPosition = getpos('.')[1:2]
    let l:hasLeft = 0

    while 1
	let l:matchPosition = searchpos('.', a:flags.'W')
	if l:matchPosition == [0, 0]
	    " We've arrived at the buffer's border.
	    call setpos('.', [0] + l:originalPosition + [0])
	    return l:matchPosition
	elseif s:IsHlgroupIdHere(l:matchPosition[0], l:matchPosition[1], a:hlgroupId)
	    " We're still / again inside the same-colored syntax area.
	    if l:hasLeft
		" We've found a place in the next syntax area with the same
		" color.
		return l:matchPosition
	    endif
	elseif s:IsSynIDHere(l:matchPosition[0], l:matchPosition[1], a:synID)
	    " We're still / again inside the syntax area.
	    " Progress until we also find the desired color in this syntax area.
	elseif s:IsUnhighlightedWhitespaceHere(l:matchPosition[0], l:matchPosition[1])
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
function! s:SearchLastOfSynID( synID, hlgroupId, flags )
    let l:originalPosition = getpos('.')[1:2]
    let l:goodPosition = [0, 0]

    while 1
	let l:matchPosition = searchpos('.', a:flags.'W')
	if l:matchPosition == [0, 0]
	    " We've arrived at the buffer's border.
	    break
	elseif s:IsHlgroupIdHere(l:matchPosition[0], l:matchPosition[1], a:hlgroupId)
	    " We're still / again inside the same-colored syntax area.
	    let l:goodPosition = l:matchPosition
	elseif s:IsSynIDHere(l:matchPosition[0], l:matchPosition[1], a:synID)
	    " We're still inside the syntax area.
	    " Tentatively progress; we may again find the desired color in this
	    " syntax area.
	elseif s:IsUnhighlightedWhitespaceHere(l:matchPosition[0], l:matchPosition[1])
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
function! s:Jump( count, SearchFunction, flags, currentSyntaxId, currentHlgroupId )
    let l:save_view = winsaveview()
"****D echomsg '****' a:currentSyntaxId.':' string(synIDattr(a:currentSyntaxId, 'name')) 'colored in' synIDattr(a:currentHlgroupId, 'name')
    for l:i in range(1, a:count)
	let l:matchPosition = call(a:SearchFunction, [a:currentSyntaxId, a:currentHlgroupId, a:flags])
	if l:matchPosition == [0, 0]
	    if l:i > 1
		" (Due to the count,) we've already moved to an intermediate
		" match. Undo that to behave like the old vi-compatible
		" motions. (Only the ]s motion has different semantics; it obeys
		" the 'wrapscan' setting and stays at the last possible match if
		" the setting is off.)
		call winrestview(l:save_view)
	    endif

	    " Ring the bell to indicate that no further match exists.
	    execute "normal! \<C-\>\<C-n>\<Esc>"

	    return l:matchPosition
	endif
    endfor

    " Open the fold at the final search result. This makes the search work like
    " the built-in motions, and avoids that some visual selections get stuck at
    " a match inside a closed fold.
    normal! zv

    return l:matchPosition
endfunction
function! SameSyntaxMotion#Jump( count, SearchFunction, flags )
    let [l:currentSyntaxId, l:currentHlgroupId] = s:GetCurrentSyntaxAndHlgroupIds()
    return  s:Jump(a:count, a:SearchFunction, a:flags, l:currentSyntaxId, l:currentHlgroupId)
endfunction

function! SameSyntaxMotion#BeginForward( mode )
    call CountJump#JumpFunc(a:mode, function('SameSyntaxMotion#Jump'), function('s:SearchFirstOfSynID'), '')
endfunction
function! SameSyntaxMotion#BeginBackward( mode )
    call CountJump#JumpFunc(a:mode, function('SameSyntaxMotion#Jump'), function('s:SearchLastOfSynID'), 'b')
endfunction
function! SameSyntaxMotion#EndForward( mode )
    call CountJump#JumpFunc(a:mode, function('SameSyntaxMotion#Jump'), function('s:SearchLastOfSynID'), '')
endfunction
function! SameSyntaxMotion#EndBackward( mode )
    call CountJump#JumpFunc(a:mode, function('SameSyntaxMotion#Jump'), function('s:SearchFirstOfSynID'), 'b')
endfunction

function! SameSyntaxMotion#TextObjectBegin( count, isInner )
    let [g:CountJump_Context.syntaxId, g:CountJump_Context.hlgroupId] = s:GetCurrentSyntaxAndHlgroupIds()

    return s:Jump(a:count, function('s:SearchLastOfSynID'), 'b', g:CountJump_Context.syntaxId, g:CountJump_Context.hlgroupId)
endfunction
function! SameSyntaxMotion#TextObjectEnd( count, isInner )
    return s:Jump(a:count, function('s:SearchLastOfSynID'), '' , g:CountJump_Context.syntaxId, g:CountJump_Context.hlgroupId)
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
