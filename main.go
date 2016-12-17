package main

import (
	"net/http"

	rice "github.com/GeertJohan/go.rice"
	"github.com/labstack/echo"
	"github.com/labstack/echo/middleware"
)


func main() {
	e := echo.New()
	e.Use(middleware.Logger())
	e.Use(middleware.Recover())

	assets := http.FileServer(rice.MustFindBox("assets").HTTPBox())
	e.GET("/", echo.WrapHandler(assets))

	e.Logger.Fatal(e.Start(":5000"))
}
