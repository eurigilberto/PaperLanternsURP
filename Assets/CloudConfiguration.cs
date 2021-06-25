using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[ExecuteAlways]
public class CloudConfiguration : MonoBehaviour
{
    private MeshRenderer _renderer;
    public Vector3 offsetPosition;
    public Vector3 scale;
    public Vector4[] cloudSpheres;

    [Range(0,1)]
    public float sphereInterp = 0;
    [Range(0,5)]
    public float planeCutoff = 0.7f;
    [Range(0,5)]
    public float unionSmoothFactor = 0.2f;

    public void OnEnable()
    {
        _renderer = gameObject.GetComponent<MeshRenderer>();
        UpdateMaterial();
    }

    const int maxShaderArraySize = 20;

    public void UpdateMaterial()
    {
        if (!(_renderer is null))
        {
            MaterialPropertyBlock mpb = new MaterialPropertyBlock();
            int maxRead = cloudSpheres.Length < maxShaderArraySize ? cloudSpheres.Length : maxShaderArraySize;

            Vector4[] copyArray = new Vector4[maxRead];
            for (int i = 0; i < maxRead; i++)
            {
                copyArray[i] = cloudSpheres[i];
            }

            mpb.SetFloat("cloudSpheresCount", copyArray.Length);
            mpb.SetVectorArray("cloudSpheres", copyArray);
            mpb.SetVector("_offset", offsetPosition);
            mpb.SetVector("_scale", scale);
            mpb.SetFloat("arraySphereInterp", sphereInterp);
            mpb.SetFloat("planeCutoff", planeCutoff);
            mpb.SetFloat("unionSmoothFactor", unionSmoothFactor);

            _renderer.SetPropertyBlock(mpb);
        }
    }

    public void OnValidate()
    {
        UpdateMaterial();
    }
}
