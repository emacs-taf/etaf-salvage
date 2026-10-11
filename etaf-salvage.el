;;; -*- lexical-binding: t; -*-
;;; etaf-salvage.el --- Salvage Station, a standalone GameKit application

;; SPDX-License-Identifier: GPL-3.0-or-later
;; Version: 0.1.0
;; Package-Requires: ((emacs "29.1") (etaf-gamekit "0.1.0") (etaf-ui "0.1.0"))
;;; Commentary:
;; Salvage Station owns its Godot rules and native ETAF presentation. GameKit
;; supplies the shared backend connection and game instance lifetime.
;;
;; Variable: etaf-salvage-game
;; Inert game definition accepted by etaf-gamekit-start. Each start creates an
;; independent Godot world. The bundled native project is resolved from this
;; application entry, not from the GameKit repository.
;;
;; Variable: etaf-salvage-appearance
;; Initial palette of a new expedition: `auto' (default), `light' or `dark'.
;; `auto' follows the frame's background mode when the instance starts; changing
;; the palette from the running instance never restarts the Godot world.
;;
;; Function: etaf-salvage-open ()
;;;###autoload (autoload 'etaf-salvage-open "etaf-salvage" nil t)
;; Start and display an independent expedition; return its GameKit instance.
;; It starts paused without implicit snapshot restoration. Close the instance
;; through etaf-gamekit-close or kill its buffer; no implicit save is performed.
;;
;;; Code:
(require 'etaf-gamekit)
(require 'etaf-ui)
(defconst etaf-salvage--directory
  (file-name-directory (or load-file-name buffer-file-name)))
(let ((load-path (cons (expand-file-name "lisp" etaf-salvage--directory) load-path)))
  (require 'etaf-salvage-app))
(provide 'etaf-salvage)
;;; etaf-salvage.el ends here
