;;; pretty-print.el --- Batch Scheme formatter (indent only) -*- lexical-binding: t; -*-
;; Usage examples:
;;   Format a single file:
;;     emacs --batch -l pretty-print.el -f pp:main path/to/file.scm
;;
;;   Format multiple files:
;;     emacs --batch -l pretty-print.el -f pp:main file1.scm file2.ss
;;
;;   Recurse a directory (default extensions: .scm, .sps, .ss):
;;     emacs --batch -l pretty-print.el -f pp:main path/to/dir
;;
;;   Check mode (non-zero exit if changes would be made):
;;     emacs --batch -l pretty-print.el -f pp:main --check path/to/dir
;;
;; Windows (PowerShell):
;;   emacs.exe --batch -l .\pretty-print.el -f pp:main C:\path\to\file.scm
;;
;; Notes:
;; - Preserves comments and EOL style.
;; - Indents based on Emacs scheme-mode (not macro-expansion aware).
;; - You can add project-specific indentation rules in pp/indent-spec.

(require 'cl-lib)
(require 'scheme)

(defgroup pp nil
  "Batch Scheme formatter (indentation only)."
  :group 'languages)

(defcustom pp/indent-width 2
  "Indentation width for Scheme bodies."
  :type 'integer
  :group 'pp)

(defcustom pp/extensions '("scm" "sps" "ss" "sls")
  "File extensions to process when a directory is given."
  :type '(repeat string)
  :group 'pp)

(defcustom pp/indent-spec
  '(;; R6RS / standard forms
    (library . 1)
    (define-record-type . 1)
    (syntax-rules . 1)
    (syntax-case . 2)
    (with-syntax . 1)
    (let-syntax . 1)
    (letrec-syntax . 1)
    (let-values . 1)
    (let*-values . 1)
    (guard . 1)
    ;; CREST RAII macros — first arg is the resource binding
    (with-mlir-context . 1)
    (with-type-converter . 1)
    (with-conversion-target . 1)
    (with-pattern-set . 1)
    (with-array-ref . 1)
    (parameterize . 1))
  "Alist of (symbol . indent-level) to teach scheme-mode indentation."
  :type '(alist :key-type symbol :value-type integer)
  :group 'pp)

;; DDR keywords appear as bare atoms (not as car of a list), so
;; scheme-indent-function is never consulted for them.  Instead, the
;; indent function for define-*-pattern checks the current line: if it
;; starts with a DDR keyword the line sits at the form's opening-paren
;; column; otherwise it is indented 2 further.
(defun pp--ddr-indent (state indent-point _normal-indent)
  "Indent DDR body.
- Section keywords (:if-match :then-let :rewrite): form-col+2
- :where (subordinate to the pattern line above it): form-col+6
- Everything else (pattern lines, bindings, builders): form-col+4"
  (let ((form-col (save-excursion
                    (goto-char (cadr state))
                    (current-column))))
    (save-excursion
      (goto-char indent-point)
      (cond
       ((looking-at (rx (* blank) ":where" (or blank eol)))
        (+ form-col 6))
       ((looking-at (rx (* blank) ":" (+ (not blank))))
        (+ form-col 2))
       (t
        (+ form-col 4))))))

(defun pp--apply-indent-spec ()
  "Apply pp/indent-spec and DDR-specific rules to current Emacs session."
  (dolist (pair pp/indent-spec)
    (put (car pair) 'scheme-indent-function (cdr pair)))
  ;; DDR macros: body at the same column as the opening paren.
  (put 'define-rewrite-pattern   'scheme-indent-function #'pp--ddr-indent)
  (put 'define-conversion-pattern 'scheme-indent-function #'pp--ddr-indent))

(defun pp--scheme-buffer-p ()
  "Return non-nil if current buffer should be treated as Scheme."
  (derived-mode-p 'scheme-mode))

(defun pp--maybe-scheme-mode (file)
  "Ensure scheme-mode is active for FILE."
  ;; Rely on auto-mode, but also force scheme-mode if needed.
  (unless (pp--scheme-buffer-p)
    ;; Fallback: force scheme-mode when extension matches.
    (let ((ext (file-name-extension file)))
      (when (and ext (member (downcase ext) pp/extensions))
        (scheme-mode)))))

(defun pp--format-current-buffer (&optional check)
  "Indent current buffer. If CHECK is non-nil, do not save, just report modifications.
Return values: (modified-p . saved-p)."
  (let ((orig-mod (buffer-modified-p))
        ;; Preserve file’s EOL/coding; don’t alter it on save:
        (coding-system-for-write buffer-file-coding-system)
        ;; Prefer predictable indentation width:
        (lisp-body-indent pp/indent-width)
        ;; Always use spaces, never tabs:
        (indent-tabs-mode nil))
    (pp--apply-indent-spec)
    ;; Indent whole buffer, then convert any tabs to spaces
    (indent-region (point-min) (point-max))
    (untabify (point-min) (point-max))
    (let ((needs-save (buffer-modified-p)))
      (cond
       ((and needs-save (not check))
        (save-buffer)
        (cons t t))
       (t
        ;; In check mode or no changes, don't save.
        (cons needs-save nil))))))

(defun pp--format-file (file &optional check)
  "Format FILE in place. If CHECK is non-nil, do not save changes; return t if changes needed."
  (let ((abs (expand-file-name file)))
    (unless (file-exists-p abs)
      (error "No such file: %s" abs))
    (let* ((buf (find-file-noselect abs))
           (result (with-current-buffer buf
                     (pp--maybe-scheme-mode abs)
                     (pp--format-current-buffer check))))
      (kill-buffer buf)
      (car result))))

(defun pp--directory-files-recursively (dir)
  "Collect files under DIR matching pp/extensions."
  (let* ((pred (lambda (f)
                 (let ((ext (file-name-extension f)))
                   (and ext (member (downcase ext) pp/extensions)))))
         files)
    (when (and (file-directory-p dir) (not (file-symlink-p dir)))
      (let ((default-directory (file-name-as-directory (expand-file-name dir))))
        (dolist (entry (directory-files "." t "^[^.].*"))
          (cond
           ((file-directory-p entry)
            (setq files (nconc files (pp--directory-files-recursively entry))))
           ((funcall pred entry)
            (push entry files)))))) ; collect
    files))

(defun pp--format-path (path &optional check)
  "Format PATH (file or directory). If CHECK is non-nil, do not save changes.
Returns the number of files that would change (CHECK=t) or did change (CHECK=nil)."
  (let ((abs (expand-file-name path)))
    (cond
     ((file-directory-p abs)
      (let ((count 0)
            (files (pp--directory-files-recursively abs)))
        (dolist (f files)
          (condition-case e
              (when (pp--format-file f check)
                (cl-incf count)
                (when check
                  (princ (format "Needs format: %s\n" f))))
            (error
             (princ (format "Error formatting %s: %s\n" f (error-message-string e)))
             (setq count (1+ count)) ; treat as needing change
             )))
        count))
     ((file-regular-p abs)
      (condition-case e
          (if (pp--format-file abs check)
              (progn
                (when check (princ (format "Needs format: %s\n" abs)))
                1)
            0)
        (error
         (princ (format "Error formatting %s: %s\n" abs (error-message-string e)))
         1)))
     (t
      (princ (format "Skipping (not a file/dir): %s\n" abs))
      0))))

(defun pp:main ()
  "Entry point for batch mode. Parses command-line-args-left.
Options:
  --check       Do not save; exit 2 if any file would change.
  --ext=CSV     Override extensions (default: scm,sps,ss). Example: --ext=scm,ss
Arguments:
  One or more files or directories."
  (interactive)
  (let ((args command-line-args-left)
        (check nil))
    ;; Parse options
    (setq command-line-args-left nil) ; prevent Emacs default option parsing later
    (let (paths)
      (dolist (a args)
        (cond
         ((string-prefix-p "--ext=" a)
          (setq pp/extensions
                (mapcar #'downcase
                        (split-string (substring a (length "--ext=")) "," t "[[:space:]]*"))))
         ((string= a "--check")
          (setq check t))
         ((string-prefix-p "--" a)
          (princ (format "Unknown option: %s\n" a)))
         (t
          (push a paths))))
      (setq paths (nreverse paths))
      (when (null paths)
        (princ "Usage: emacs --batch -l pretty-print.el -f pp:main [--check] [--ext=csv] PATH...\n")
        (kill-emacs 1))
      ;; Process paths
      (let ((total 0))
        (dolist (p paths)
          (setq total (+ total (pp--format-path p check))))
        ;; Exit code: 0 if nothing to do, 2 if any changes needed/were made
        (kill-emacs (if (> total 0) 2 0))))))

(provide 'pretty-print)
;;; pretty-print.el ends here
