package main

import (
	"fmt"
	"log"
	"net/http"
	"os"
)

var version = "dev"

func helloHandler(w http.ResponseWriter, r *http.Request) {
	fmt.Fprintf(w, "Hello, DevOps! version=%s\n", version)
}

func main() {
	http.HandleFunc("/", helloHandler)

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}
	fmt.Println("listening on :" + port)
	log.Fatal(http.ListenAndServe(":"+port, nil))
}
