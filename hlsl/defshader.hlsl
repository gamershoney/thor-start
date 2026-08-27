cbuffer Frame_Data : register(b0)
{
    float2 viewport_size;
    float2 padding;
};

struct VS_Input {
    float3 position : POSITION;
    float4 color    : COLOR;
};

struct VS_Output {
    float4 position : SV_POSITION;
    float4 color    : COLOR;
};

VS_Output RenderV(VS_Input input)
{
    VS_Output output;

    float2 ndc;

    ndc.x = (input.position.x / viewport_size.x) * 2.0 - 1.0;
    ndc.y = 1.0 - (input.position.y / viewport_size.y) * 2.0;

    output.position = float4(ndc, input.position.z, 1.0);
    output.color = input.color;

    return output;
}

float4 RenderP(VS_Output input) : SV_TARGET {
    return input.color;
}