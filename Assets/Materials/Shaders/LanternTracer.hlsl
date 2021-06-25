#define MAX_DISTANCE 3
#define MAX_ITERATION 50
#define MIN_DISTANCE 0.01

float _sharpTime;
float _timeOffsetInner;
#define pointLightPos float3(0,-0.5 + sin((_sharpTime + _timeOffsetInner)*3) * 0.35,0)

#include "Assets/Materials/Shaders/SDFFunctions.hlsl"
#include "Assets/Materials/Shaders/TileableVoronoi.hlsl"
#include "Assets/Materials/Shaders/Specluar.hlsl"

void Unity_RotateAboutAxis_Radians_float(float3 In, float3 Axis, float Rotation, out float3 Out)
{
    float s = sin(Rotation);
    float c = cos(Rotation);
    float one_minus_c = 1.0 - c;

    Axis = normalize(Axis);
    float3x3 rot_mat = 
    {   one_minus_c * Axis.x * Axis.x + c, one_minus_c * Axis.x * Axis.y - Axis.z * s, one_minus_c * Axis.z * Axis.x + Axis.y * s,
        one_minus_c * Axis.x * Axis.y + Axis.z * s, one_minus_c * Axis.y * Axis.y + c, one_minus_c * Axis.y * Axis.z - Axis.x * s,
        one_minus_c * Axis.z * Axis.x - Axis.y * s, one_minus_c * Axis.y * Axis.z + Axis.x * s, one_minus_c * Axis.z * Axis.z + c
    };
    Out = mul(rot_mat,  In);
}

float Lantern_SDF(float3 p, out int matSelect){
    matSelect = 0;
    float distMainBody = circularCapsule(p, float3(0,-0.5,0), float3(0,0.5,0), 0.2);
    float distMainBodyCut = circularCapsule(p, float3(0,-0.5,0), float3(0,0.5,0), 0.38);

    float mainBodyHull = distMainBody; //opSmoothSubtraction(distMainBodyCut, distMainBody, 0.1); 

    float distCutout = sdCapsule(p, float3(0,-1,0), float3(0,1,0), 0.23);
    float lantern = opSmoothSubtraction(distCutout, mainBodyHull, 0.2);
    //float lantern = opSubtraction(distCutout, mainBodyHull);

    float sphere = Sphere_SDF(p, pointLightPos, 0.09);

    if(sphere < lantern){
        matSelect = 1;
    }

    lantern = opUnion(sphere, lantern);
    return lantern * 0.25;
}

float3 LanternNormal( in float3 pos ){
    float2 e = float2(1.0,-1.0)*0.5773*0.0005;
    int dump;
    return normalize( e.xyy*Lantern_SDF( pos + e.xyy, dump ).x + 
					  e.yyx*Lantern_SDF( pos + e.yyx, dump ).x + 
					  e.yxy*Lantern_SDF( pos + e.yxy, dump ).x + 
					  e.xxx*Lantern_SDF( pos + e.xxx, dump ).x );
}

void Unity_PolarCoordinates(float2 UV, float2 Center, float RadialScale, float LengthScale, out float2 Out)
{
    float2 delta = UV - Center;
    float radius = length(delta) * 2 * RadialScale;
    float angle = atan2(delta.x, delta.y) * 1.0/6.28 * LengthScale;
    Out = float2(radius, angle);
}

float FlowerVoronoi(float2 UV, float2 PolarUV, float timingOffset){
    float flowerCenter = smoothstep(0.05, 0.15, PolarUV.x); 

    float planarVoronoi;
    float planarVoronoiCell;
    float2 movingUV = UV;
    movingUV.x += _sharpTime * 0.3 + timingOffset;
    Tileable_Voronoi_float(movingUV, 2, 5, planarVoronoi, planarVoronoiCell);

    planarVoronoi = planarVoronoi * 0.1 * PolarUV.x; //magic number
    float polarOffsetAngle = abs(frac((PolarUV.y + planarVoronoi + 0.5) * 5) - 0.5) * 2 * flowerCenter; //magic number
    float polarOffsetLenght = PolarUV.x + _sharpTime*0.2 + timingOffset;

    float2 newPolarCoordinates = float2(polarOffsetLenght, polarOffsetAngle);

    float flowerVoronoi;
    float flowerVoronoiCell;
    Tileable_Voronoi_float(newPolarCoordinates, 2, 2, flowerVoronoi, flowerVoronoiCell);

    return flowerVoronoiCell;
}

