using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[CreateAssetMenu(menuName ="ShaderControls/FakeFogControls", fileName ="FogControls")]
public class FakeFogControls : ScriptableObject
{
    public float fogStart = 0;
    public float fogInterpolationDistance = 20;
    public Color fogColor = Color.black;
    public float fogExpMultiplier = 2;

    public void OnValidate(){
        Shader.SetGlobalColor("fogColor", fogColor);
        Shader.SetGlobalFloat("startFog", fogStart);
        Shader.SetGlobalFloat("FogTransitionDistance", fogInterpolationDistance);
        Shader.SetGlobalFloat("fogExpMultiplier", fogExpMultiplier);
    }
}
