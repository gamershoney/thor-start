package main

import "core:encoding/json"
import "core:fmt"
import "core:os"

// Holds every user preference while remaining brave enough to survive a missing JSON file.
Config :: struct {
    width: f32                           `json:"width"`,
    height: f32                          `json:"height"`,
    background_color: Color             `json:"background_color"`,
    app_list_border: Border              `json:"app_list_border"`,
    search_bar_background_color: Color  `json:"search_bar_background_color"`,
    search_bar_border: Border            `json:"search_bar_border"`,
    app_list_highlighting: Hover_Unhover `json:"app_list_highlighting"`,
    app_list_text_color: Hover_Unhover   `json:"app_list_text_color"`,
    app_list_icon_size: f32              `json:"app_list_icon_size"`,
    app_list_font_size: f32              `json:"app_list_font_size"`,
    search_bar_text_color: Color         `json:"search_bar_text_color"`,
    search_bar_font_size: f32            `json:"search_bar_font_size"`,
    top_bar_background_color: Color      `json:"top_bar_background_color"`,
    top_bar_text_color: Color            `json:"top_bar_text_color"`,
    top_bar_border: Border               `json:"top_bar_border"`,
    top_bar_font_size: f32               `json:"top_bar_font_size"`,
    config_button_highlighting: Hover_Unhover `json:"config_button_highlighting"`,
    config_button_text_color: Color      `json:"config_button_text_color"`,
    app_refresh_interval_seconds: f32    `json:"app_refresh_interval_seconds"`,

}

// Stands ready with sensible values whenever disk access decides to take a personal day.
default_config: Config = {
    width = 600,
    height = 800,
    background_color = color_slate_base,
    app_list_border = {color = color_slate_border, sides = {right = 1}},
    search_bar_background_color = color_slate_surface,
    search_bar_border = {
        color = color_ice_accent,
        sides = {top = 1, bottom = 1, left = 1, right = 1},
    },
    app_list_highlighting = Hover_Unhover {
        hover_color = color_slate_hover,
        unhover_color = color_slate_base,
    },
    app_list_text_color = Hover_Unhover {
        hover_color = color_white,
        unhover_color = color_text_primary,
    },
    app_list_icon_size = 32,
    app_list_font_size = 17,
    search_bar_text_color = color_text_muted,
    search_bar_font_size = 17,
    top_bar_background_color = color_slate_surface,
    top_bar_text_color = color_text_primary,
    top_bar_border = {color = color_slate_border, sides = {bottom = 1}},
    top_bar_font_size = 15,
    config_button_highlighting = {hover_color = color_slate_hover, unhover_color = color_slate_surface},
    config_button_text_color = color_ice_accent,
    app_refresh_interval_seconds = 300,
}

// Gives every user setting a respectable home instead of making it live beside the executable.
CONFIG_DIRECTORY_NAME :: "Thor-Start"
CONFIG_FILE_NAME :: "config.json"

// Writes a friendly, human-editable config before the defaults can wander off unsupervised.
write_config_file :: proc(path: string, config: Config) -> bool {
    data, marshal_err := json.marshal(
        config,
        json.Marshal_Options{
            pretty = true,
            use_spaces = true,
            spaces = 2,
        },
        context.temp_allocator,
    )
    if marshal_err != nil {
        fmt.printfln("Could not serialize the default config: %v", marshal_err)
        return false
    }

    if write_err := os.write_entire_file(path, data); write_err != nil {
        fmt.printfln("Could not write config file %s: %v", path, write_err)
        return false
    }
    return true
}

// Layers user choices over safe defaults and refuses to let one grumpy file ruin startup.
load_config_from_path :: proc(config_directory, config_path: string) -> Config {
    if !os.exists(config_path) {
        if directory_err := os.make_directory_all(config_directory); directory_err != nil {
            fmt.printfln(
                "Could not create config directory %s: %v",
                config_directory,
                directory_err,
            )
            return default_config
        }

        write_config_file(config_path, default_config)
        return default_config
    }

    data, read_err := os.read_entire_file(config_path, context.temp_allocator)
    if read_err != nil {
        fmt.printfln("Could not read config file %s: %v", config_path, read_err)
        return default_config
    }

    config := default_config
    if parse_err := json.unmarshal(data, &config); parse_err != nil {
        fmt.printfln("Could not parse config file %s: %v", config_path, parse_err)
        return default_config
    }
    return config
}

// Discovers the operating system's preferred config shelf and brings back the best available settings.
load_config :: proc() -> Config {
    directory, path, ok := config_file_paths()
    if !ok do return default_config
    return load_config_from_path(directory, path)
}

// Both startup and the editor button resolve the exact same file.
// Returned paths use the temporary allocator.
config_file_paths :: proc() -> (directory, path: string, ok: bool) {
    user_config_directory, user_directory_err := os.user_config_dir(context.temp_allocator)
    if user_directory_err != nil {
        fmt.printfln("Could not discover the user config directory: %v", user_directory_err)
        return "", "", false
    }

    config_directory, directory_path_err := os.join_path(
        {user_config_directory, CONFIG_DIRECTORY_NAME},
        context.temp_allocator,
    )
    if directory_path_err != nil {
        fmt.printfln("Could not construct the config directory path: %v", directory_path_err)
        return "", "", false
    }

    config_path, config_path_err := os.join_path(
        {config_directory, CONFIG_FILE_NAME},
        context.temp_allocator,
    )
    if config_path_err != nil {
        fmt.printfln("Could not construct the config file path: %v", config_path_err)
        return "", "", false
    }
    return config_directory, config_path, true
}
