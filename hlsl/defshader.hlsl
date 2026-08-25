struct VS_Input {
    float3 position : POSITION;
    float4 color : COLOR;
};

struct VS_Output {
    float4 position: POSITION;
    float4 color : COLOR;
};

VS_Output RenderV(
    VS_Input input
){
    VS_Output Output;
    Output.position = float4(input.position, 1.0);
    Output.color = input.color;
    
    return Output;
};

float4 RenderP(VS_Output input) :SV_Target {
    return input.color;
}