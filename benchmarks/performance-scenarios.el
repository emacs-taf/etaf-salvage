;;; -*- lexical-binding: t; -*-
;;; performance-scenarios.el --- Salvage Station interaction workloads
;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Code:
(require 'etaf-salvage)
(declare-function taf-benchmark-register "performance-driver" (id &rest properties))
(defun etaf-salvage-benchmark--text (session)
  "Read SESSION's rendered text without properties."
  (with-current-buffer (etaf-gamekit-buffer session)
    (buffer-substring-no-properties (point-min) (point-max))))

(defun etaf-salvage-benchmark--fixture (mode operation)
  "Create a complete game surface for MODE and measured OPERATION."
  (let* ((session (etaf-salvage-open))
         (runtime (etaf-runtime-for-buffer (etaf-gamekit-buffer session)))
         (expected nil) (target nil))
    (list
     :buffer (etaf-gamekit-buffer session)
     :ready (lambda ()
              (if (eq mode 'batch) (etaf-runtime-refit runtime 1200 46)
                (etaf-refit runtime (selected-window)))
              (and (eq (etaf-gamekit-status session) 'ready)
                   (etaf-host-ref-size runtime 'salvage-map)))
     :invoke
     (lambda (index)
       (pcase operation
         ('select
          (setq expected (if (cl-evenp index) "Power core 1" "Power core 2"))
          (etaf-dispatch-event runtime (if (cl-evenp index) 'salvage-tile-3-12 'salvage-tile-4-26) 'press))
         ('route
          (setq expected (if (cl-evenp index) '(6 4) '(6 5))
                target (if (cl-evenp index) 'salvage-tile-4-6 'salvage-tile-5-6))
          (etaf-dispatch-event runtime target 'press))
         ('resize
          (setq expected (if (cl-evenp index) 900 1200))
          (etaf-runtime-refit runtime expected 46))))
     :settled
     (lambda ()
       (pcase operation
         ('select (string-match-p expected (etaf-salvage-benchmark--text session)))
         ('route
          (and (eq (etaf-gamekit-status session) 'ready)
               (equal (car (last (plist-get (plist-get (etaf-gamekit-observation session) :world) :route))) expected)
               (equal (plist-get (etaf-runtime-host-props-for runtime target) :color) "#73BDEB")))
         ('resize (= (car (etaf-runtime-viewport runtime)) expected))))
     :verify (lambda () (or (etaf-gamekit-last-error session) t))
     :outcome (lambda () (list :operation (symbol-name operation)
                                  :map (let ((size (etaf-host-ref-size runtime 'salvage-map)))
                                         (vector (car size) (cdr size)))))
     :cleanup (lambda () (etaf-gamekit-close session)
                (kill-buffer (etaf-gamekit-buffer session))))))

(dolist (case '((select 16 "Select an object and publish target intelligence")
                (route 50 "Deck click through Godot pathfinding to painted route")
                (resize 50 "Refit a fixed-cell game between 900 and 1200 pixels")))
  (let ((operation (car case)))
    (taf-benchmark-register
     (format "etaf-salvage.%s" operation)
     :version 2 :modes '(batch gui) :isolation 'series :impact 'subtree
     :budget-ms (cadr case) :description (caddr case)
     :setup (lambda (mode) (etaf-salvage-benchmark--fixture mode operation)))))

(provide 'etaf-salvage-performance-scenarios)
