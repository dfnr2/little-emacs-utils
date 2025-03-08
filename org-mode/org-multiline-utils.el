#+TITLE: org-multiline-property-utils
#+AUTHOR: David Fenyes
#+DATE: [2024-08-07 Wed]

A couple of convenient utilities for working with multiline properties in Org mode.

** Overview

=org-multiline-property-utils= provides two main functions to improve the
handling of multiline properties in Org mode:

1. =org-property-column-fill=: Wraps multiline property values to =fill-column=
   width, preserving newlines.
2. =org-insert-property-continuation=: Inserts a continuation line for the
   current property.

These functions are designed to provide behavior analogous to the default Org
mode functions but tailored specifically for multiline property drawers.

** Features

- Intelligent wrapping of multiline property values that respects =fill-column=
- Respects and preserves newline characters (=\n=) in property values. This is
  useful when a property value contains paragraphs or enumerated items, for
  example.
- Easy insertion of property continuation lines
- Seamless integration with existing Org mode keybindings

** Installation

*** For Doom Emacs Users

1. Save =org-multiline-property-utils.el= in your Doom Emacs lisp directory:
   - Typically =~/.doom.d/lisp/= or =~/.config/doom/lisp/=

2. Add the following to your Doom Emacs config file (usually =config.el=):

   #+BEGIN_SRC emacs-lisp
   (use-package org-multiline-property-utils
     :after org
     :config
     (define-key org-mode-map (kbd "C-<return>") #'org-insert-property-continuation)
     (define-key org-mode-map (kbd "M-q") #'org-property-column-fill))
   #+END_SRC

3. Restart Doom Emacs or reload your configuration.

*** For Regular Emacs Users

1. Save =org-multiline-property-utils.el= in a directory in your Emacs load path.

2. Add the following to your Emacs configuration file:

   #+BEGIN_SRC emacs-lisp
   (require 'org-multiline-property-utils)
   (with-eval-after-load 'org
     (define-key org-mode-map (kbd "C-<return>") #'org-insert-property-continuation)
     (define-key org-mode-map (kbd "M-q") #'org-property-column-fill))
   #+END_SRC

3. Restart Emacs or evaluate the configuration.

** Usage

After installation, the following key bindings will be available in Org mode:

- =M-q= (=org-property-column-fill=): When the cursor is on a property line,
  this will wrap the property value to =fill-column= width, preserving any
  newlines in the original value.

- =C-<return>= (=org-insert-property-continuation=): When the cursor is on a
  property line, this will insert a continuation line for the current property.

These functions only modify their behavior when used within property drawers.
Outside of property drawers, they fall back to their default Org mode behavior.

** Examples

*** Wrapping a Multiline Property

Before:
#+BEGIN_EXAMPLE
:LONG_PROPERTY: This is a very long property value that exceeds the fill-column width and contains a newline character.\nThis is the continuation of the property value on a new line.
#+END_EXAMPLE

After =M-q=:
#+BEGIN_EXAMPLE
:LONG_PROPERTY: This is a very long property value that exceeds the
:LONG_PROPERTY+: fill-column width and contains a newline character.
:LONG_PROPERTY+: \nThis is the continuation of the property value on a
:LONG_PROPERTY+: new line.
#+END_EXAMPLE

*** Inserting a Continuation Line

Starting with:
#+BEGIN_EXAMPLE
:PROPERTY: Some value
#+END_EXAMPLE

After pressing =C-<return>=:
#+BEGIN_EXAMPLE
:PROPERTY: Some value
:PROPERTY+:
#+END_EXAMPLE

** Contributing

Contributions to improve =org-multiline-property-utils= are welcome. Please feel
free to submit issues or pull requests on the project's GitHub page.

** License

This project is licensed under the GNU General Public License v3.0 or later.
