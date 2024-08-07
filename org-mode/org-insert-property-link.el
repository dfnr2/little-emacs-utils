;;; org-property-link-insertion.el --- Insert links from Org properties

;; Author: Your Name
;; Keywords: org-mode, links
;; Version: 1.2
;; Package-Requires: ((emacs "24.4"))
;; URL: https://github.com/dfnr2/little-emacs-utils

;;; Commentary:

;; This package provides a simple way to insert links stored in Org mode
;; property drawers.  It's particularly useful for quickly inserting
;; frequently used links without having to remember or type them out each time.

;;; How to use:

;; 1. In your Org files, define links in property drawers like this:
;;    :PROPERTIES:
;;    :LINK: [[valve-st-disabled][=Valve Disabled=]]
;;    :END:

;; 2. Use the shortcut C-c C-x l in any Org file to bring up a list of
;;    all defined links. Select a link to insert it at the cursor position.

;;; Installation:

;; 1. Clone the repository:
;;    git clone git@github.com:dfnr2/little-emacs-utils.git

;; 2. Add the following configuration to your Emacs init file
;;    (usually ~/.emacs, ~/.emacs.d/init.el, or ~/.doom.d/config.el for Doom Emacs):

;;    (use-package org-property-link-insertion
;;      :after org
;;      :load-path "path/to/little-emacs-utils/org-mode"
;;      :bind (:map org-mode-map
;;                  ("C-c C-x l" . org-insert-property-link)))

;; 3. Replace "path/to/little-emacs-utils" with the actual path where you cloned the repository.
;; 4. Restart Emacs or evaluate the configuration.

;; Note for Doom Emacs users:
;; If you want Doom to manage this package, add the following to your packages.el file:
;;
;; (package! org-property-link-insertion
;;   :recipe (:host github :repo "dfnr2/little-emacs-utils" :files ("org-mode/*.el")))

;; You can change the key binding by modifying the :bind section in the use-package declaration.

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

;; Key binding for standard Emacs
;; (This line can be removed for Doom Emacs users)
(define-key org-mode-map (kbd "C-c C-x l") 'org-insert-property-link)

(provide 'org-property-link-insertion)

;;; org-property-link-insertion.el ends here
