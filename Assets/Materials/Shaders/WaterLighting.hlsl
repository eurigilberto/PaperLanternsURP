#include "Assets/Materials/Shaders/Specluar.hlsl"
#include "Assets/Materials/Shaders/SDFFunctions.hlsl"

void WaterShading_float(float3 normal, float3 reflectionColor, float3 waterColor, float reflectivity, float3 positionWS, float3 cameraPos, float waterHeight, out float3 newColor){
    float3 lightDir;
    float3 lightColor;
    GetSceneMainlight(lightDir, lightColor);

    float3 normalViewDir = normalize(positionWS - cameraPos);
    float3 specualViewDir = normalize((positionWS + waterHeight * float3(0,1,0) * 10) - cameraPos);

    float s = specular(lightDir, normal, -normalViewDir, 30, 1.5, float3(1,20,1));
    float sR = specular(lightDir, normal, -normalViewDir, 1, 1, float3(1,1,1));
    
    float hlSpecular = specular(lightDir, normal, -specualViewDir, 90, 10, float3(1,20,1));
    float hightlightNormal = normalize(normal * float3(1,10000,1));
    //float highLights = dot(viewDir, hightlightNormal);
    //float highLights = dot(lightDir, -viewDir);
    //highLights = saturate(invLerp(0.9,1,highLights));//saturate(invLerp(0.16,0.2,highLights)) * hlSpecular;
    //highLights = saturate(smoothstep(2,2.1,highLights));

    float nDotL = dot(normal, lightDir);
    newColor = reflectivity * reflectionColor * sR + ((1 - reflectivity) * nDotL * waterColor + s * 0.1) * lightColor + hlSpecular * lightColor;
}