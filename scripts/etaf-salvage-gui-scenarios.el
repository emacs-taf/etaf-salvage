;;; -*- lexical-binding: t; -*-
;;; etaf-salvage-gui-scenarios.el --- Existing-frame Salvage Station acceptance

;; SPDX-License-Identifier: GPL-3.0-or-later
;; This development adapter uses the documented generic GUI verifier tool.
;;; Code:
(require 'etaf-salvage)
(require 'emacs-gui-verifier)

(defun etaf-salvage-gui--session (context)
  "Read the game session owned by CONTEXT."
  (etaf-gui-verifier-context-get context 'game))

(defun etaf-salvage-gui--runtime (context)
  "Read the mounted game runtime in CONTEXT."
  (etaf-runtime-for-buffer (etaf-gamekit-buffer (etaf-salvage-gui--session context))))

(defun etaf-salvage-gui--text (context)
  "Read CONTEXT's visible game text without properties."
  (with-current-buffer (etaf-gamekit-buffer (etaf-salvage-gui--session context))
    (buffer-substring-no-properties (point-min) (point-max))))

(defun etaf-salvage-gui--size (width rows)
  "Resize the existing frame toward WIDTH pixels and ROWS text lines."
  (let ((chrome (- (frame-pixel-height) (window-body-height nil t))))
    (set-frame-parameter nil 'fullscreen nil)
    (set-frame-size nil width (+ chrome (* rows (frame-char-height))) t)))

(defun etaf-salvage-gui--fit-p (context)
  "Whether CONTEXT's game matches its live window and fits its usable range."
  (let* ((runtime (etaf-salvage-gui--runtime context))
         (viewport (etaf-runtime-viewport runtime))
         (root (etaf-host-ref-size runtime 'salvage-root))
         (cell (etaf-host-ref-size runtime 'salvage-tile-0-0)))
    (and root cell (eq (etaf-gamekit-status (etaf-salvage-gui--session context)) 'ready)
         (<= 0 (- (window-body-width nil t) (car viewport)) (* 2 (frame-char-width)))
         (= (cdr viewport) (window-body-height))
         (<= (car root) (max (* 38 (car cell)) (car viewport)))
         (<= (cdr root) (max 30 (cdr viewport))))))

(defun etaf-salvage-gui--play-action (id refs predicate)
  "Create a rendered game action ID using REFS and observation PREDICATE."
  (etaf-gui-verifier-action-create
   :id id :screenshot t :settle-timeout 10
   :execute (lambda (context)
              (dolist (ref refs)
                (etaf-dispatch-event (etaf-salvage-gui--runtime context) ref 'press)))
   :settled-p (lambda (context)
                (funcall predicate (etaf-gamekit-view (etaf-salvage-gui--session context))))))

(defun etaf-salvage-gui-run (directory)
  "Run the game GUI scenario in fresh DIRECTORY using the existing frame.
Leave the game visible in tactical pause and restore the original frame size.
Screenshots require visual review; use the performance driver for latency."
  (unless (display-graphic-p) (error "A graphical Emacs frame is required"))
  (let ((size (list (frame-pixel-width) (frame-pixel-height)))
        (fullscreen (frame-parameter nil 'fullscreen)))
    (unwind-protect
        (etaf-gui-verifier-run
         (etaf-gui-verifier-scenario-create
          :name "salvage-station"
          :claim "Native game interaction and responsive width/height layouts"
          :initialize
          (lambda (context)
            (let* ((etaf-salvage-appearance 'dark)
                   (session (etaf-salvage-open)))
              (etaf-gui-verifier-context-put context 'game session)
              (etaf-gui-verifier-context-select-buffer context (etaf-gamekit-buffer session))))
          :invariants
          (lambda (context)
            (append
             (let ((mission (etaf-gamekit-view (etaf-salvage-gui--session context) :mission)))
               (when (or (eq t (plist-get mission :won)) (eq t (plist-get mission :lost)))
                 (list (etaf-gui-verifier-assert
                        "Ended expedition removes prior controls from the painted output"
                        (and (not (etaf-host-ref-size (etaf-salvage-gui--runtime context) 'salvage-pause))
                             (not (string-match-p "P +PAUSE" (etaf-salvage-gui--text context))))))))
             (when-let* ((size (etaf-host-ref-size (etaf-salvage-gui--runtime context) 'salvage-map)))
               (let ((original (etaf-gui-verifier-context-get context 'canvas-size)))
                 (unless original (etaf-gui-verifier-context-put context 'canvas-size size))
                 (list (etaf-gui-verifier-assert "Game canvas keeps its intrinsic size"
                                                (or (null original) (equal original size))))))
             (etaf-gui-verifier-line-height-assertions
                     (etaf-gamekit-buffer (etaf-salvage-gui--session context)))
                    (list (etaf-gui-verifier-assert
                           "Live engine has no rejected action or transport error"
                           (not (etaf-gamekit-last-error (etaf-salvage-gui--session context)))))))
          :actions
          (append
           (mapcar
            (lambda (spec)
              (etaf-gui-verifier-action-create
               :id (car spec) :screenshot t
               :execute (lambda (_context) (etaf-salvage-gui--size (cadr spec) (caddr spec)))
               :settled-p #'etaf-salvage-gui--fit-p
               :assertions (lambda (context)
                             (list (etaf-gui-verifier-assert "Canvas fits its viewport or documented minimum"
                                                            (etaf-salvage-gui--fit-p context))))))
            '(("wide" 1400 48) ("standard" 1000 42) ("short" 1400 34)
              ("tall" 700 53) ("minimum-clipping" 420 20) ("compact" 640 32)))
           (list
            (etaf-gui-verifier-action-create
             :id "compact-panels" :screenshot t
             :execute (lambda (context)
                        (etaf-dispatch-event (etaf-salvage-gui--runtime context) 'salvage-show-panels 'press))
             :settled-p (lambda (context) (string-match-p "EXPEDITION CONSOLE" (etaf-salvage-gui--text context))))
            (etaf-gui-verifier-action-create
             :id "close-panels" :screenshot t
             :execute (lambda (_context) (execute-kbd-macro (kbd "<escape>")))
             :settled-p (lambda (context) (not (string-match-p "EXPEDITION CONSOLE" (etaf-salvage-gui--text context)))))
            (etaf-gui-verifier-action-create
             :id "interactive" :screenshot t :settled-p #'etaf-salvage-gui--fit-p
             :execute (lambda (_context) (etaf-salvage-gui--size 1100 44)))
            (etaf-gui-verifier-action-create
             :id "light-theme" :screenshot t
             :execute (lambda (context)
                        (etaf-dispatch-event (etaf-salvage-gui--runtime context) 'salvage-theme 'press))
             :settled-p (lambda (context) (string-match-p "Dark" (etaf-salvage-gui--text context))))
            (etaf-gui-verifier-action-create
             :id "dark-theme" :screenshot t
             :execute (lambda (context)
                        (etaf-dispatch-event (etaf-salvage-gui--runtime context) 'salvage-theme 'press))
             :settled-p (lambda (context) (string-match-p "Light" (etaf-salvage-gui--text context))))
            (etaf-gui-verifier-action-create
             :id "native-route" :screenshot t
             :execute (lambda (context)
                        (etaf-focus (etaf-salvage-gui--runtime context) 'salvage-tile-4-4)
                        (execute-kbd-macro (kbd "d d d")))
             :settled-p (lambda (context)
                          (equal (car (last (plist-get (plist-get
                            (etaf-gamekit-view (etaf-salvage-gui--session context)) :world) :route))) '(7 4))))
            (etaf-gui-verifier-action-create
             :id "inspect-core" :screenshot t
             :execute (lambda (context)
                        (etaf-dispatch-event (etaf-salvage-gui--runtime context) 'salvage-tile-3-12 'press))
             :settled-p (lambda (context) (string-match-p "Power core 1" (etaf-salvage-gui--text context))))
            (etaf-gui-verifier-action-create
             :id "objectives" :screenshot t
             :execute (lambda (context)
                        (etaf-dispatch-event (etaf-salvage-gui--runtime context) 'salvage-objectives-tab 'press))
             :settled-p (lambda (context) (string-match-p "Recover three power cores" (etaf-salvage-gui--text context))))
            (etaf-gui-verifier-action-create
             :id "help" :screenshot t
             :execute (lambda (context)
                        (etaf-dispatch-event (etaf-salvage-gui--runtime context) 'salvage-help 'press))
             :settled-p (lambda (context) (string-match-p "FLIGHT MANUAL" (etaf-salvage-gui--text context))))
            (etaf-gui-verifier-action-create
             :id "close-help" :screenshot t
             :execute (lambda (_context) (execute-kbd-macro (kbd "<escape>")))
             :settled-p (lambda (context) (not (string-match-p "FLIGHT MANUAL" (etaf-salvage-gui--text context)))))
            (etaf-salvage-gui--play-action
             "recover-first-core" '(salvage-route-target salvage-pause)
             (lambda (view) (= (plist-get (plist-get view :pilot) :cores) 1)))
            (etaf-salvage-gui--play-action
             "disable-drone" '(salvage-pulse)
             (lambda (view) (< (plist-get (plist-get view :mission) :drones) 3)))
            (etaf-salvage-gui--play-action
             "recover-second-core" '(salvage-tile-4-26 salvage-route-target salvage-shield)
             (lambda (view) (= (plist-get (plist-get view :pilot) :cores) 2)))
            (etaf-salvage-gui--play-action
             "recover-third-core" '(salvage-tile-14-26 salvage-route-target)
             (lambda (view) (= (plist-get (plist-get view :pilot) :cores) 3)))
            (etaf-salvage-gui--play-action
             "extraction-complete" '(salvage-tile-14-3 salvage-route-target)
             (lambda (view) (eq t (plist-get (plist-get view :mission) :won))))
            (etaf-salvage-gui--play-action
             "new-expedition" '(salvage-new-expedition)
             (lambda (view) (and (= (plist-get (plist-get view :pilot) :cores) 0)
                                  (eq t (plist-get (plist-get view :mission) :paused))))))))
         directory)
      (set-frame-size nil (car size) (cadr size) t)
      (set-frame-parameter nil 'fullscreen fullscreen)))
  nil)

(provide 'etaf-salvage-gui-scenarios)
;;; etaf-salvage-gui-scenarios.el ends here
