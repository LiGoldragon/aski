;; Aski v0.17 — scope and local variable tracking

;; =============================================================
;; Scopes
;; =============================================================

(block_body) @local.scope
(match_body) @local.scope
(method_def) @local.scope
(trait_impl) @local.scope
(process_block) @local.scope

;; =============================================================
;; Definitions
;; =============================================================

(instance_stmt (instance_ref) @local.definition)
(mutation_stmt (mutable_ref) @local.definition)
(param (instance_ref) @local.definition)
(param (borrow_ref) @local.definition)
(param (mutable_ref) @local.definition)

;; =============================================================
;; References
;; =============================================================

(instance_ref) @local.reference
(self_ref) @local.reference
(borrow_ref) @local.reference
(mutable_ref) @local.reference
