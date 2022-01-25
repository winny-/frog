#lang at-exp racket/base

(require racket/require
         (multi-in racket (contract date file format string system))
         scribble/reader
         threading
         "params.rkt"
         "paths.rkt"
         (only-in "util.rkt"
                  display-to-file*)
         "verbosity.rkt")

(provide new-post)

(define/contract (new-post title type and-edit?)
  (-> string? (or/c 'markdown 'scribble) boolean? void?)
  (define-values (extension template)
    (case type
      [(markdown) (values ".md"    new-markdown)]
      [(scribble) (values ".scrbl" new-scribble)]))
  (define-values (date-only-str date-time-str)
    (let ([now (current-date)])
      (parameterize ([date-display-format 'iso-8601])
        (values (date->string now #f)
                (date->string now #t)))))
  (define filename (~a date-only-str
                       "-"
                       (~> title string-downcase slug)
                       extension))
  (define pathname (build-path (src/posts-path) filename))
  (cond [(file-exists? pathname)
         (unless and-edit?
           (raise-user-error 'new-post "~a already exists." pathname))]
        [else (display-to-file* #:exists 'error
                                (template title date-time-str)
                                pathname)])
  (displayln pathname)
  (when and-edit?
    (system (editor-command-string
             (replace-$editor-in-current-editor)
             (path->string pathname)
             (current-editor-command)))))

(define-namespace-anchor anc)
(define (render text-body title date)
  (eval `(let ([title ,title]
               [date ,date])
          (string-join (list ,@text-body) ""))
        (namespace-anchor->namespace anc)))

(define (new-markdown title date)
  (cond
    [(file-exists? "post-template.md")
     (prn1 "Using post-template.md")
     (render (call-with-input-file "post-template.md" read-inside) title date)]
    [else
     @~a{Title: @title
         Date: @date
         Tags: DRAFT

         _Replace this with your post text. Add one or more comma-separated
         Tags above. The special tag `DRAFT` will prevent the post from being
         published._

         <!-- more -->


         }]))

(define (new-scribble title date)
  (cond
    [(file-exists? "post-scribble.scrbl")
     (prn1 "Using post-scribble.scrbl")
     (render (call-with-input-file "post-template.scrbl" read-inside) title date)]
    [else
     @~a{#lang scribble/manual

          Title: @title
          Date: @date
          Tags: DRAFT

          Replace this with your post text. Add one or more comma-separated
          Tags above. The special tag `DRAFT` will prevent the post from being
          published.

          <!-- more -->


          }]))

(define (get-editor . _)
  (or (getenv "EDITOR") (getenv "VISUAL")
      (raise-user-error
       'new-post
       "EDITOR or VISUAL must be defined in the environment to use $EDITOR in frog.rkt")))

(define (replace-$editor-in-current-editor)
  (regexp-replaces (current-editor) `([#rx"\\$EDITOR" ,get-editor])))
