(ns hardmode-ui-hypertext.server
  (:require
    [browserify]
    [fs]
    [http]
    [hyperscript        :as $]
    [mori               :refer [hash-map assoc dissoc merge set into
                                vector first get-in conj partial
                                filter map each to-clj to-js is-vector]]
    [path]
    [send-data]
    [send-data.json     :as    send-json]
    [send-data.html     :as    send-html]
    [send-data.error    :as    send-error]
    [url]
    [util]
    [wisp.runtime       :refer [= str or not nil?]]
    [wisp.sequence      :refer [reduce]]))

(defn server
  " Create and launch an HTTP server.
    Use this to get a GUI in your browser. "
  [port & body]
  (fn [context]
    (let [server  (http.createServer)
          context (assoc (or context (hash-map)) :server server)]
      (console.log "Listening on" port)
      (server.listen port)
      (let [new-context (reduce (fn [context member] (member context))
                                (hash-map) body)]
        (server.on "request" (get-request-handler new-context))
        new-context))))

(defn route [pattern handler]
  " A route is an URL pattern with a handler function. "
  (hash-map :pattern pattern
            :handler handler))

(defn add-route [context new-route]
  " Add a route to context.routes, creating it if missing. "
  (let [routes (or (mori.get context "routes") (vector))]
    (assoc context :routes (conj routes new-route))))

(defn add-routes [context & routes]
  " Convenience function for adding multiple routes. "
  (reduce add-route context routes))

(defn get-request-handler [context]
  " Return a function which finds the correct route
    for the requested URL and writes an HTTP response. "
  (fn request-handler [request response]
    (let [routes   (mori.get context "routes")
          url-path (aget (url.parse request.url) "pathname")
          match    (fn [route] (= url-path (mori.get route "pattern")))
          route    (first (filter match routes))]
      (console.log "Requested" url-path)
      (if route
        ((mori.get route "handler") request response)
        (send-error request response { "body" (Error. "404") })))))

; TODO :) allow for more than one page
; TODO :/ fix source maps
; TODO :/ use remapify or similar for shorter require paths

(defn page [pattern script]
  (fn [context]

    (let [br (browserify { :debug      false
                           :extensions [ ".wisp" ]})]

      (br.add (path.resolve (path.join
        (path.dirname (require.resolve "wisp/runtime")) "engine" "browser.js")))
      (br.require (path.join __dirname "client.wisp") { :expose "client" })
      (br.transform (require "wispify") { :global true })
      (br.transform (require "stylify") { :global true })

      (add-routes context

        (route pattern
          (fn [request response]
            (send-html request response (str
              "<!doctype html>"
              (.-outerHTML (page-template context))))))

        (route (str pattern "script")
          (fn [request response]
            (br.bundle (fn [error bundled]
              (if error (throw error))
              (send-data request response (bundled.toString "utf8"))))))))))

; TODO allow for specifying a custom title
(defn page-template
  " Generic HTML page template. "
  [context]
  ($ "html" [
    ($ "head" [
      ($ "meta" { :charset "utf-8" })
      ($ "title" "Boepripasi") ])
    ($ "body" [
      ($ "script" { :src "/script" })
      ($ "script" { :type "application/wisp" } (get-init-script context))])]))

(defn get-init-script
  " Generate the function call which bootstraps widgets into existence. "
  [context]
  (let [add-widget-initializer (fn [acc wid] (str acc "\n  " wid))]
    (str
      "\n(.init-application! (require \"client\")"
      (mori.reduce add-widget-initializer "" (mori.get context "widgets"))
      ")")))

(defn widget
  " A standalone GUI control. Expects options to be a Mori hash-map. "
  [w-dir id options]
  (let [o         (partial mori.get options)
        w-name    (path.basename w-dir)
        w-rel     (fn [filename] (path.join w-dir filename))
        if-exists (fn [filename] (if (fs.existsSync filename) filename nil))
        script    (or (o "script") (if-exists (w-rel "client.wisp")))
        style     (or (o "style")  (if-exists (w-rel "style.styl")))
        requires  [script style]
        requires  (apply vector (requires.filter (fn [v] (not (nil? v)))))
        defaults  (hash-map :widget   w-name
                            :id       id
                            :path     w-dir
                            :script   script
                            :style    style
                            :requires requires)]
    (merge defaults options)))

(defn widget-container
  " A widget which can contain other widgets. "
  [w-dir id options body]
  (let [widget (widget w-dir id options)
        body   (to-clj body)
        add-to (fn [acc wid] (into acc (mori.get wid "requires")))
        deps   (mori.reduce add-to (set) body)]
    (assoc widget
      :body     (into (vector) (map (fn [member] (dissoc member "requires")) body))
      :requires (into (or (mori.get widget "requires") (vector)) deps))))

; TODO :) add widgets to page not context
(defn add-widget!
  " Add a widget to the context and register it with Browserify. "
  [context widget]
  (let [c  (partial mori.get context)
        w  (partial mori.get widget)
        br (c "browserify")]
    (mori.each (w "requires") (fn [file] (br.require file)))
    (assoc context :widgets
      (conj (or (c "widgets") (vector))
        (dissoc widget "requires" "dir")))))

(defn add-widgets [context & widgets]
  " Convenience function for adding multiple widgets. "
  (reduce add-widget context widgets))

; manually require and export everything in ./widgets
(let [rel       (partial path.join __dirname "widgets")
      is-dir?   (fn [dir] (.isDirectory (fs.statSync (rel dir))))
      dirs      (.filter (fs.readdirSync (rel "")) is-dir?)
      fullpath  (fn [wid] (path.resolve (rel wid "server.wisp")))
      widgets   {}
      exporter  (fn [wid] (let [widget-module (require (fullpath wid))
                                widget-name   widget-module.name]
                  (set! (aget widgets widget-name) widget-module)))]
  (dirs.map exporter)
  (set! (aget module.exports "widgets") widgets))
