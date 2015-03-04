(ns hardmode-ui-hypertext.widget
  (:require
    [fs]
    [hardmode-ui-hypertext.template :as template]
    [mori         :refer [assoc conj hash-map merge partial to-clj vector]]
    [path]
    [wisp.runtime :refer [or =]]))

(defn widget [w-dir id options]
  (let [w-name    (path.basename w-dir)
        w-path    (fn [suffix] (path.join w-dir (str w-name suffix)))
        if-exists (fn [filename] (if (fs.existsSync filename) filename))]
    (merge
      (hash-map
        :name     w-name
        :dir      w-dir
        :script   (if-exists (w-path "_client.wisp"))
        :style    (if-exists (w-path ".styl"))
        :id       id)
      (apply hash-map options))))

(defn add-widget [context widget]
  (let [c  (partial mori.get context)
        w  (partial mori.get widget)
        br (c "browserify")]
    (if (w "script") (br.require (w "script")))
    (if (w "style")  (br.require (w "style")))
    (assoc context :widgets
      (assoc (or (c "widgets") (hash-map)) (w "id") widget))))

(defn add-widgets [context & widgets]
  (reduce add-widget context widgets))
