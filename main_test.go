package main

import (
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestHelloHandlerReturnsOK(t *testing.T) {
	rec := httptest.NewRecorder()
	helloHandler(rec, httptest.NewRequest(http.MethodGet, "/", nil))
	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d", rec.Code, http.StatusOK)
	}
}

func TestHelloHandlerShowsVersion(t *testing.T) {
	old := version
	version = "1.2.3-test"
	defer func() { version = old }()

	rec := httptest.NewRecorder()
	helloHandler(rec, httptest.NewRequest(http.MethodGet, "/", nil))
	want := "Hello, SALAH! version=1.2.3-test\n"
	if got := rec.Body.String(); got != want {
		t.Errorf("body = %q, want %q", got, want)
	}
}
