package main

import (
	"net/http"

	"github.com/labstack/echo"
	"github.com/labstack/echo/middleware"
	rice "github.com/GeertJohan/go.rice"
)


func main() {
	e := echo.New()
	e.Use(middleware.Logger())
	e.Use(middleware.Recover())

	assets := http.FileServer(rice.MustFindBox("./assets").HTTPBox())
	e.GET("/*", echo.WrapHandler(assets))

	e.Logger.Fatal(e.Start("127.0.0.1:5000"))
}
