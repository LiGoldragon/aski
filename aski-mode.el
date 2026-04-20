;;; aski-mode.el --- Major mode for aski language -*- lexical-binding: t; -*-

;; Author: Li
;; Version: 0.1.0
;; Keywords: languages
;; Package-Requires: ((emacs "27.1"))

;;; Commentary:
;; Syntax highlighting and editing support for .aski files.

;;; Code:

(defgroup aski nil
  "Major mode for aski."
  :group 'languages)

(defvar aski-mode-syntax-table
  (let ((st (make-syntax-table)))
    ;; ;; is comment-to-end-of-line
    (modify-syntax-entry ?\; ". 12" st)
    (modify-syntax-entry ?\n ">" st)
    ;; string delimiter
    (modify-syntax-entry ?\" "\"" st)
    ;; balanced delimiters
    (modify-syntax-entry ?\( "()" st)
    (modify-syntax-entry ?\) ")(" st)
    (modify-syntax-entry ?\[ "(]" st)
    (modify-syntax-entry ?\] ")[" st)
    (modify-syntax-entry ?\{ "(}" st)
    (modify-syntax-entry ?\} "){" st)
    ;; @ : ~ & are punctuation
    (modify-syntax-entry ?@ "." st)
    (modify-syntax-entry ?: "." st)
    (modify-syntax-entry ?~ "." st)
    (modify-syntax-entry ?& "." st)
    (modify-syntax-entry ?^ "." st)
    (modify-syntax-entry ?> "." st)
    (modify-syntax-entry ?! "." st)
    (modify-syntax-entry ?# "." st)
    (modify-syntax-entry ?$ "." st)
    (modify-syntax-entry ?? "." st)
    (modify-syntax-entry ?| "." st)
    (modify-syntax-entry ?' "." st)
    st)
  "Syntax table for `aski-mode'.")

(defvar aski-font-lock-keywords
  `(
    ;; stub — warning face
    ("\\_<___\\_>" . font-lock-warning-face)

    ;; @ prefix on instances — highlight the @Name as a unit
    ("@\\([A-Z][a-zA-Z0-9]*\\)" 0 font-lock-variable-name-face)

    ;; : borrow prefix
    (":\\(@[A-Z][a-zA-Z0-9]*\\)" 0 font-lock-variable-name-face)

    ;; ~ mutable borrow prefix
    ("~\\(@[A-Z][a-zA-Z0-9]*\\)" 0 font-lock-variable-name-face)

    ;; ! const prefix — !Name
    ("!\\([A-Z][a-zA-Z0-9]*\\)" 0 font-lock-constant-face)

    ;; # contract prefix
    ("#(" . font-lock-preprocessor-face)

    ;; ^ return prefix
    ("\\^" . font-lock-keyword-face)

    ;; > yield prefix
    (">[^=]" . font-lock-keyword-face)

    ;; (| and |) match delimiters
    ("(|" . font-lock-keyword-face)
    ("|)" . font-lock-keyword-face)

    ;; PascalCase — types, domains, traits
    ("\\_<\\([A-Z][a-zA-Z0-9]*\\)\\_>" . font-lock-type-face)

    ;; camelCase before ( — function/method calls
    ("\\_<\\([a-z][a-zA-Z0-9]*\\)(" 1 font-lock-function-name-face)

    ;; camelCase after . — method access
    ("\\.\\([a-z][a-zA-Z0-9]*\\)" 1 font-lock-function-name-face)

    ;; & trait combination
    ("\\([A-Z][a-zA-Z0-9]*\\)&\\([A-Z][a-zA-Z0-9]*\\)"
     (1 font-lock-type-face) (2 font-lock-type-face))

    ;; numeric literals
    ("\\_<[0-9]+\\(?:\\.[0-9]+\\)?\\_>" . font-lock-constant-face)

    ;; operators
    (,(regexp-opt '("==" "!=" ">=" "<=" "&&" "||" "..=" "..." ".." "+" "-" "*" "/" "%") 'symbols)
     . font-lock-builtin-face)
    )
  "Font-lock keywords for `aski-mode'.")

;;;###autoload
(define-derived-mode aski-mode prog-mode "Aski"
  "Major mode for editing aski language files."
  :syntax-table aski-mode-syntax-table
  (setq-local comment-start ";; ")
  (setq-local comment-end "")
  (setq-local comment-start-skip ";;+\\s-*")
  (setq-local font-lock-defaults '(aski-font-lock-keywords))
  (setq-local indent-tabs-mode nil)
  (setq-local tab-width 2))

;;;###autoload
(add-to-list 'auto-mode-alist '("\\.aski\\'" . aski-mode))

(provide 'aski-mode)
;;; aski-mode.el ends here
