struct VS_Input {
    float3 position : POSITION;
    float4 color : COLOR;
};

struct VS_Output {
    float4 position : SV_POSITION;
    float4 color : COLOR;
};

VS_Output RenderV(VS_Input input) {
    VS_Output output;

    output.position = float4(input.position, 1.0);
    output.color = input.color;

    return output;
}

float4 RenderP(VS_Output input) : SV_TARGET {
    return input.color;
}