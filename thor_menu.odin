package main

import sdl "vendor:sdl3"
import "core:fmt"
import "base:runtime"
config:: struct{
    title: cstring,
    width: i32,
    height: i32,
    appversion: cstring
}


default: config = {
    title = "Thor",
    width = 400,
    height = 600,
    appversion = "0.0.1"
}

menu :: struct {
    conf : config,
    wind: ^sdl.Window,
    quit: bool
}

window_init :: proc "c" ()->^menu{
    Menu := &menu{quit=false}
    context = runtime.default_context()
    Menu.conf = default

    ok := sdl.Init(sdl.INIT_VIDEO)
    if !ok{
        fmt.println("error could not activate sdl")
        return Menu
    }

    window := sdl.CreateWindow(Menu.conf.title,Menu.conf.width,Menu.conf.height,sdl.WINDOW_ALWAYS_ON_TOP)
    if window == nil{
        fmt.println("error on sdl window creation")
        fmt.println(sdl.GetError())
        return Menu
    }
    ok = sdl.SetAppMetadata(
        Menu.conf.title,
        Menu.conf.appversion,
        nil
    )
    Menu.wind = window
    ok = sdl.ShowWindow(window)
    if !ok{
        fmt.println("error could not activate window")
        return Menu
    }

    fmt.println("window initiated")
    evnt :sdl.Event
    for(!Menu.quit) {
        for (sdl.PollEvent(&evnt)){
            if (evnt.type == sdl.EventType.QUIT){
                Menu.quit = true
            }
        }
    }
    
    sdl.Quit()
    return Menu
}