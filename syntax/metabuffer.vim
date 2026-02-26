if exists('b:current_syntax')
  finish
endif
let b:current_syntax = 'metabuffer'

highlight default link MetaPrompt Identifier
syntax match MetaPrompt /^#.*/
