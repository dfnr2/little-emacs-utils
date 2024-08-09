;;; org-property-links.el --- Insert and create links in Org properties

;; Author: Your Name
;; Keywords: org-mode, links
;; Version: 1.3
;; Package-Requires: ((emacs "24.4"))
;; URL: https://github.com/dfnr2/little-emacs-utils

;;; Commentary:

;; This package provides functions to insert and create links stored in Org mode
;; property drawers. It's particularly useful for quickly inserting frequently
;; used links and for creating property drawers with links based on headings or
;; other Org elements.

;;; How to use:

;; 1. In your Org files, define links in property drawers like this:
;;    :PROPERTIES:
;;    :LINK: [[valve-st-disabled][=Valve Disabled=]]
;;    :END:

;; 2. Use the shortcut C-c C-x l to insert a link from existing properties.
;; 3. Use the shortcut C-c C-x L to create a new property drawer with a link.

;;; Installation:

;; 1. Clone the repository:
;;    git clone git@github.com:dfnr2/little-emacs-utils.git

;; 2. Add the following configuration to your Emacs init file
;;    (usually ~/.emacs, ~/.emacs.d/init.el, or ~/.doom.d/config.el for Doom Emacs):

;;    (use-package org-property-links
;;      :after org
;;      :load-path "path/to/little-emacs-utils/org-mode"
;;      :bind (:map org-mode-map
;;                  ("C-c C-x l" . org-insert-property-link)
;;                  ("C-c C-x L" . org-create-property-link)))

;; 3. Replace "path/to/little-emacs-utils" with the actual path where you cloned the repository.
;; 4. Restart Emacs or evaluate the configuration.

;; Note for Doom Emacs users:
;; If you want Doom to manage this package, add the following to your packages.el file:
;;
;; (package! org-property-links
;;   :recipe (:host github :repo "dfnr2/little-emacs-utils" :files ("org-mode/*.el")))
;;
;; And you might want to use the following key binding in your config.el:
;;
;; (map! :after org
;;       :map org-mode-map
;;       :localleader
;;       :desc "Insert property link" "l" #'org-insert-property-link
;;       :desc "Create property link" "L" #'org-create-property-link)

;;; Code:

(defun org-insert-property-link ()
  "Insert a link from :LINK: properties in the current buffer."
  (interactive)
  (let* ((links
          (org-element-map (org-element-parse-buffer) 'node-property
            (lambda (prop)
              (when (equal (org-element-property :key prop) "LINK")
                (org-element-property :value prop)))))
         (selected-link
          (completing-read "Select link to insert: " links nil t)))
    (if selected-link
        (insert selected-link)
      (message "No link selected"))))

(defun org-create-property-link ()
  "Create a LINK property for the current Org item or section.
This function inserts a property drawer (if not present) and adds a LINK
property. The LINK property contains an Org link where the target and
description are determined as follows:
1. If a #+NAME: property exists, it's used as the link target.
2. If the heading contains a <<link-name>>, that's extracted as the target.
3. Otherwise, the full heading text is used as both target and description.
The function works on headings, list items, and other Org elements."
  (interactive)
  (save-excursion
    (org-back-to-heading t)
    (let* ((element (org-element-at-point))
           (heading (org-element-property :raw-value element))
           (name (org-element-property :NAME element))
           (link-name (or name
                          (and (string-match "<<\\([^>]+\\)>>" heading)
                               (match-string 1 heading))
                          (string-trim heading)))
           (section-name (string-trim (replace-regexp-in-string "<<.*>>" "" heading)))
           (link-property (format ":LINK: [[%s][%s]]" link-name section-name)))
      (forward-line 1)
      (if (looking-at-p ":PROPERTIES:")
          (progn
            (forward-line 1)
            (while (and (looking-at-p ":[A-Za-z]+:") (not (looking-at-p ":END:")))
              (forward-line 1))
            (insert link-property "\n"))
        (insert ":PROPERTIES:\n" link-property "\n:END:\n")))))

(provide 'org-property-links)

;;; org-property-links.el ends here