void LanternTracer_float(float3 startPos, float3 viewDir, float4 lColor, float TimingOffset, float rotationAngle, out float3 color, out float alpha){
    _timeOffsetInner = TimingOffset;
    color = float3(1,0,0);
    alpha = 0;

    float3 startPosRotated;
    Unity_RotateAboutAxis_Radians_float(startPos, float3(0,1,0), rotationAngle, startPosRotated);
    startPos = startPosRotated;

    float3 viewDirRotated;
    Unity_RotateAboutAxis_Radians_float(viewDir, float3(0,1,0), rotationAngle, viewDirRotated);
    viewDir = viewDirRotated;

    float currentDistance = 0;
    [loop]
    for(int i = 0; i < MAX_ITERATION; i++){
        float3 checkPos = startPos + viewDir * currentDistance;
        int matSelect;
        float dist = Lantern_SDF(checkPos, matSelect);

        if(dist < MIN_DISTANCE){
            if(matSelect == 0){
                float3 normal = LanternNormal(checkPos);

                float3 lightDir;
                float3 lightColor;
                GetSceneMainlight(lightDir, lightColor);
                float3 lightDirRotated;
                Unity_RotateAboutAxis_Radians_float(lightDir, float3(0,1,0), rotationAngle, lightDirRotated);
                lightDir = lightDirRotated;

                float lightIntensity = dot(normal, lightDir);
                lightIntensity = saturate(invLerp(-0.3, 1, lightIntensity));
                lightIntensity = lerp(0.005, 1, lightIntensity);

                float3 pointLightDir = normalize(checkPos - pointLightPos);
                float distanceToLight = length(checkPos - pointLightPos);
                float lightFalloff = 1/(distanceToLight*distanceToLight*15);
                float pointLightIntensity =  saturate(invLerp(-2,1, dot(-pointLightDir, normal))) + 0.4;
                pointLightIntensity *= 4;

                float cheapAO = float(i)/MAX_ITERATION;
                cheapAO = exp(-cheapAO);

                float viewLightAngle = dot(viewDir, lightDir);
                float henyenLaw = hg(viewLightAngle, 0.95);
                float henyenMultiplier = exp(-saturate(dot(normal, -viewDir)) * 3);

                float fresnel = exp(-saturate(dot(normal, -viewDir)) * 2) * 0.1 * (lightFalloff + lightIntensity);

                float c = dot(-viewDir, normal);

                float angleAroundY = dot(normalize(checkPos.xz), float2(1,0));
                float2 UV = float2(0,0);
                UV.x = angleAroundY * 0.5 + 0.5;
                UV.y = saturate(checkPos.y + 0.5);

                float2 polarUV;
                Unity_PolarCoordinates(UV, float2(0.5,0.5), 0.6, 0.8, polarUV);
                
                float flowerVoronoi = FlowerVoronoi(UV, polarUV,TimingOffset);

                float3 flowerColor1 = float3(1,1,1) * 6;
                float3 flowerColor2 = float3(1,1,1) * 1.5;

                //float flowerCells = saturate(invLerp(0.5,1, flowerVoronoi));

                float3 flowerColor = lerp(flowerColor1, flowerColor2, step(0.7, flowerVoronoi));
                float3 ringColor = float3(0.1,0.1,0.1);
                float ringMask = step(0.5, abs(checkPos.y));

                float sRing = 0;
                if(ringMask > 0.5){
                    sRing = specular(pointLightDir, normal, viewDir, 3, 2, float3(1,1,1));
                }

                float3 lightColorInfo = (sRing + fresnel + lightFalloff * pointLightIntensity) * lColor + lightColor * (fresnel + lightIntensity * cheapAO + henyenLaw * henyenMultiplier * cheapAO);
                
                if(ringMask > 0.5){
                    color = ringColor * lightColorInfo;
                }else{
                    if(step(0.7, flowerVoronoi) > 0.5){
                        color = flowerColor2 * lightColorInfo;
                    }else {
                        color = saturate((lColor + 0.1) * 1.5) * 1.5;
                    }
                }
                //color = lerp(flowerColor, ringColor, ringMask) * lightColorInfo;
                //color = fresnel;
            }else if(matSelect == 1){
                color = lColor * 5;
            }
            alpha = 1;
            break;
        }
        currentDistance += dist;
        if(currentDistance > MAX_DISTANCE){
            break;
        }
    }
}