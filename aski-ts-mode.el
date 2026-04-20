;;; aski-ts-mode.el --- Tree-sitter mode for aski -*- lexical-binding: t; -*-

;; Author: Li
;; Version: 0.17.0
;; Keywords: languages
;; Package-Requires: ((emacs "29.1"))

;;; Commentary:
;; Tree-sitter powered major mode for .aski files (v0.17).
;; Requires the tree-sitter-aski grammar to be installed.
;;
;; Install grammar: M-x treesit-install-language-grammar RET aski
;; Or via Nix: packages.tree-sitter-aski

;;; Code:

(require 'treesit)

(defgroup aski-ts nil
  "Tree-sitter mode for aski."
  :group 'languages)

(defcustom aski-ts-mode-indent-offset 2
  "Number of spaces for each indentation step in `aski-ts-mode'."
  :type 'integer
  :group 'aski-ts)

;; Grammar source for treesit-install-language-grammar
(add-to-list 'treesit-language-source-alist
             '(aski "https://github.com/Criome/aski" nil "tree-sitter-aski/src"))

;; ── Font-lock — v0.17 node types ──

(defvar aski-ts-mode--font-lock-settings
  (treesit-font-lock-rules
   :language 'aski
   :feature 'comment
   '((comment) @font-lock-comment-face)

   :language 'aski
   :feature 'string
   '((string_literal) @font-lock-string-face
     (string_content) @font-lock-string-face
     (string_escape) @font-lock-escape-face)

   :language 'aski
   :feature 'number
   '((integer_literal) @font-lock-number-face
     (float_literal) @font-lock-number-face)

   :language 'aski
   :feature 'constant
   :override t
   '(;; Const declarations
     (const_decl name: (type_identifier) @font-lock-constant-face)
     ;; Enum variants
     (bare_variant (type_identifier) @font-lock-constant-face)
     (data_variant name: (type_identifier) @font-lock-constant-face)
     (struct_variant name: (type_identifier) @font-lock-constant-face)
     ;; Match patterns
     (variant_pattern (type_identifier) @font-lock-constant-face)
     (or_pattern (type_identifier) @font-lock-constant-face)
     (destructure_pattern (type_identifier) @font-lock-constant-face))

   :language 'aski
   :feature 'keyword
   :override t
   '(;; ^ early return — keyword face, control flow
     (early_return "^" @font-lock-keyword-face)
     ;; ? try-unwrap — keyword face, control flow
     (try_expr "?" @font-lock-keyword-face)
     ;; (| |) match delimiters — keyword face
     (match_body "(|" @font-lock-keyword-face)
     (match_body "|)" @font-lock-keyword-face)
     (match_expr "(|" @font-lock-keyword-face)
     (match_expr "|)" @font-lock-keyword-face)
     ;; [| |] loop delimiters
     (loop_stmt "[|" @font-lock-keyword-face)
     (loop_stmt "|]" @font-lock-keyword-face)
     ;; {| |} iteration delimiters
     (iteration_stmt "{|" @font-lock-keyword-face)
     (iteration_stmt "|}" @font-lock-keyword-face)
     ;; [| |] iteration body delimiters
     (iteration_body "[|" @font-lock-keyword-face)
     (iteration_body "|]" @font-lock-keyword-face)
     ;; or-pattern pipe
     (or_pattern "|" @font-lock-keyword-face)
     ;; FFI block delimiters
     (ffi_block "(|" @font-lock-keyword-face)
     (ffi_block "|)" @font-lock-keyword-face)
     ;; Process block delimiters
     (process_block "[|" @font-lock-keyword-face)
     (process_block "|]" @font-lock-keyword-face))

   :language 'aski
   :feature 'type
   '((type_identifier) @font-lock-type-face
     (generic_param) @font-lock-type-face
     (type_application
       constructor: (type_identifier) @font-lock-type-face))

   :language 'aski
   :feature 'definition
   :override t
   '(;; Module name — use function-name-face to distinguish from exports
     (module_decl name: (type_identifier) @font-lock-function-name-face)
     ;; Module exports — type-face (they ARE types being exported)
     (module_export (type_identifier) @font-lock-type-face)
     (module_export (identifier) @font-lock-function-name-face)
     ;; Enum name
     (enum_decl name: (type_identifier) @font-lock-preprocessor-face)
     ;; Struct name
     (struct_decl name: (type_identifier) @font-lock-variable-name-face)
     ;; Newtype name
     (newtype_decl name: (type_identifier) @font-lock-preprocessor-face)
     ;; Nested domain names
     (nested_enum name: (type_identifier) @font-lock-preprocessor-face)
     (nested_struct name: (type_identifier) @font-lock-variable-name-face)
     ;; Trait declaration name
     (trait_decl name: (identifier) @font-lock-function-name-face)
     ;; Trait impl name
     (trait_impl trait_name: (identifier) @font-lock-function-name-face))

   :language 'aski
   :feature 'builtin
   :override t
   '((stdout_stmt "StdOut" @font-lock-builtin-face)
     (stderr_stmt "StdErr" @font-lock-builtin-face)
     (self_ref) @font-lock-builtin-face)

   :language 'aski
   :feature 'function
   '(;; Method definitions
     (method_def name: (identifier) @font-lock-function-name-face)
     ;; Signature methods
     (signature name: (identifier) @font-lock-function-name-face)
     ;; FFI functions
     (ffi_function name: (identifier) @font-lock-function-name-face))

   :language 'aski
   :feature 'property
   '(;; Struct field declarations
     (typed_field name: (type_identifier) @font-lock-property-name-face)
     (self_typed_field (type_identifier) @font-lock-property-name-face))

   :language 'aski
   :feature 'variable
   '(;; Instance references
     (instance_ref) @font-lock-variable-use-face
     ;; Instance statement definitions
     (instance_stmt (instance_ref) @font-lock-variable-name-face)
     ;; Mutation definitions
     (mutation_stmt (mutable_ref) @font-lock-variable-name-face)
     ;; Parameters
     (param (instance_ref) @font-lock-variable-name-face)
     (sig_param (instance_ref) @font-lock-variable-name-face)
     (ffi_param (instance_ref) @font-lock-variable-name-face))

   :language 'aski
   :feature 'operator
   :override t
   '(;; Arithmetic / comparison operators
     (binary_expr "+" @font-lock-operator-face)
     (binary_expr "-" @font-lock-operator-face)
     (binary_expr "*" @font-lock-operator-face)
     (binary_expr "%" @font-lock-operator-face)
     (binary_expr "==" @font-lock-operator-face)
     (binary_expr "!=" @font-lock-operator-face)
     (binary_expr "<" @font-lock-operator-face)
     (binary_expr ">" @font-lock-operator-face)
     (binary_expr "<=" @font-lock-operator-face)
     (binary_expr ">=" @font-lock-operator-face)
     (binary_expr "&&" @font-lock-operator-face)
     (binary_expr "||" @font-lock-operator-face)
     ;; Sigils — @ : ~ $ & — keyword face so they pop
     (instance_ref "@" @font-lock-keyword-face)
     (borrow_ref ":" @font-lock-keyword-face)
     (mutable_ref "~" @font-lock-keyword-face)
     (generic_param "$" @font-lock-keyword-face)
     (generic_param "&" @font-lock-keyword-face)
     ;; Path separator
     (path_expr "/" @font-lock-delimiter-face))

   :language 'aski
   :feature 'punctuation
   :override t
   '(["(" ")" "[" "]" "{" "}" "{|" "|}" "(|" "|)" "[|" "|]"] @font-lock-bracket-face
     ["." "|"] @font-lock-delimiter-face))
  "Font-lock settings for `aski-ts-mode'.")

