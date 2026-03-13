; Org-mode highlight query for Minga
; Maps org-mode tree-sitter nodes to standard capture names.

; Headlines: stars get keyword styling, headline text gets function styling
(headline (stars) @keyword (item) @function)

; TODO/DONE keywords
(item . (expr) @keyword (#eq? @keyword "TODO"))
(item . (expr) @string (#eq? @string "DONE"))

; Priority cookies [#A], [#B], etc.
(item . (expr)? . (expr "[" "#" @constant [ "num" "str" ] @constant "]"))

; Tags
(tag_list (tag) @tag)

; Properties
(property_drawer) @comment
(property name: (expr) @tag (value)? @string)

; Timestamps
(timestamp "<" (day)? @number (date)? @number (time)? @number (repeat)? @operator (delay)? @operator) @string
(timestamp "[") @comment

; Footnotes
(fndef label: (expr) @tag (description) @variable)

; Directives (#+TITLE:, #+BEGIN_SRC, etc.)
(directive name: (expr) @keyword (value)? @string)

; Comments
(comment) @comment

; Drawers
(drawer name: (expr) @keyword (contents)? @comment)

; Code blocks
(block name: (expr) @keyword (contents)? @string)
(dynamic_block name: (expr) @keyword (contents)? @variable)

; Lists
(bullet) @punctuation

; Checkboxes
(checkbox) @punctuation
(checkbox status: (expr "-") @operator)
(checkbox status: (expr "str") @constant (#any-of? @constant "x" "X"))

; Table horizontal rulers
(hr) @punctuation
