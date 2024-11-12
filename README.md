SAME SYNTAX MOTION
===============================================================================
_by Ingo Karkat_

DESCRIPTION
------------------------------------------------------------------------------

Vim offers many different powerful motions to position the cursor, but none
leverages the syntactic analysis of the built-in syntax highlighting.

This plugin provides mappings to jump to the borders and next [count]
occurrences of text parsed as the same syntax as under the cursor. So when
you're in a large block of comments, a quick [y will take you to the
beginning of the comment. The ay and iy text objects will select the
surrounding text that belongs to the same syntax.

### SEE ALSO

### RELATED WORKS

- The SyntaxMotion plugin ([vimscript #2965](http://www.vim.org/scripts/script.php?script_id=2965)) by Dominique Pellé provides very
  similar motions for normal and visual mode, but no operator-pending and text
  objects. It does not skip over contained sub-syntax items and uses same
  color as the distinguishing property.
- textobj-syntax ([vimscript #2716](http://www.vim.org/scripts/script.php?script_id=2716)) provides similar ay and iy text objects,
  but doesn't support a [count] to select multiple.

USAGE
------------------------------------------------------------------------------

    "Same syntax" in the context of the mappings and text objects means all of the
    following:
    1. The same syntax ID is used to highlight the text. Transparent syntax groups
       are ignored.
    2. The stack of syntax items includes the one found under the cursor. When a
       syntax contains other syntaxes (possibly with different highlighting),
       these are included. So when you have escape sequences in a string
       ("foo\<CR>bar"), quoted words in a comment (# a "foo" piece), or keywords
       in a docstring (@author Ernie), the entire text is treated as one syntax
       area, even though there are different-colored pieces inside.
    3. Unhighlighted whitespace between the same syntax items is skipped. So when
       there are multiple keywords in a row (FOO BAR BAZ), they are treated as one
       area, even though the whitespace between them is not covered by the syntax.

    ]y                      Go to [count] next start of the same syntax.
    ]Y                      Go to [count] next end of the same syntax.
    [y                      Go to [count] previous start of the same syntax.
    [Y                      Go to [count] previous end of the same syntax.
                            The 'wrapscan' setting applies.

    ay                      "a syntax" text object, select [count] same syntax
                            areas.
    iy                      "inner syntax" text object, select [count] same syntax
                            areas within the same line. Whitespace around the
                            syntax area is not included. Unhighlighted whitespace
                            delimits same syntax items here, so this selects
                            individual keywords.

INSTALLATION
------------------------------------------------------------------------------

The code is hosted in a Git repo at
    https://github.com/inkarkat/vim-SameSyntaxMotion
You can use your favorite plugin manager, or "git clone" into a directory used
for Vim packages. Releases are on the "stable" branch, the latest unstable
development snapshot on "master".

This script is also packaged as a vimball. If you have the "gunzip"
decompressor in your PATH, simply edit the \*.vmb.gz package in Vim; otherwise,
decompress the archive first, e.g. using WinZip. Inside Vim, install by
sourcing the vimball or via the :UseVimball command.

    vim SameSyntaxMotion*.vmb.gz
    :so %

To uninstall, use the :RmVimball command.

### DEPENDENCIES

- Requires Vim 7.0 or higher.
- Requires the ingo-library.vim plugin ([vimscript #4433](http://www.vim.org/scripts/script.php?script_id=4433)), version 1.044 or
  higher.
- Requires the CountJump plugin ([vimscript #3130](http://www.vim.org/scripts/script.php?script_id=3130)), version 1.90 or higher.

CONFIGURATION
------------------------------------------------------------------------------

For a permanent configuration, put the following commands into your vimrc:

To change the default motion mappings, use:

    let g:SameSyntaxMotion_BeginMapping = 'y'
    let g:SameSyntaxMotion_EndMapping = 'Y'

To also change the [ / ] prefix to something else, follow the instructions for
CountJump-remap-motions.

To change the default text object mappings, use:

    let g:SameSyntaxMotion_TextObjectMapping = 'y'

To also change the a prefix to something else, follow the instructions for
CountJump-remap-text-objects.

LIMITATIONS
------------------------------------------------------------------------------

- Because the algorithm has to sequentially inspect every character's syntax
  groups, movement (especially when there's no additional match and the search
  continues to the buffer's border or wraps around) can be noticeably slow.

### CONTRIBUTING

Report any bugs, send patches, or suggest features via the issue tracker at
https://github.com/inkarkat/vim-SameSyntaxMotion/issues or email (address
below).

HISTORY
------------------------------------------------------------------------------

##### 1.10    12-Nov-2024
- CHG: Highlight group / same color is not considered any longer; only the
  syntax ID itself counts. There's now the SameHighlightMotion.vim plugin for
  moving along pure highlighting, so let's sharpen the focus of this one. In
  practice, this change likely makes no difference in most cases, as syntax
  definitions and colors usually are defined in parallel.

##### 1.01    04-Nov-2018
- CountJump 1.9 renames g:CountJump\_Context to g:CountJump\_TextObjectContext.

__You need to update to CountJump.vim ([vimscript #3130](http://www.vim.org/scripts/script.php?script_id=3130)) version 1.90!__

##### 1.00    03-Dec-2012
- First published version.

##### 0.01    14-Sep-2012
- Started development.

------------------------------------------------------------------------------
Copyright: (C) 2012-2024 Ingo Karkat -
The [VIM LICENSE](http://vimdoc.sourceforge.net/htmldoc/uganda.html#license) applies to this plugin.

Maintainer:     Ingo Karkat &lt;ingo@karkat.de&gt;
