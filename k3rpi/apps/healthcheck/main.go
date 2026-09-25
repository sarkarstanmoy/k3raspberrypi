package main

import (
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
	httpSwagger "github.com/swaggo/http-swagger/v2"

	_ "healthcheck/docs"
)

// @title       Healthcheck API
// @version     1.0
// @description Liveness endpoint for the k3rpi cluster.
// @host        localhost:3000
// @BasePath    /api/v1
func main() {
	r := chi.NewRouter()
	r.Use(middleware.Logger)
	r.Route("/api/v1", func(r chi.Router) {
		r.Get("/healthcheck", healthcheck)
	})

	r.Get("/swagger/*", httpSwagger.Handler(
		httpSwagger.URL("http://localhost:3000/swagger/doc.json"), // Points to the generated json
	))

	http.ListenAndServe(":3000", r)
}

// healthcheck reports service liveness.
// @Summary     Health check
// @Description Reports whether the service is up
// @Tags        health
// @Produce     plain
// @Success     200 {string} string "Healthy"
// @Router      /healthcheck [get]
func healthcheck(w http.ResponseWriter, r *http.Request) {
	w.Write([]byte("Healthy"))
}
