// This simple program serves a plain text HTTP page displaying which
// port it's listening on, when the process was started and the
// hostname.

package main

import (
	"flag"
	"fmt"
	"net/http"
	"os"
	"time"
)

func hello(w http.ResponseWriter, r *http.Request, listenSpec string, start string, hostname string) {
	fmt.Fprintf(w, "Hello world!\n"+
		"Listening on: %s\n"+
		"Started on: %s\n"+
		"Hostname: %s\n", listenSpec, start, hostname)
}

func main() {
	port := flag.Int("port", 8080, "HTTP port number")
	flag.Parse()

	listenSpec := fmt.Sprintf(":%d", *port)
	start := time.Now().String()
	hostname, _ := os.Hostname()

	fmt.Printf("Serving on %s.....\n", listenSpec)

	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		hello(w, r, listenSpec, start, hostname)
	})
	http.ListenAndServe(listenSpec, nil)
}
