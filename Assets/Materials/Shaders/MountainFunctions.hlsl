#include "Assets/Materials/Shaders/SDFFunctions.hlsl"
#include "Assets/Materials/Shaders/TileableVoronoi.hlsl"

void MountainColor_float(float3 position, float3 normal, float3 viewDir, float3 grassColor, float3 rockColor, float3 ambientColor, out float3 color){
    float3 lightDir;
    float3 lightColor;
    GetSceneMainlight(lightDir, lightColor);

    float nDotL = dot(lightDir, normal);
    float fresnel = saturate(exp(-dot(-viewDir, normal) * 8)) * saturate(nDotL) * 10;

    float grassNoise;
    float grassNoiseCell;
    Tileable_Voronoi_float(float2(position.x,position.z) * 0.05, 2, 10, grassNoise, grassNoiseCell);
    grassNoise *= 0.1;

    float grassMask = smoothstep(0.7,0.72, dot(float3(0,1,0), normal) - grassNoise);
    //float grassMask = smoothstep(0.7,0.72, dot(float3(0,1,0), normal));

    float voronoi;
    float voronoicell;
    Tileable_Voronoi_float(float2(position.z,position.y)*0.1, 2, 20, voronoi, voronoicell);

    float3 mountianColor = lerp(rockColor * voronoicell, grassColor, grassMask);
    float diffuseLight = saturate(invLerp(0,1, nDotL)) * 12;
    color = mountianColor * (diffuseLight * lightColor + ambientColor) + fresnel * lightColor;
}