;;; org-property-links.el --- Create and insert links in Org properties -*- lexical-binding: t -*-

;; Copyright (C) 2023 David Fenyes
;;
;; Author: David Fenyes (dfnum2@gmail.com)
;; Version: 1.14
;; Package-Requires: ((emacs "26.1") (org "9.3"))
;; Keywords: convenience, hypermedia
;; URL: https://github.com/yourusername/org-property-links

;;; Commentary:

;; This package provides convenient functions to insert and create links stored
;; in Org property drawers, including links from files referenced by #+INCLUDE directives.
;;
;; Features:
;; - Insert links from property drawers in the current buffer and included files.
;; - Insert links in full format [[link][description]] or short format [[link]].
;; - Uses Org's internal parser for robust #+INCLUDE handling.
;; - Handles quoted and unquoted file paths.
;; - Reuses parse trees where possible for improved performance.
;; - Caches included file results (based on modification time) to improve performance
;;   when including large files.
;; - Customizable sorting options for link insertion.
;;
;; Usage:
;; - M-x org-property-links-insert-long   (insert full format link)
;; - M-x org-property-links-insert-short  (insert short format link)
;; - M-x org-property-links-create        (create link property for current heading)
;; - M-x org-property-links-toggle-tracking
;;
;; Example configuration:
;; (use-package org-property-links
;;   :after org
;;   :bind (:map org-mode-map
;;               ("C-c C-x L" . org-property-links-create)
;;               ("C-c C-x l l" . org-property-links-insert-long)
;;               ("C-c C-x l s" . org-property-links-insert-short)
;;               ("C-c C-x t" . org-property-links-toggle-tracking))
;;   :config
;;   (setq org-property-links-sort-mode "description")
;;   (setq org-property-links-field "LINK")
;;   (setq org-property-links-tracking-field "TRACKING"))


;;; Code:

