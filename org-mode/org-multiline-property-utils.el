;;; org-multiline-property-utils.el --- Utilities for Org mode properties -*- lexical-binding: t; -*-

;; Author: David Fenyes
;; Version: 1.1
;; Package-Requires: ((emacs "24.4") (org "9.0"))
;; Keywords: org, convenience
;; URL: https://github.com/dfnrw//org-multiline-property-utils

;;; Commentary:

;; This package provides utility functions for working with Org mode properties:
;;
;; - org-multiline-property-utils-column-fill: Wraps property values to fill-column width.
;;   Intended to be mapped to M-q, providing behavior analogous to the default
;;   fill-paragraph, but tailored for property drawers.
;;
;; - org-insert-property-continuation: Inserts a continuation line for the current property.
;;   Intended to be mapped to C-<return>, providing behavior analogous to the default
;;   org-insert-heading, but tailored for property drawers.
;;
;; To use this package in Doom Emacs:
;;
;; 1. Save this file as `org-multiline-property-utils-utils.el` in your Doom Emacs Lisp directory.
;;    This is typically either `~/.doom.d/lisp/` or `~/.config/doom/lisp/`.
;;
;; 2. Add the following to your Doom Emacs config file (usually `config.el`):
;;
;;    (use-package org-multiline-property-utils
;;      :after org
;;      :config
;;      (define-key org-mode-map (kbd "C-<return>") #'org-insert-property-continuation)
;;      (define-key org-mode-map (kbd "M-q") #'org-multiline-property-utils-column-fill))
;;
;; 3. Restart Doom Emacs or reload your configuration.
;;
;; These functions will then be available when you start Doom Emacs, with the
;; specified key bindings active in Org mode buffers.

;;; Code:

(require 'org)
(require 'org-element)

(defun org-multiline-property-utils-column-fill ()
  "Fill the current property value to `fill-column'.
If not in a property, use the normal `fill-paragraph' function.
For properties, wrap the value to `fill-column' width and replace
the property lines with the wrapped property. Preserves '\\n' as
new property lines.

This function is intended to be mapped to M-q in Org mode,
providing behavior analogous to the default fill-paragraph, but
tailored for property drawers."
  (interactive)
  (if (org-multiline-property-utils--in-property-drawer-p)
      (let* ((element (org-element-at-point))
             (property (org-element-property :key element))
             (clean-property (replace-regexp-in-string "\\+$" "" property))
             (value (org-entry-get nil clean-property t))
             (wrapped-segments (org-multiline-property-utils--wrap-value-preserve-newlines value clean-property))
             (formatted-lines (org-multiline-property-utils--format-wrapped-segments clean-property wrapped-segments)))
        (org-entry-delete nil clean-property)
        (insert (mapconcat #'identity formatted-lines "\n") "\n"))
    (fill-paragraph)))

(defun org-multiline-property-utils--wrap-value-preserve-newlines (value property)
  "Wrap VALUE to fit within `fill-column', preserving '\\n' as segment separators.
PROPERTY is the name of the property being wrapped."
  (let* ((prefix-length (+ 2 (length property) 2)) ; ":PROPERTY: "
         (fill-column (- fill-column prefix-length))
         (first-char (substring value 0 1))
         (value-rest (substring value 1))
         (segments (split-string value-rest "\\\\n" t))
         wrapped-segments)
    ;; Add "\n" to the beginning of each segment except the first
    (setq segments
          (cons (car segments)
                (mapcar (lambda (seg) (concat "\\n" seg))
                        (cdr segments))))
    ;; Add the first character back to the first segment
    (setf (car segments) (concat first-char (car segments)))
    (dolist (segment segments)
      (with-temp-buffer
        (insert (string-trim segment))
        (fill-region (point-min) (point-max))
        (push (split-string (buffer-string) "\n" t) wrapped-segments)))
    (nreverse wrapped-segments)))

(defun org-multiline-property-utils--format-wrapped-segments (property wrapped-segments)
  "Format WRAPPED-SEGMENTS with PROPERTY prefixes."
  (let* ((all-lines (apply #'append wrapped-segments))
         (first-line (car all-lines))
         (rest-lines (cdr all-lines)))
    (cons (format ":%s: %s" property first-line)
          (mapcar (lambda (line) (format ":%s+: %s" property line)) rest-lines))))

(defun org-multiline-property-utils-insert-continuation ()
  "Insert a continuation line for the current property or a new list item.
If the current line is a property, create a new line with the same
property name.  If the current property doesn't end with '+', add
it to denote a continuation.  If it's a list item, insert a new list item.
Otherwise, insert a new heading as per default Org behavior.

This function is intended to be mapped to C-<return> in Org mode,
providing behavior analogous to the default org-insert-heading,
but tailored for property drawers and preserving list behavior."
  (interactive)
  (cond
   ;; If at a property, insert property continuation
   ((org-at-property-p)
    (let* ((element (org-element-at-point))
           (property (org-element-property :key element))
           (is-continuation (string-match-p "\\+$" property)))
      (end-of-line)
      (newline-and-indent)
      (insert ":" property (if is-continuation "" "+") ": ")))

   ;; If in a list, insert new list item
   ((org-in-item-p)
    (org-insert-item))

   ;; Default behavior: insert heading
   (t
    (org-insert-heading))))

(defun org-multiline-property-utils--in-property-drawer-p ()
  "Check if point is inside a property drawer.
Returns t if the current element is a node property, nil otherwise."
  (eq (org-element-type (org-element-at-point)) 'node-property))

;;;###autoload
(define-key org-mode-map (kbd "C-<return>") #'org-multiline-property-utils-insert-continuation)
;;;###autoload
(define-key org-mode-map (kbd "M-q") #'org-multiline-property-utils-column-fill)

(provide 'org-multiline-property-utils)

;;; org-multiline-property-utils.el ends here
