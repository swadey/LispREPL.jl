LispREPL.jl: A REPL for LispSyntax.jl
===============================

[![Join the chat at https://gitter.im/swadey/Lisp.jl](https://badges.gitter.im/swadey/Lisp.jl.svg)](https://gitter.im/swadey/Lisp.jl?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)
![Build Status](https://travis-ci.org/swadey/LispREPL.jl.svg?branch=master)

This package provides REPL functionality with Lisp syntax on top of julia.  This is really Michael Hatherly's contribution factored out of LispSyntax.jl.

## Usage

The lisp REPL mode is entered using the `)` key in a same way as other REPL modes such as
help (`?`) and shell (`;`). Unlike those modes the lisp mode is "sticky". After pressing
return to evaluate the current line the mode will *not* switch back to the `julia>` mode,
but instead will remain in lisp mode. To return to Julia mode press backspace.

## Customization

The lisp mode prompt text and color may be set via your `ENV` settings. For example adding
the following to your `.bashrc` (or equivalent) file

```bash
export LISP_PROMPT_TEXT="λ "
export LISP_PROMPT_COLOR="red"
```

will set the prompt for lisp mode to a red lambda.