(require 'org)
(require 'org-element)

(defgroup org-property-links nil
  "Options for org-property-links."
  :group 'org)

(defcustom org-property-links-sort-mode "description"
  "Determines how links are sorted when inserting.
Possible values are \"description\" or \"link\"."
  :type '(choice
          (const :tag "Sort by description" "description")
          (const :tag "Sort by link" "link"))
  :group 'org-property-links)

(defcustom org-property-links-field "LINK"
  "The name of the property used to store links."
  :type 'string
  :group 'org-property-links)

(defcustom org-property-links-tracking-field "TRACKING"
  "The name of the property used to track items."
  :type 'string
  :group 'org-property-links)

(make-variable-buffer-local 'org-property-links-sort-mode)


;;; Caching for Included Files

(defvar org-property-links--file-cache (make-hash-table :test 'equal)
  "Cache mapping included file paths to a cons cell of (MOD-TIME . LINK-VALUE-LIST).
MOD-TIME is the file's last modification time when it was last parsed.")

(defun org-property-links--get-links-from-file (file)
  "Return the list of LINK property values from FILE.
Uses a cache keyed by FILE path and checks the file's modification time.
If the file has not changed since it was last read, returns the cached result."
  (if (not (file-exists-p file))
      (progn
        (message "Included file not found: %s" file)
        nil)
    (let* ((mod-time (nth 5 (file-attributes file))) ; modification time
           (cache-entry (gethash file org-property-links--file-cache))
           (cached-mod-time (car cache-entry))
           (cached-links (cdr cache-entry)))
      (if (and cached-mod-time (equal mod-time cached-mod-time))
          ;; Cached result is valid.
          cached-links
        ;; Otherwise, read and parse the file.
        (with-temp-buffer
          (condition-case err
              (progn
                (insert-file-contents file)
                (org-mode)
                (let* ((file-parse (org-element-parse-buffer))
                       (links (org-element-map file-parse 'node-property
                                (lambda (prop)
                                  (when (equal (org-element-property :key prop)
                                               org-property-links-field)
                                    (org-element-property :value prop))))))
                  (puthash file (cons mod-time links) org-property-links--file-cache)
                  links))
            (error (message "Error reading %s: %s" file err)
                   nil)))))))


;;; Helper Functions

(defun org-property-links--strip-quotes (s)
  "If string S is enclosed in quotes, remove them; otherwise return S unchanged."
  (if (and (string-prefix-p "\"" s)
           (string-suffix-p "\"" s))
      (substring s 1 -1)
    s))

(defun org-property-links--get-base-directory ()
  "Return the base directory for file paths.
Uses the current buffer's file directory or falls back to `default-directory`."
  (or (and (buffer-file-name)
           (file-name-directory (buffer-file-name)))
      default-directory))


;;; Include File Handling

(defun org-property-links--get-included-links ()
  "Return LINK property values collected from all #+INCLUDE files.
This function searches for INCLUDE keywords using Org-element parsing,
handles both quoted and unquoted file paths, and uses caching to avoid
reprocessing large files unnecessarily."
  (let ((links nil)
        (base (org-property-links--get-base-directory))
        (parse-tree (org-element-parse-buffer)))
    (org-element-map parse-tree 'keyword
      (lambda (keyword)
        (when (string= (upcase (org-element-property :key keyword)) "INCLUDE")
          (let* ((raw-value (org-element-property :value keyword))
                 ;; Split on whitespace to ignore any additional options.
                 (first-token (car (split-string raw-value "[ \t\n]+" t)))
                 (file-path (org-property-links--strip-quotes first-token))
                 (full-path (expand-file-name file-path base))
                 (file-links (org-property-links--get-links-from-file full-path)))
            (setq links (append links file-links))))))
    links))

(defun org-property-links--collect-all-links ()
  "Collect unique LINK property values from the current buffer and included files.
Reuses the current buffer's parse tree for performance."
  (let* ((parse-tree (org-element-parse-buffer))
         (current-links (org-element-map parse-tree 'node-property
                          (lambda (prop)
                            (when (equal (org-element-property :key prop)
                                         org-property-links-field)
                              (org-element-property :value prop)))))
         (include-links (org-property-links--get-included-links))
         (all-links (delete-dups (append current-links include-links))))
    all-links))


;;; Link Parsing and Insertion

(defun org-property-links--parse-link (link-string)
  "Parse LINK-STRING and return a cons cell (path . description).
If LINK-STRING is in the Org link format, its components are extracted."
  (if (string-match org-link-any-re link-string)
      (cons (match-string 2 link-string)
            (or (match-string 3 link-string)
                (match-string 2 link-string)))
    (cons link-string link-string)))

(defun org-property-links--insert-impl (short-form)
  "Implementation function that inserts a link.
When SHORT-FORM is non-nil, insert link without description."
  (let* ((all-links (org-property-links--collect-all-links))
         (parsed-links (mapcar #'org-property-links--parse-link all-links)))
    (if (null parsed-links)
        (message "No %s properties found in current buffer or included files."
                 org-property-links-field)
      (let* ((sort-by-description (equal org-property-links-sort-mode "description"))
             (sorted-links (sort parsed-links
                                 (lambda (a b)
                                   (string<
                                    (downcase (if sort-by-description (cdr a) (car a)))
                                    (downcase (if sort-by-description (cdr b) (car b)))))))
             (formatted-links (mapcar (lambda (link)
                                        (if sort-by-description
                                            (cons (format "%s (%s)" (cdr link) (car link)) link)
                                          (cons (format "%s (%s)" (car link) (cdr link)) link)))
                                      sorted-links))
             (max-length (apply #'max (mapcar (lambda (link) (length (car link))) formatted-links)))
             (padded-links (mapcar (lambda (link)
                                     (cons (format (format "%%-%ds" max-length) (car link))
                                           (cdr link)))
                                   formatted-links))
             (selected-link (completing-read "Select link to insert: "
                                             (mapcar #'car padded-links)
                                             nil t)))
        (when selected-link
          (let ((original-link (cdr (assoc selected-link padded-links))))
            (if short-form
                ;; Short form: link without description
                (insert (format "[[%s]]" (car original-link)))
              ;; Long form: full Org link with brackets and description
              (insert (format "[[%s][%s]]"
                              (car original-link)
                              (cdr original-link))))))))))

(defun org-property-links-insert-long ()
  "Insert a link from LINK properties in full Org format with description."
  (interactive)
  (org-property-links--insert-impl nil))

(defun org-property-links-insert-short ()
  "Insert just the target part of a link from LINK properties."
  (interactive)
  (org-property-links--insert-impl t))


;;; Link Property Creation

(defun org-property-links-create ()
  "Create a LINK property for the current Org item.
Inserts a property drawer (if necessary) and adds a LINK property.
The link target and description are determined by:
1. The value of a #+NAME: property, if present.
2. A <<link-name>> found in the heading.
3. The :CUSTOM_ID: property, if present.
4. Otherwise, the heading text is used."
  (interactive)
  (save-excursion
    (org-back-to-heading t)
    (let* ((element (org-element-at-point))
           (heading (org-element-property :raw-value element))
           (name (org-element-property :NAME element))
           (custom-id (org-element-property :CUSTOM_ID element))
           (link-name (or name
                          (and (string-match "<<\\([^>]+\\)>>" heading)
                               (match-string 1 heading))
                          custom-id
                          (string-trim heading)))
           (section-name (string-trim (replace-regexp-in-string "<<.*>>" "" heading)))
           (link-property (format ":%s: [[%s][%s]]" org-property-links-field link-name section-name)))
      (forward-line 1)
      (if (looking-at-p ":PROPERTIES:")
          (progn
            (forward-line 1)
            (while (and (looking-at-p ":[A-Za-z]+:")
                        (not (looking-at-p ":END:")))
              (forward-line 1))
            (insert link-property "\n"))
        (insert ":PROPERTIES:\n" link-property "\n:END:\n"))
      (message "Link property created successfully."))))


;;; Toggle Tracking Property

(defun org-property-links-toggle-tracking ()
  "Toggle the TRACKING property in the current entry.
If the property exists, it is toggled between 't' and 'f'. If it doesn't exist,
a property drawer is created (if necessary) and TRACKING is set to 't'."
  (interactive)
  (save-excursion
    (org-back-to-heading t)
    (let* ((tracking-value (org-entry-get (point) org-property-links-tracking-field))
           (new-value (if (equal tracking-value "t") "f" "t")))
      (if tracking-value
          (org-entry-put (point) org-property-links-tracking-field new-value)
        (forward-line 1)
        (if (looking-at-p ":PROPERTIES:")
            (progn
              (forward-line 1)
              (while (and (looking-at-p ":[A-Za-z]+:")
                          (not (looking-at-p ":END:")))
                (forward-line 1))
              (insert (format ":%s: t\n" org-property-links-tracking-field)))
          (insert ":PROPERTIES:\n"
                  (format ":%s: t\n" org-property-links-tracking-field)
                  ":END:\n")))
      (message "Tracking is now %s"
               (if (equal new-value "t") "enabled" "disabled")))))


;;; Provide Feature

(provide 'org-property-links)

;;; org-property-links.el ends here
