package main

import (
	"net/http"
	"log"
	"net"
	"time"

	"github.com/labstack/echo"
	"github.com/labstack/echo/middleware"
	rice "github.com/GeertJohan/go.rice"
	"github.com/tatsushid/go-fastping"
	"github.com/timshannon/bolthold"
	"github.com/sabhiram/go-wol"
)

type Machine struct {
	Name string `json:"name"`
	Ip string `json:"ip" boltholdIndex:"Ip"`
	MacAddress string `json:"mac"`
	Up bool `json:"up"`
}

type App struct {
	Store *bolthold.Store
}

func (app *App) listMachine(c echo.Context) error {
	var machines []Machine
	app.Store.Find(&machines, bolthold.Where(bolthold.Key).Ne(""))

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

	app.Store.Upsert(m.Ip, m)
	return c.Redirect(http.StatusSeeOther, "/api/v1/machines")
}

func (app *App) deleteMachine(c echo.Context) error {
	ip := c.Param("ip")
	app.Store.DeleteMatching(&Machine{}, bolthold.Where(bolthold.Key).Eq(ip))
	return c.Redirect(http.StatusSeeOther, "/api/v1/machines")
}

func (app *App) wakeMachine(c echo.Context) error {
	ip := c.Param("ip")
	m := Machine{}

	if err := app.Store.Get(ip, &m); err != nil {
		return c.JSON(http.StatusNotFound, err)
	}

	err := wol.SendMagicPacket(m.MacAddress, "255.255.255.255:9", "")
	if err != nil {
		return c.JSON(http.StatusInternalServerError, err)
	}

	return c.Redirect(http.StatusSeeOther, "/api/v1/machines")
}

func main() {
	store, err := bolthold.Open("data.db", 0666, nil)
	if err != nil {
		log.Fatalln(err)
	}

	app := App{store}

	e := echo.New()
	e.Use(middleware.Logger())
	e.Use(middleware.Recover())

	e.GET("/api/v1/machines", app.listMachine)
	e.POST("/api/v1/machines", app.createMachine)
	e.DELETE("/api/v1/machines/:ip", app.deleteMachine)
	e.PATCH("/api/v1/machines/:ip", app.wakeMachine)

	assets := http.FileServer(rice.MustFindBox("./assets").HTTPBox())
	e.GET("/*", echo.WrapHandler(assets))

	e.Logger.Fatal(e.Start("127.0.0.1:5000"))
}
