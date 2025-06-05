using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using Unity.Entities;

public class SpawnerAuthoring : MonoBehaviour
{

    public GameObject prefab;
    public float spawnRate;

}

class SpawnerBaker : Baker<SpawnerAuthoring>
{
    public override void Bake(SpawnerAuthoring authoring)
    {
        Entity entity = GetEntity(TransformUsageFlags.None);

        AddComponent(entity, new SpawnerComponent
        {

            prefab = GetEntity(authoring.prefab, TransformUsageFlags.Dynamic),
            spawnPos = authoring.transform.position,
            nextSpawnTime = 0.0f,
            spawnRate = authoring.spawnRate,
        });
    }
}