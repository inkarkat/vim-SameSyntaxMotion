" SameSyntaxMotion.vim: Motions to the borders of the same syntax highlighting.
"
" DEPENDENCIES:
"   - CountJump.vim plugin
"   - ingo-library.vim plugin
"
" Copyright: (C) 2012-2022 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
let s:save_cpo = &cpo
set cpo&vim

function! s:GetCurrentSyntaxId()
    return synID(line('.'), col('.'), 1)
endfunction
function! s:IsSynIDContainedHere( line, col, synId, currentSyntaxId, synstackCache )
    if ! has_key(a:synstackCache, a:currentSyntaxId)
	let l:synstack = synstack(a:line, a:col)
	let l:synIdIndex = index(l:synstack, a:synId)
	" To be contained in the original syntax (represented by a:synId), that
	" syntax must still be part of the syntax stack and the current syntax
	" must be on top of it.
	" Note: a:currentSyntaxId is guaranteed to be in the syntax stack, no
	" need to check for containment.
	let a:synstackCache[a:currentSyntaxId] = (l:synIdIndex != -1 && index(l:synstack, a:currentSyntaxId) >= l:synIdIndex)
    endif
    return a:synstackCache[a:currentSyntaxId]
endfunction
function! s:IsUnhighlightedWhitespaceHere( currentSyntaxId )
    if ! ingo#cursor#IsOnWhitespace()
	return 0
    endif

    if synIDtrans(a:currentSyntaxId) == 0
	" No effective syntax group here.
	return 1
    endif

    if ! ingo#syntaxitem#HasHighlighting(a:currentSyntaxId)
	" The syntax group has no highlighting defined.
	return 1
    endif

    return 0
endfunction
function! SameSyntaxMotion#SearchFirstOfSynID( synId, flags, isInner )
    let l:isBackward = (a:flags =~# 'b')
    let l:originalPosition = getpos('.')[1:2]
    let l:matchPosition = []
    let l:hasLeft = 0
    let l:synstackCache = {}

    try
	while l:matchPosition != l:originalPosition
	    let l:matchPosition = searchpos('.', a:flags, (a:isInner ? line('.') : 0))
	    if l:matchPosition == [0, 0]
		" We've arrived at the buffer's border.
		call setpos('.', [0] + l:originalPosition + [0])
		return l:matchPosition
	    endif

	    let l:currentSyntaxId = s:GetCurrentSyntaxId()
	    if l:currentSyntaxId == a:synId
		if ! l:isBackward && l:matchPosition == [1, 1] && l:matchPosition != l:originalPosition
		    " This is no circular buffer; text at the buffer start is
		    " separate from the end. Break up the syntax area to correctly
		    " handle matches at both beginning and end of the buffer.
		    let l:hasLeft = 1
		endif

		" We're still / again inside the same syntax area.
		if l:hasLeft
		    " We've found a place in the next syntax area with the same
		    " id.
		    return l:matchPosition
		endif

		if l:isBackward && l:matchPosition == [1, 1]
		    " This is no circular buffer; text at the buffer start is
		    " separate from the end. Break up the syntax area to correctly
		    " handle matches at both beginning and end of the buffer.
		    let l:hasLeft = 1
		endif
	    elseif s:IsSynIDContainedHere(l:matchPosition[0], l:matchPosition[1], a:synId, l:currentSyntaxId, l:synstackCache)
		" We're still / again inside the syntax area.
		" Progress until we also find the desired id in this syntax area.
	    elseif ! a:isInner && s:IsUnhighlightedWhitespaceHere(l:currentSyntaxId)
		" Tentatively progress; the same syntax area may continue after the
		" plain whitespace. But if it doesn't, we do not include the
		" whitespace.
	    else
		" We've just left the syntax area.
		let l:hasLeft = 1
		" Keep on searching for the next syntax area.
	    endif
	endwhile

	" We've wrapped around and arrived at the original position without a match.
	return [0, 0]
    catch /^Vim\%((\a\+)\)\=:/
	call setpos('.', [0] + l:originalPosition + [0])
	throw ingo#msg#MsgFromVimException()   " Avoid E608: Cannot :throw exceptions with 'Vim' prefix.
    endtry
endfunction
function! SameSyntaxMotion#SearchLastOfSynID( synId, flags, isInner )
    let l:flags = a:flags
    let l:originalPosition = getpos('.')[1:2]
    let l:goodPosition = [0, 0]
    let l:matchPosition = []
    let l:synstackCache = {}

    try
	while l:matchPosition != l:originalPosition
	    let l:matchPosition = searchpos('.', l:flags, (a:isInner ? line('.') : 0))
	    if l:matchPosition == [0, 0]
		" We've arrived at the buffer's border.
		break
	    endif

	    let l:currentSyntaxId = s:GetCurrentSyntaxId()
	    if l:currentSyntaxId == a:synId
		if a:isInner && ingo#cursor#IsOnWhitespace()
		    " We don't include whitespace around the syntax area in the
		    " inner jump.
		    continue
		endif

		" We're still / again inside the same syntax area.
		let l:goodPosition = l:matchPosition
		" Go on (without wrapping now!) until we've reached the start of the
		" syntax area.
		let l:flags = substitute(l:flags, '[wW]', '', 'g') . 'W'
	    elseif s:IsSynIDContainedHere(l:matchPosition[0], l:matchPosition[1], a:synId, l:currentSyntaxId, l:synstackCache)
		" We're still inside the syntax area.
		" Tentatively progress; we may again find the desired id in this
		" syntax area.
	    elseif ! a:isInner && s:IsUnhighlightedWhitespaceHere(l:currentSyntaxId)
		" Tentatively progress; the same syntax area may continue after the
		" plain whitespace. But if it doesn't, we do not include the
		" whitespace.
	    elseif l:goodPosition != [0, 0]
		" We've just left the syntax area.
		break
	    endif
	    " Keep on searching for the next syntax area, until we wrap around and
	    " arrive at the original position without a match.
	endwhile

	call setpos('.', [0] + (l:goodPosition == [0, 0] ? l:originalPosition : l:goodPosition) + [0])
	return l:goodPosition
    catch /^Vim\%((\a\+)\)\=:/
	call setpos('.', [0] + l:originalPosition + [0])
	throw ingo#msg#MsgFromVimException()   " Avoid E608: Cannot :throw exceptions with 'Vim' prefix.
    endtry
endfunction
function! SameSyntaxMotion#Jump( count, SearchFunction, isBackward )
    return  CountJump#CountJumpFuncWithWrapMessage(a:count, 'same syntax search', a:isBackward, a:SearchFunction, s:GetCurrentSyntaxId(), (a:isBackward ? 'b' : ''), 0)
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
    let g:CountJump_TextObjectContext.syntaxId = s:GetCurrentSyntaxId()

    " Move one character to the right, so that we do not jump to the previous
    " syntax area when we're at the start of a syntax area. CountJump will
    " restore the original cursor position should there be no proper text
    " object.
    call search('.', 'W')

    return CountJump#CountJumpFunc(a:count, function('SameSyntaxMotion#SearchLastOfSynID'), g:CountJump_TextObjectContext.syntaxId, 'bW', a:isInner)
endfunction
function! SameSyntaxMotion#TextObjectEnd( count, isInner )
    return CountJump#CountJumpFunc(a:count, function('SameSyntaxMotion#SearchLastOfSynID'), g:CountJump_TextObjectContext.syntaxId, 'W' , a:isInner)
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
