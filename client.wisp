(ns hardmode-ui-hypertext.client
  (:require [event-sinks]
            [html-delegator]
            [insert-css]
            [observ                     :as observer]
            [observ.watch               :as watch-value!]
            [virtual-dom.create-element :as create-element]
            [virtual-dom.diff           :as diff]
            [virtual-dom.h              :as $]
            [virtual-dom.patch          :as patch]))

(set! window.HARDMODE         (or window.HARDMODE         {}))
(set! window.HARDMODE.widgets (or window.HARDMODE.widgets {}))

(defn init-widgets! [& widgets]
  (console.log "Initializing a bunch of widgets:" widgets)
  (widgets.map (fn [widget]
    (console.log "Initializing widget:" widget)
    (let [script (require (:script widget))]
      (set! (aget window.HARDMODE.widgets (:id widget))
            (if script.init (script.init! widget)
                            (init-widget! widget)))))))

(def init-application! init-widgets!)

(defn init-widget! [widget]
  (let [style (require (:style widget))]
    (if style (insert-css style)))

  (let [state (observer (:initial widget))]
    (set! (aget widget "state") state)
    (watch-value! state (get-updater widget)))

  (let [delegator (html-delegator)
        sinks     (event-sinks [])
        events    { :delegator delegator
                    :sinks     sinks }]
    (set! (aget widget "events") events))

  widget)

(defn get-updater [widget]
  (fn update-widget! [state]
    (let [template (:template (require (:script widget)))]
      (if template
          (let [element   (:element widget)
                new-vtree (template widget state)]
            (if element
              (let [old-vtree (:vtree widget)
                    patches   (diff old-vtree new-vtree)]
                (set! (aget widget "vtree")   new-vtree)
                (set! (aget widget "element") (patch element patches)))
              (let [element   (create-element! new-vtree)]
                (set! (aget widget "vtree")   new-vtree)
                (set! (aget widget "element") element)
                (document.body.appendChild    element))))))))
