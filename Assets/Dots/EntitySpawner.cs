using Unity.Entities;
using Unity.Mathematics;
using Unity.Transforms;
using UnityEngine;
using Unity.Rendering;

public class EntitySpawner : MonoBehaviour
{
    public Mesh mesh;
    public Material material;

    private void Start()
    {
        if (mesh == null || material == null)
        {
            Debug.LogError("Mesh and Material must be assigned.");
            return;
        }

        var world = World.DefaultGameObjectInjectionWorld;
        var entityManager = world.EntityManager;

        var entity = entityManager.CreateEntity();

        // 1. Add transform (required for Entities Graphics)
        entityManager.AddComponentData(entity, new LocalTransform
        {
            Position = float3.zero,
            Rotation = quaternion.identity,
            Scale = 1f
        });

        // 2. Add bounds (required for rendering culling)
        var bounds = mesh.bounds;
        entityManager.AddComponentData(entity, new RenderBounds
        {
            Value = new Unity.Mathematics.AABB
            {
                Center = bounds.center,
                Extents = bounds.extents
            }
        });
        entityManager.AddComponentData(entity, new WorldRenderBounds
        {
            Value = new Unity.Mathematics.AABB
            {
                Center = bounds.center,
                Extents = bounds.extents
            }
        });

        var renderMeshArray = new RenderMeshArray(new Material[] { material }, new Mesh[] { mesh });

        
        RenderMeshUtility.AddComponents(entity, entityManager, new RenderMeshDescription(), renderMeshArray, MaterialMeshInfo.FromRenderMeshArrayIndices(0, 0));


    }
}
