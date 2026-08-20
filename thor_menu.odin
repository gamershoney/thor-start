package main

import sdl "vendor:sdl3"
import "core:fmt"
import "base:runtime"
config:: struct{
    title: cstring,
    width: i32,
    height: i32
}


default: config = {
    title = "Thor",
    width = 400,
    height = 600
}



window_init :: proc "c" (){
    context = runtime.default_context()
    def := default

    ok := sdl.Init(sdl.INIT_VIDEO)
    if !ok{
        fmt.println("error could not activate sdl")
        return
    }

    window := sdl.CreateWindow(def.title,def.width,def.height,sdl.WINDOW_ALWAYS_ON_TOP)
    if window == nil{
        fmt.println("error on sdl window creation")
        fmt.println(sdl.GetError())
        return
    }
    ok = sdl.ShowWindow(window)
    if !ok{
        fmt.println("error could not activate window")
        return
    }
}