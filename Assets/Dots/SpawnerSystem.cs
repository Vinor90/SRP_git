using Unity.Burst;
using Unity.Entities;
using Unity.Transforms;
using Unity.Mathematics;
using Unity.Collections;

[BurstCompile]
public partial struct SpawnerSystem : ISystem
{
    [BurstCompile]
    public void OnUpdate(ref SystemState state)
    {
        if (!SystemAPI.TryGetSingleton<SpawnerComponent>(out var spawner))
            return;

        EntityCommandBuffer ecb = new EntityCommandBuffer(Allocator.Temp);

        if (spawner.nextSpawnTime < SystemAPI.Time.ElapsedTime)
        {
            Entity newEntity = ecb.Instantiate(spawner.prefab);

            ecb.SetComponent(newEntity, new LocalTransform
            {
                Position = spawner.spawnPos,
                Rotation = quaternion.identity,
                Scale = 1f
            });

            spawner.nextSpawnTime = (float)SystemAPI.Time.ElapsedTime + spawner.spawnRate;
            SystemAPI.SetSingleton(spawner);
        }

        ecb.Playback(state.EntityManager);
        ecb.Dispose();
    }
}
/*public partial struct SpawnerSystem : ISystem
{

    public void OnUpdate(ref SystemState state)
    {
        if (!SystemAPI.TryGetSingletonEntity<SpawnerComponent>(out Entity spawnerEntity))
        {
            return;
        }

        RefRW<SpawnerComponent> spawner = SystemAPI.GetComponentRW<SpawnerComponent>(spawnerEntity);

        EntityCommandBuffer entcomBuffer = new EntityCommandBuffer(Allocator.Temp);

        if (spawner.ValueRO.nextSpawnTime < SystemAPI.Time.ElapsedTime)
        {
            Entity newEntity = entcomBuffer.Instantiate(spawner.ValueRO.prefab);

            spawner.ValueRW.nextSpawnTime = (float)SystemAPI.Time.ElapsedTime + spawner.ValueRO.spawnRate;
            entcomBuffer.Playback(state.EntityManager);
        }

    }

}*/