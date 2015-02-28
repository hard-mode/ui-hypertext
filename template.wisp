(ns hardmode-ui-hypertext.template
  (:require
    [fs]
    [jade]
    [path]
    [wisp.runtime :refer [=]]))

(defn path-absolute [p]
  (= (path.resolve p) (path.normalize p)))

(defn resolve [template]
  (if (path-absolute template) template
    (let [fullpath (path.resolve (path.join "." template))]
      (if (fs.exists-sync fullpath) fullpath
        (let [fullpath (path.resolve (path.join __dirname template))]
          (if (fs.exists-sync fullpath) fullpath
            (throw (Error. (str "Could not find template "
                                template)))))))))

(defn render [template context]
  (jade.renderFile (resolve template) context))