;; Aski v0.17 — indentation rules

;; Block bodies [...]
(block_body "[" @indent.begin "]" @indent.end)

;; Enum declarations (...)
(enum_decl "(" @indent.begin ")" @indent.end)

;; Struct declarations {...}
(struct_decl "{" @indent.begin "}" @indent.end)

;; Trait impl [...[...]]
(trait_impl "[" @indent.begin "]" @indent.end)

;; Trait decl (name [...])
(trait_decl "(" @indent.begin ")" @indent.end)

;; Match body (| ... |)
(match_body "(|" @indent.begin "|)" @indent.end)
(match_expr "(|" @indent.begin "|)" @indent.end)

;; Loop [| ... |]
(loop_stmt "[|" @indent.begin "|]" @indent.end)

;; Iteration {| ... |}
(iteration_stmt "{|" @indent.begin "|}" @indent.end)

;; Nested enum (| ... |)
(nested_enum "(|" @indent.begin "|)" @indent.end)

;; Nested struct {| ... |}
(nested_struct "{|" @indent.begin "|}" @indent.end)

;; FFI block (| ... |)
(ffi_block "(|" @indent.begin "|)" @indent.end)

;; Process block [| ... |]
(process_block "[|" @indent.begin "|]" @indent.end)

;; Block expressions [...]
(block_expr "[" @indent.begin "]" @indent.end)
