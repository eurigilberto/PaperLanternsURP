float startFog;
float FogTransitionDistance;
float fogExpMultiplier;
float3 fogColor;

void ApplyFakeFog_float(float3 positionWS, float3 cameraPos, float3 colorNoFog, out float3 color){
    float distanceFromCamera = length(positionWS - cameraPos);
    float fogInterpolator = 0;
    if(FogTransitionDistance < 0.001){
        fogInterpolator = step(0, distanceFromCamera - startFog);
    }else{
        fogInterpolator = saturate((distanceFromCamera - startFog)/FogTransitionDistance);
    }
    color = lerp(fogColor, colorNoFog, exp(-fogInterpolator*fogExpMultiplier));
}