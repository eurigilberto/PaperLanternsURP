using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[ExecuteAlways]
public class UpdateShaderTime : MonoBehaviour
{
    // Update is called once per frame
    void Update()
    {
        Shader.SetGlobalFloat("_sharpTime", Time.time);
    }
}