;; ── Indentation ──

(defvar aski-ts-mode--indent-rules
  `((aski
     ((parent-is "source_file") column-0 0)
     ((node-is ")") parent-bol 0)
     ((node-is "]") parent-bol 0)
     ((node-is "}") parent-bol 0)
     ((node-is "|)") parent-bol 0)
     ((node-is "|}") parent-bol 0)
     ((node-is "|]") parent-bol 0)
     ((parent-is "enum_decl") parent-bol ,aski-ts-mode-indent-offset)
     ((parent-is "struct_decl") parent-bol ,aski-ts-mode-indent-offset)
     ((parent-is "block_body") parent-bol ,aski-ts-mode-indent-offset)
     ((parent-is "block_expr") parent-bol ,aski-ts-mode-indent-offset)
     ((parent-is "match_body") parent-bol ,aski-ts-mode-indent-offset)
     ((parent-is "match_expr") parent-bol ,aski-ts-mode-indent-offset)
     ((parent-is "match_arm") parent-bol ,aski-ts-mode-indent-offset)
     ((parent-is "loop_stmt") parent-bol ,aski-ts-mode-indent-offset)
     ((parent-is "iteration_body") parent-bol ,aski-ts-mode-indent-offset)
     ((parent-is "iteration_stmt") parent-bol ,aski-ts-mode-indent-offset)
     ((parent-is "trait_decl") parent-bol ,aski-ts-mode-indent-offset)
     ((parent-is "trait_impl") parent-bol ,aski-ts-mode-indent-offset)
     ((parent-is "method_def") parent-bol ,aski-ts-mode-indent-offset)
     ((parent-is "ffi_block") parent-bol ,aski-ts-mode-indent-offset)
     ((parent-is "process_block") parent-bol ,aski-ts-mode-indent-offset)
     ((parent-is "nested_enum") parent-bol ,aski-ts-mode-indent-offset)
     ((parent-is "nested_struct") parent-bol ,aski-ts-mode-indent-offset)
     (no-node parent-bol 0)))
  "Indentation rules for `aski-ts-mode'.")

;; ── Navigation (defun movement) ──

(defvar aski-ts-mode--defun-type-regexp
  (regexp-opt '("enum_decl"
                "struct_decl"
                "newtype_decl"
                "trait_decl"
                "trait_impl"
                "const_decl"
                "ffi_block"
                "process_block"
                "module_decl"))
  "Regexp matching top-level definition node types.")

