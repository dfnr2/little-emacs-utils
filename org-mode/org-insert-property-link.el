;;; org-property-link-insertion.el --- Insert links from Org properties

;; Author: Your Name
;; Keywords: org-mode, links
;; Version: 1.1

;;; Commentary:

;; This package provides a simple way to insert links stored in Org mode
;; property drawers.  It's particularly useful for quickly inserting
;; frequently used links without having to remember or type them out each time.

;;; How to use (for standard Emacs):

;; 1. Copy this entire file into your Emacs configuration file
;;    (usually ~/.emacs or ~/.emacs.d/init.el).

;; 2. Restart Emacs or evaluate the code (M-x eval-buffer).

;; 3. In your Org files, define links in property drawers like this:
;;    :PROPERTIES:
;;    :LINK: [[valve-st-disabled][=Valve Disabled=]]
;;    :END:

;; 4. Use the shortcut C-c C-x l in any Org file to bring up a list of
;;    all defined links. Select a link to insert it at the cursor position.

;; Note: You can change the key binding by modifying the (define-key ...)
;; line at the end of this file.

;;; How to use (for Doom Emacs):

;; 1. Create a new file in your Doom Emacs configuration directory:
;;    ~/.doom.d/lisp/org-property-link-insertion.el

;; 2. Copy the code section of this file (everything below ";;; Code:")
;;    into the new file.

;; 3. In your ~/.doom.d/config.el, add the following lines:

;;    (load! "lisp/org-property-link-insertion")
;;    (map! :map org-mode-map
;;          :desc "Insert property link"
;;          "C-c C-x l" #'org-insert-property-link)

;; 4. Run 'doom sync' in your terminal and restart Emacs.

;; 5. Use the functionality as described in steps 3 and 4 of the
;;    standard Emacs instructions above.

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
