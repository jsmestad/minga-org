; Org-mode injection query for code blocks.
;
; Injects language-specific highlighting into #+BEGIN_SRC blocks.
; The language is extracted from the block's parameter field:
;
;   #+BEGIN_SRC elixir
;   defmodule Foo do
;     ...
;   end
;   #+END_SRC
;
; Here, name="SRC" and parameter="elixir". The parameter value is
; matched case-insensitively against Minga's compiled-in grammars.

(block
  name: (expr) @_block_name
  parameter: (expr) @injection.language
  (contents) @injection.content
  (#any-of? @_block_name "SRC" "src" "Src"))
