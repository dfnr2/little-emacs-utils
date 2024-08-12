;;; org-property-links.el --- Create and insert links in Org properties -*- lexical-binding: t -*-

;; Copyright (C) 2023 David Fenyes

;; Author: David Fenyes (dfnum2@gmail.com)
;; Version: 1.10
;; Package-Requires: ((emacs "26.1") (org "9.3"))
;; Keywords: convenience, hypermedia
;; URL: https://github.com/yourusername/org-property-links

;;; Commentary:

;; This package provides convenient functions to insert and create links stored
;; in Org property drawers. It's useful for defining and quickly inserting
;; frequently used links to be displayed by name rather than section number.

;; Features:
;; - Insert links from existing property drawers
;; - Create new property drawers with links based on current Org elements
;; - Customizable sorting options for link insertion
;; - Flexible link target selection (NAME, target definition, CUSTOM_ID, or heading)

;; Usage:
;; - M-x org-property-links-insert : Insert a link from existing properties
;; - M-x org-property-link : Create a new property link for the current element

;; Configuration:
;; You can customize the following variables:
;; - org-insert-link-sort-mode: Determines how links are sorted when inserting
;;   (options: "description" or "link")
;; - org-property-links-field: The name of the property used to store links
;;   (default: "LINK")

;; Example configuration:
;; (use-package org-property-links
;;   :after org
;;   :config
;;   (setq org-property-links-sort-mode "description")
;;   (setq org-property-links-field "LINK"))

;; For more information, see the README file or visit the package homepage.

;;; Code:

(require 'org)
(require 'org-element)

(defgroup org-property-links nil
  "Options for org-property-links."
  :group 'org)

(defcustom org-property-links-sort-mode "description"
  "Determines how links are sorted when inserting.
Possible values are \"description\" or \"link\".
This variable can be set globally or as a file-local variable."
  :type '(choice
          (const :tag "Sort by description" "description")
          (const :tag "Sort by link" "link"))
  :group 'org-property-links)

(defcustom org-property-links-field "LINK"
  "The name of the property used to store links."
  :type 'string
  :group 'org-property-links)

(make-variable-buffer-local 'org-insert-link-sort-mode)

(defun org-property-links--parse-link (link-string)
  "Parse LINK-STRING and return a cons of (path . description)."
  (if (string-match org-link-any-re link-string)
      (cons (match-string 2 link-string)
            (or (match-string 3 link-string)
                (match-string 2 link-string)))
    (cons link-string link-string)))

(defun org-property-links-insert ()
  "Insert a link from :LINK: properties in the current buffer.
The order of presented links is determined by
`org-insert-link-sort-mode', which can be set globally or as a
file-local variable. If `org-insert-link-sort-mode` is not set to
'link', sorting defaults to 'description'."
  (interactive)
  (let* ((links (org-element-map (org-element-parse-buffer) 'node-property
                  (lambda (prop)
                    (when (equal (org-element-property :key prop) org-property-links-field)
                      (org-element-property :value prop)))))
         (parsed-links (mapcar #'org-property-links--parse-link links)))
    (if (null parsed-links)
        (message "No %s properties found in the current buffer." org-property-links-field)
      (let* ((sorted-links (if (equal org-insert-link-sort-mode "link")
                               (sort parsed-links
                                     (lambda (a b)
                                       (string< (downcase (or (car a) ""))
                                                (downcase (or (car b) "")))))
                             (sort parsed-links
                                   (lambda (a b)
                                     (string< (downcase (or (cdr a) ""))
                                              (downcase (or (cdr b) "")))))))
             (max-length (apply 'max (mapcar (lambda (link)
                                               (length (format "%s (%s)" (cdr link) (car link))))
                                             sorted-links)))
             (padded-links (mapcar (lambda (link)
                                     (cons (format (concat "%-" (number-to-string max-length) "s")
                                                   (format "%s (%s)" (cdr link) (car link)))
                                           link))
                                   sorted-links))
             (selected-link (completing-read
                             "Select link to insert: "
                             (mapcar #'car padded-links)
                             nil t)))
        (when selected-link
          (let ((original-link (cdr (assoc selected-link padded-links))))
            (insert (format "[[%s][%s]]"
                            (car original-link)
                            (cdr original-link)))))))))

(defun org-property-links-create ()
  "Create a LINK property for the current Org item or section.
This function inserts a property drawer (if not present) and adds a LINK
property. The LINK property contains an Org link where the target and
description are determined as follows:
1. If a #+NAME: property exists, it's used as the link target.
2. If the heading contains a <<link-name>>, that's extracted as the target.
3. If a :CUSTOM_ID: property exists, it's used as the link target.
4. Otherwise, the full heading text is used as both target and description.
The function works on headings, list items, and other Org elements."
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
            (while (and (looking-at-p ":[A-Za-z]+:") (not (looking-at-p ":END:")))
              (forward-line 1))
            (insert link-property "\n"))
        (insert ":PROPERTIES:\n" link-property "\n:END:\n"))
      (message "Link property created successfully."))))

(provide 'org-property-links)

;;; org-property-links.el ends here
