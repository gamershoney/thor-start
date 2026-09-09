package main

import "core:log"
import "core:os"

init_file_logger :: proc() -> (logger: log.Logger, ok: bool) {
    logger = log.nil_logger()
    directory, _, paths_ok := config_file_paths()
    if !paths_ok do return
    if err := os.make_directory_all(directory); err != nil do return
    path, err := os.join_path({directory, "thor-start.log"}, context.temp_allocator)
    if err != nil do return
    file, open_err := os.open(path, {.Write, .Append, .Create}, os.Permissions_Default_File)
    if open_err != nil do return
    return log.create_file_logger(file, .Info, ident = "thor-start"), true
}

shutdown_file_logger :: proc(logger: log.Logger, active: bool) {
    if active do log.destroy_file_logger(logger)
}
