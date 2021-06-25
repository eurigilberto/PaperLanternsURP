#define MAX_DISTANCE 5
#define MAX_ITERATION 40
#define MIN_DISTANCE 0.01

#include "Assets/Materials/Shaders/SDFFunctions.hlsl"

//This values are updated from C# using material property blocks
int cloudSpheresCount = 0; 
float4 cloudSpheres[20];
float arraySphereInterp = 0;
float planeCutoff = 0.7;
float unionSmoothFactor = 0.2;
float _sharpTime;
/*This time is updated from a c# script that changes a global shader value, this is done because for some reason
the time that you get from _Time.y adds noise to the normal calculation (I am not surer why that is the case, but this fixes it)*/


float CloudDistortion(float3 p, float mult, float speed){
    //A modified displacement function taken form https://iquilezles.org/www/articles/distfunctions/distfunctions.htm
    return sin(mult*p.x)*sin(mult*p.y + _sharpTime * speed)*sin(mult*p.z);
}

float CloudSphereDistortion(float3 p, float cellSize, float radius, float unionFactor){
    float3 movedPosition = p + float3(0., 0.2 * _sharpTime, 0.);
    float3 scaledPos = movedPosition / cellSize;
    float3 cellIndex = floor(scaledPos);
    float3 cellPosition = frac(scaledPos);
    float3 cellCenter = frac(cellIndex * 120.12312);

    float displacement = 0;
    bool first = true;

    float3 centerOffset = float3(0.5,0.5,0.5);

    for(int i = -1; i < 2; i++){
        for(int j = -1; j < 2; j++){
            for(int k = -1; k < 2; k++){
                float3 center = float3(i, j, k) + centerOffset;
                float distance = length(cellPosition - center) - radius;
                if(first){
                    displacement = distance;
                    first = false;
                }else{
                    displacement = opSmoothUnion(displacement, distance, unionFactor);
                }
            }
        }
    }
    return displacement;
}

float Cloud_SDF(float3 p){
    float displacement = CloudDistortion(p, 2, 4) + CloudDistortion(p, 1, 1);
    /*This distortion is added to hide the fact that the clouds are just made from spheres and to give the cloud a more interesting shape.
    The first is a fast moving "small detail" distorion and the second one a small moving "large detail" distorion*/

    float displacement2 = 1;//CloudSphereDistortion(p, 2, 0.2, 0.2);

    //The following section uses the sphere position and size passde to the material to generate the main shape
    //The xyz of the float4 is the position and the w is the radius
    float completeSphere;
    float newSphere; 
    for(int i = 0; i < cloudSpheresCount; i++){
        newSphere = Sphere_SDF(p, float3(cloudSpheres[i].xyz), float(cloudSpheres[i].w));
        if(i == 0){
            completeSphere = newSphere;
        }else{
            completeSphere = opSmoothUnion(newSphere, completeSphere, unionSmoothFactor);//0.2 is a magic numer
        }
    }

    float planeDist = Plane_SDF(p, float3(0,-1,0), -0.3);
    float displacedSphere = completeSphere + displacement * 0.07;
    float displacedWithArray = displacement2;//displacedSphere + displacement2 * smoothstep(1, -2, displacedSphere);

    return opSmoothIntersection(planeDist, lerp(displacedSphere,displacedWithArray,arraySphereInterp), planeCutoff) * 1;//0.07 and 0.7 are magic numbers, play with them to get different shapes
}

float3 CloudNormal( in float3 pos ){
    //This is a function taken form https://iquilezles.org/www/articles/normalsSDF/normalsSDF.htm
    float2 e = float2(1.0,-1.0)*0.5773*0.0005;
    return normalize( e.xyy*Cloud_SDF( pos + e.xyy ).x + 
					  e.yyx*Cloud_SDF( pos + e.yyx ).x + 
					  e.yxy*Cloud_SDF( pos + e.yxy ).x + 
					  e.xxx*Cloud_SDF( pos + e.xxx ).x );
}

void CloudTracer_float(float3 startPos, float3 viewDir, float maxTravleDistance, float scateringConstant, float hgMultiplier, out float3 color, out float alpha, out float traveledDistance, out float3 normalOut){
    color = float3(1,0,0);
    alpha = 0;
    traveledDistance = 0;
    normalOut = float3(0,1,0);

    float currentDistance = 0;
    [loop]
    for(int i = 0; i < MAX_ITERATION; i++){
        float3 checkPos = startPos + viewDir * currentDistance;
        float dist = Cloud_SDF(checkPos);

        if(currentDistance > maxTravleDistance){
            /*This is occlusion base on the scene depth. This distance is calculated by transforming the scene depth to world position,
            then that position is transformed to SDF local space, subtracted with the ray start position*/
            alpha = 0;
            break;
        }
        if(dist < MIN_DISTANCE){
            float3 normal = CloudNormal(checkPos);
            normalOut = normal;
            
            float3 lightDir;
            float3 lightColor;
            GetSceneMainlight(lightDir, lightColor);//A wrapper for the get main light function from unity

            float lightIntensity = dot(normal, lightDir);
            lightIntensity = saturate(invLerp(-0.3, 1, lightIntensity)); //The inverse lerp is there to make it look like the light is wrapping around the cloud
            lightIntensity = lerp(0.05, 1, lightIntensity); 
            /*This is to make sure there is always bit of difuse light which is then added to the ambient light which helps
            to maintein the cloudy shape on the dark side*/
            

            float viewLightAngle = dot(viewDir, lightDir);
            float henyenLaw = hg(viewLightAngle, scateringConstant); //0.96 is basically a magic number, I get good results from 0.9 to 0.99
            /*float hg(float angle, float _ScatteringConstant) {
                float g2 = _ScatteringConstant*_ScatteringConstant;
                return (1-g2) / (4*3.1415*pow(1+g2-2*_ScatteringConstant*(angle), 1.5));
            }This function was taken from a tutorial by Sebastian Lague https://www.youtube.com/watch?v=4QOcCGI6xOU&t=30s*/

            float cheapAO = exp(- float(i)/MAX_ITERATION); 
            /*If there are a lot if things around the point you are trying to reach it is going to increase the amount of steps
            that have to be taken to get there, becasue the maximun distance traveled is the minium distance to the scene so, 
            as you get closer and there are more things around the system takes smaller and smaller steps*/

            //pow(float(i)/MAX_ITERATION, 3) + henyenMultiplier 
            float henyenMultiplier = invLerp(0.1, 1, exp(-saturate(dot(normal, -viewDir)) * 2));
            /* Technically the multiplier would depend on the amount of stuff the moon light would have
            to pass through to get to the other side, but I decided not do that here and insted used what you see there, which is basically fresnel*/

            float henyenMask = exp(-saturate(dot(normal, -viewDir)) * 4);// exp(-saturate() * 5) * 20;
            float fresnel = exp(-saturate(dot(normal, -viewDir)) * 5) * 20 * lightIntensity;//Multiplied by the light to reduce it where there is little to no light

            float completeLight = max(0, henyenLaw * henyenMultiplier) * hgMultiplier + cheapAO * lightIntensity + fresnel;//the ambient light is added later
            color = max(0, henyenLaw * henyenMultiplier) * hgMultiplier;// lightColor * completeLight;
            alpha = 1;
            traveledDistance = currentDistance; //This is used by the custom fog function I made
            break;
        }
        currentDistance += dist;
        if(currentDistance > MAX_DISTANCE){ //Stop if the ray has already traveled enogth distance
            break;
        }
    }
}