(ns hardmode-ui-hypertext.client
  (:require [wisp.sequence :refer [map]]))

(defn init-widget! [widget]
  (let [container (document.createElement "div")
        template  (require (:template widget))]
    (set! (aget container "id") (str "container_" (:id widget)))
    (template widget (fn [err html]
      (if err (throw err))
      (set! (aget container "innerHTML") html)
      (document.body.appendChild container)))))

(defn init-widgets! [& widgets]
  (map init-widget! widgets))
