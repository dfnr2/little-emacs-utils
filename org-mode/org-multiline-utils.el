;;; org-multiline-utils.el --- Utilities for Org mode multiline elements -*- lexical-binding: t; -*-

;; Author: David Fenyes
;; Version: 1.2
;; Package-Requires: ((emacs "24.4") (org "9.0"))
;; Keywords: org, convenience
;; URL: https://github.com/yourusername/org-multiline-utils

;;; Commentary:

;; This package provides utility functions for working with Org mode elements
;; that support multiline continuation, specifically:
;;
;; 1. Property drawers - with "+" continuation syntax
;; 2. Org keywords that support multiline continuation:
;; - #+TITLE:
;; - #+AUTHOR:
;; - #+DATE:
;; - #+CAPTION:
;; - #+HEADER:
;; - #+TBLFM:
;; - #+HTML_HEAD:
;; - #+LATEX_HEADER:
;; - #+ATTR_HTML:
;; - #+ATTR_LATEX:
;; - #+ATTR_ODT:
;; - #+ATTR_ASCII:
;; - #+ATTR_ORG:
;; - #+ATTR_BEAMER:
;; - #+ATTR_REVEAL:
;; - #+NAME:
;; - #+PLOT:
;;
;; This package provides two main functions:
;;
;; - org-multiline-utils-column-fill: Wraps content to fill-column width.
;;   Intended to be mapped to M-q, providing behavior analogous to the default
;;   fill-paragraph, but tailored for multiline elements.
;;
;; - org-multiline-utils-insert-continuation: Inserts a continuation line for the current element.
;;   Intended to be mapped to C-c c, providing a way to easily extend multiline elements.
;;
;; To use this package in Doom Emacs:
;;
;; 1. Save this file as `org-multiline-utils.el` in your Doom Emacs Lisp directory.
;;    This is typically either `~/.doom.d/lisp/` or `~/.config/doom/lisp/`.
;;
;; 2. Add the following to your Doom Emacs config file (usually `config.el`):
;;
;;    (use-package org-multiline-utils
;;      :after org
;;      :config
;;      (define-key org-mode-map (kbd "C-c c") #'org-multiline-utils-insert-continuation)
;;      (define-key org-mode-map (kbd "M-q") #'org-multiline-utils-column-fill))
;;
;; 3. Restart Doom Emacs or reload your configuration.
;;
;; These functions will then be available when you start Doom Emacs, with the
;; specified key bindings active in Org mode buffers.

;;; Code:

(require 'org)
(require 'org-element)

(defvar org-multiline-utils-supported-keywords
  '("CAPTION"
    "TITLE"
    "AUTHOR"
    "DATE"
    "HEADER"
    "TBLFM"
    "HTML_HEAD"
    "LATEX_HEADER"
    "ATTR_HTML"
    "ATTR_LATEX"
    "ATTR_BEAMER"
    "ATTR_ODT"
    "ATTR_ORG"
    "ATTR_ASCII"
    "ATTR_TEXT"
    "PLOT"
    "NAME")
  "List of Org keywords that support multiline continuation.")

;;; Common utilities

(defun org-multiline-utils-column-fill ()
  "Fill the current element content to `fill-column'.
Works with property drawers and supported keywords.
If not in a supported element, falls back to the normal `fill-paragraph'."
  (interactive)
  (cond
   ((org-multiline-utils--in-property-drawer-p)
    (org-multiline-utils--fill-property))
   ((org-multiline-utils--at-supported-keyword-p)
    (condition-case err
        (org-multiline-utils--fill-keyword)
      (error (message "Error wrapping keyword: %s" (error-message-string err))
             (fill-paragraph))))
   (t
    (fill-paragraph))))

(defun org-multiline-utils-insert-continuation ()
  "Insert a continuation line for the current element.
Works with property drawers, supported keywords, and list items.
If none of these apply, falls back to org-insert-heading."
  (interactive)
  (cond
   ;; If at a property, insert property continuation
   ((org-at-property-p)
    (org-multiline-utils--insert-property-continuation))

   ;; If at a keyword, insert keyword continuation
   ((org-multiline-utils--at-supported-keyword-p)
    (org-multiline-utils--insert-keyword-continuation))

   ;; If in a list, insert new list item
   ((org-in-item-p)
    (org-insert-item))

   ;; Default behavior: insert heading
   (t
    (org-insert-heading))))

;;; Property drawer functions

(defun org-multiline-utils--in-property-drawer-p ()
  "Check if point is inside a property drawer.
Returns t if the current element is a node property, nil otherwise."
  (eq (org-element-type (org-element-at-point)) 'node-property))

(defun org-multiline-utils--fill-property ()
  "Fill the current property value to `fill-column'."
  (let* ((element (org-element-at-point))
         (property (org-element-property :key element))
         (clean-property (replace-regexp-in-string "\\+$" "" property))
         (value (org-entry-get nil clean-property t))
         (wrapped-segments (org-multiline-utils--wrap-property-value-preserve-newlines value clean-property))
         (formatted-lines (org-multiline-utils--format-wrapped-property-segments clean-property wrapped-segments)))
    (org-entry-delete nil clean-property)
    (insert (mapconcat #'identity formatted-lines "\n") "\n")))

(defun org-multiline-utils--wrap-property-value-preserve-newlines (value property)
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

(defun org-multiline-utils--format-wrapped-property-segments (property wrapped-segments)
  "Format WRAPPED-SEGMENTS with PROPERTY prefixes."
  (let* ((all-lines (apply #'append wrapped-segments))
         (first-line (car all-lines))
         (rest-lines (cdr all-lines)))
    (cons (format ":%s: %s" property first-line)
          (mapcar (lambda (line) (format ":%s+: %s" property line)) rest-lines))))

(defun org-multiline-utils--insert-property-continuation ()
  "Insert a continuation line for the current property."
  (let* ((element (org-element-at-point))
         (property (org-element-property :key element))
         (is-continuation (string-match-p "\\+$" property)))
    (end-of-line)
    (newline-and-indent)
    (insert ":" property (if is-continuation "" "+") ": ")))

;;; Keyword functions

(defun org-multiline-utils--get-current-keyword ()
  "Get the current keyword name.
Handles both #+ and # prefixes for keywords."
  (save-excursion
    (beginning-of-line)
    (when (looking-at "^[ \t]*#\\+\\([A-Z_]+\\):")
      (match-string-no-properties 1))))

(defun org-multiline-utils--at-supported-keyword-p ()
  "Check if point is at a supported keyword line."
  (let ((keyword (org-multiline-utils--get-current-keyword)))
    (and keyword (member keyword org-multiline-utils-supported-keywords))))

(defun org-multiline-utils--get-all-keyword-lines ()
  "Get all consecutive lines that belong to the current keyword element.
Returns a list of (start . end) positions for each line."
  (let ((keyword (org-multiline-utils--get-current-keyword))
        (lines '())
        (current-line (line-number-at-pos))
        line-start)
    (when keyword
      ;; Find the first line that matches the keyword
      (save-excursion
        ;; Go to the first line in the current block of this keyword
        (while (and (not (bobp))
                    (progn
                      (forward-line -1)
                      (looking-at (format "^[ \t]*#\\+%s:" keyword))))
          ;; Keep going backward as long as we find matching lines
          )
        (forward-line 1)  ;; Move back to the first matching line

        ;; Now collect all consecutive lines with this keyword
        (while (and (not (eobp))
                    (looking-at (format "^[ \t]*#\\+%s:" keyword)))
          (push (cons (line-beginning-position) (line-end-position)) lines)
          (forward-line 1))))

    (nreverse lines)))

(defun org-multiline-utils--extract-keyword-content ()
  "Extract the full content from all lines of the current keyword.
Returns the content as a single string."
  (let ((keyword (org-multiline-utils--get-current-keyword))
        (content ""))
    (when keyword
      (save-excursion
        (let ((lines (org-multiline-utils--get-all-keyword-lines)))
          (dolist (line-pos lines)
            (goto-char (car line-pos))
            (let ((line (buffer-substring-no-properties
                         (car line-pos)
                         (cdr line-pos))))
              (when (string-match (format "^[ \t]*#\\+%s:[ \t]*\\(.*\\)$" keyword) line)
                (when (> (length content) 0)
                  (setq content (concat content " ")))
                (setq content (concat content (match-string 1 line)))))))
        content))))

(defun org-multiline-utils--fill-keyword ()
  "Fill the current keyword content to `fill-column'."
  (let ((keyword (org-multiline-utils--get-current-keyword)))
    (when keyword
      (let* ((content (org-multiline-utils--extract-keyword-content))
             (line-positions (org-multiline-utils--get-all-keyword-lines))
             (wrapped-text (org-multiline-utils--wrap-keyword-text content keyword)))

        ;; Delete all existing lines
        (save-excursion
          (dolist (pos (reverse line-positions))
            (delete-region (car pos) (1+ (cdr pos)))))

        ;; Insert the new wrapped text at the beginning of where the element was
        (save-excursion
          (goto-char (caar line-positions))
          (insert wrapped-text "\n"))))))

(defun org-multiline-utils--wrap-keyword-text (text keyword)
  "Wrap TEXT to fit within `fill-column' for KEYWORD."
  (when (or (null text) (not (stringp text)))
    (setq text ""))

  (let* ((prefix (format "#+%s: " keyword))
         (prefix-length (length prefix))
         (effective-fill-column (- fill-column prefix-length))
         wrapped-lines)

    ;; Fill the text in a temp buffer
    (with-temp-buffer
      (insert text)
      (let ((fill-column effective-fill-column))
        (fill-region (point-min) (point-max)))
      (setq wrapped-lines (split-string (buffer-string) "\n" t)))

    ;; Format the output with proper prefixes
    (if (null wrapped-lines)
        ;; If no content, just return the prefix
        prefix
      ;; Otherwise, format properly with the same prefix for all lines
      (concat
       (concat prefix (car wrapped-lines))
       (if (cdr wrapped-lines)
           (concat
            "\n"
            (mapconcat
             (lambda (line) (concat prefix line))
             (cdr wrapped-lines)
             "\n"))
         "")))))

(defun org-multiline-utils--insert-keyword-continuation ()
  "Insert a continuation line for the current keyword."
  (let ((keyword (org-multiline-utils--get-current-keyword)))
    (end-of-line)
    (newline-and-indent)
    (insert (format "#+%s: " keyword))))

;;;###autoload
;;;(define-key org-mode-map (kbd "C-c c") #'org-multiline-utils-insert-continuation)
;;;###autoload
;;;(define-key org-mode-map (kbd "M-q") #'org-multiline-utils-column-fill)

(provide 'org-multiline-utils)

;;; org-multiline-utils.el ends here
