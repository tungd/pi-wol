package main

import (
	"encoding/json"
	"io/ioutil"
	"net/http"
	"log"
	"net"
	"time"

	"github.com/labstack/echo"
	"github.com/labstack/echo/middleware"
	rice "github.com/GeertJohan/go.rice"
	"github.com/tatsushid/go-fastping"
)

type Machine struct {
	Name string `json:"name"`
	Ip string `json:"ip"`
	MacAddress string `json:"mac"`
	Up bool `json:"up"`
}

type App struct {
	Data string
}

func (app *App) Read() []Machine {
	var machines []Machine
	data, err := ioutil.ReadFile(app.Data)
	if err != nil {
		log.Fatal("Error reading data file.")
	}
	json.Unmarshal(data, &machines)
	return machines
}

func (app *App) Write(ms []Machine) {
	data, _ := json.MarshalIndent(ms, "", "  ")
	ioutil.WriteFile(app.Data, data, 664)
}

func (app *App) listMachine(c echo.Context) error {
	machines := app.Read()

	results := make(map[string]*Machine)
	p := fastping.NewPinger()
	for i, m := range machines {
		ip, _ := net.ResolveIPAddr("ip4:icmp", m.Ip)
		results[m.Ip] = &machines[i]
		p.AddIPAddr(ip)
	}
	p.OnRecv = func(addr *net.IPAddr, rtt time.Duration) {
		m := results[addr.String()]
		results[m.Ip].Up = true
		log.Printf("%s: up\n", addr)
	}
	p.OnIdle = func() {
		log.Println("Finished")
	}
	if err := p.Run(); err != nil {
		log.Fatalln(err)
	}
	return c.JSON(http.StatusOK, machines)
}

func (app *App) createMachine(c echo.Context) error {
	m := Machine{}
	if err := c.Bind(&m); err != nil {
		return c.JSON(http.StatusBadRequest, err)
	}

	machines := append(app.Read(), m)
	app.Write(machines)
	return c.JSON(http.StatusCreated, machines)
}

func (app *App) deleteMachine(c echo.Context) error {
	ip := c.Param("ip")
	machines := []Machine{}
	for _, m := range app.Read() {
		if m.Ip != ip {
			machines = append(machines, m)
		}
	}
	app.Write(machines)
	return c.JSON(http.StatusOK, machines)
}

func main() {
	app := App{"data.json"}

	e := echo.New()
	e.Use(middleware.Logger())
	e.Use(middleware.Recover())

	e.GET("/api/v1/machines", app.listMachine)
	e.POST("/api/v1/machines", app.createMachine)
	e.DELETE("/api/v1/machines/:ip", app.deleteMachine)

	assets := http.FileServer(rice.MustFindBox("./assets").HTTPBox())
	e.GET("/*", echo.WrapHandler(assets))

	e.Logger.Fatal(e.Start("127.0.0.1:5000"))
}
