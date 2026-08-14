package main

import "base:runtime"
import "core:fmt"
import windows "core:sys/windows"


main :: proc() {

    
    err := bindWinKey()
    fmt.println(err)

}