;; ── Imenu ──

(defvar aski-ts-mode--imenu-settings
  '(("Enum" "\\`enum_decl\\'" nil nil)
    ("Struct" "\\`struct_decl\\'" nil nil)
    ("Newtype" "\\`newtype_decl\\'" nil nil)
    ("Trait" "\\`trait_decl\\'" nil nil)
    ("Impl" "\\`trait_impl\\'" nil nil)
    ("Constant" "\\`const_decl\\'" nil nil)
    ("FFI" "\\`ffi_block\\'" nil nil)
    ("Module" "\\`module_decl\\'" nil nil))
  "Imenu settings for `aski-ts-mode'.")

;; ── Mode definition ──

;;;###autoload
(define-derived-mode aski-ts-mode prog-mode "Aski"
  "Tree-sitter major mode for aski (v0.17)."
  :group 'aski-ts

  ;; Comments
  (setq-local comment-start ";; ")
  (setq-local comment-end "")
  (setq-local comment-start-skip ";;+\\s-*")

  ;; Indentation
  (setq-local indent-tabs-mode nil)
  (setq-local tab-width aski-ts-mode-indent-offset)
  (setq-local treesit-simple-indent-rules aski-ts-mode--indent-rules)

  ;; Font-lock — 4-level structure like rust-ts-mode
  (setq-local treesit-font-lock-feature-list
              '((comment definition)
                (keyword string)
                (builtin constant number type)
                (function operator property punctuation variable)))
  (setq-local treesit-font-lock-settings
              aski-ts-mode--font-lock-settings)

  ;; Navigation
  (setq-local treesit-defun-type-regexp aski-ts-mode--defun-type-regexp)

  ;; Imenu
  (setq-local treesit-simple-imenu-settings aski-ts-mode--imenu-settings)

  ;; Activate tree-sitter
  (treesit-parser-create 'aski)
  (treesit-major-mode-setup))

;;;###autoload
(add-to-list 'auto-mode-alist '("\\.aski\\'" . aski-ts-mode))

(provide 'aski-ts-mode)
;;; aski-ts-mode.el ends here
