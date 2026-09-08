package main

//node colors
color_red : Color = {1,0,0,1}
color_blue : Color = {0,0,1,1}
color_green : Color = {0,1,0,1}
color_white : Color = {1,1,1,1}


// Default slate palette (normalized RGBA). Assign roles in config.odin;
// UI construction and rendering should consume Config, not these swatches.
color_slate_base: Color = {18.0/255, 24.0/255, 34.0/255, 1} // #121822
color_slate_surface: Color = {24.0/255, 32.0/255, 44.0/255, 1} // #18202C
color_slate_hover: Color = {39.0/255, 57.0/255, 78.0/255, 1} // #27394E
color_slate_border: Color = {52.0/255, 65.0/255, 83.0/255, 1} // #344153
color_ice_accent: Color = {126.0/255, 195.0/255, 224.0/255, 1} // #7EC3E0
color_text_primary: Color = {232.0/255, 238.0/255, 245.0/255, 1} // #E8EEF5
color_text_muted: Color = {169.0/255, 184.0/255, 202.0/255, 1} // #A9B8CA

