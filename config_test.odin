package main

import "base:runtime"
import "core:encoding/json"
import "core:os"
import "core:strings"
import "core:testing"

// Builds a disposable config neighborhood so tests never redecorate the user's real AppData.
make_test_config_paths :: proc(t: ^testing.T) -> (directory, path: string, ok: bool) {
    directory_err: os.Error
    directory, directory_err = os.make_directory_temp(
        "",
        "thor-start-config-*",
        context.allocator,
    )
    if !testing.expect(t, directory_err == nil, "could not create temporary config directory") {
        return "", "", false
    }

    path_err: runtime.Allocator_Error
    path, path_err = os.join_path({directory, CONFIG_FILE_NAME}, context.allocator)
    if !testing.expect(t, path_err == nil, "could not construct temporary config path") {
        _ = os.remove(directory)
        delete(directory)
        return "", "", false
    }
    return directory, path, true
}

// Cleans the tiny test neighborhood before it starts demanding property taxes.
destroy_test_config_paths :: proc(directory, path: string) {
    _ = os.remove(path)
    _ = os.remove(directory)
    delete(path)
    delete(directory)
}

// Proves a missing config becomes a real file containing the application's defaults.
@(test)
missing_config_creates_default_file :: proc(t: ^testing.T) {
    directory, path, ok := make_test_config_paths(t)
    if !ok {
        return
    }
    defer destroy_test_config_paths(directory, path)

    config := load_config_from_path(directory, path)

    testing.expect(t, os.exists(path), "default config file was not created")
    testing.expect_value(t, config.width, default_config.width)
    testing.expect_value(t, config.app_list_font_size, default_config.app_list_font_size)

    data, read_err := os.read_entire_file(path, context.temp_allocator)
    if !testing.expect(t, read_err == nil, "could not read the generated config") {
        return
    }
    testing.expect(
        t,
        strings.contains(string(data), `"app_list_highlighting"`),
        "generated config exposed the internal highlighting typo",
    )

    written_config: Config
    parse_err := json.unmarshal(data, &written_config)
    if !testing.expect(t, parse_err == nil, "generated config was not valid JSON") {
        return
    }
    testing.expect_value(
        t,
        written_config.app_list_font_size,
        default_config.app_list_font_size,
    )
}

// Confirms partial JSON changes one preference while every omitted value keeps its safety net.
@(test)
partial_config_keeps_unspecified_defaults :: proc(t: ^testing.T) {
    directory, path, ok := make_test_config_paths(t)
    if !ok {
        return
    }
    defer destroy_test_config_paths(directory, path)

    write_err := os.write_entire_file(path, `{"app_list_font_size": 23}`)
    if !testing.expect(t, write_err == nil, "could not write partial test config") {
        return
    }

    config := load_config_from_path(directory, path)

    testing.expect_value(t, config.app_list_font_size, f32(23))
    testing.expect_value(t, config.width, default_config.width)
    testing.expect_value(t, config.app_list_icon_size, default_config.app_list_icon_size)
}

// Ensures malformed JSON gets benched while the defaults confidently finish the game.
@(test)
malformed_config_uses_defaults :: proc(t: ^testing.T) {
    directory, path, ok := make_test_config_paths(t)
    if !ok {
        return
    }
    defer destroy_test_config_paths(directory, path)

    write_err := os.write_entire_file(path, `{ definitely-not-json }`)
    if !testing.expect(t, write_err == nil, "could not write malformed test config") {
        return
    }

    config := load_config_from_path(directory, path)

    testing.expect_value(t, config.width, default_config.width)
    testing.expect_value(t, config.app_list_font_size, default_config.app_list_font_size)
}
