using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class RandomSpheres : MonoBehaviour
{
    // В ОБЩЕМ СЛУЧАЕ НАМ НУЖНО:
    // 1) Создать и заполнить массивы данных (можно в структуре)
    // 2) Создать ComputeBuffer
    // 3) Скопировать массивы данных в буффер
    // 4) Отправить данные буфера в ядро
    // 5) Использовать GPU buffer, чтобы задать движение объектов


    [SerializeField]
    private int objectsCount = 20;
    [SerializeField, Range(1, 30)]
    private float spread = 20;
    [SerializeField, Range(0.1f, 2f)]
    private float speed = 0.5f;
    [SerializeField]
    private ComputeShader shader;
    [SerializeField]
    private GameObject prefab;

    // создаем переменные, которые будем использовать для хранения данных на GPU, получая эти данные на CPU
    private Vector3[] resultPositions;              // intances store in CPU data
    private Transform[] objects;                    // создаем массивы значений векторов и объектов (префабов)

    private ComputeBuffer _Buffer;                   // GPU data
    private int kernelIndex;
    private uint threadGroupSize;


    private void Start()
    {
        kernelIndex = shader.FindKernel("CSMain");                                                  // обращаемся к шэйдеру
        shader.GetKernelThreadGroupSizes(kernelIndex, out threadGroupSize, out _, out _);       //compute shader метод GetKernelThreadGroupSizes  возвращает значение указанное в numthreads и
                                                                                                //далее умножает на кол-во объектов, к-ые нужно отрендерить (ядра * objectcount)
        objectsCount *= (int)threadGroupSize;
        _Buffer = new ComputeBuffer(objectsCount, sizeof(float) * 3);                            // создаем GPU буффер, используя массив данных на CPU
                                                                                                 // sizeof оператор возвращает 4 байта памяти
        resultPositions = new Vector3[objectsCount];
        objects = new Transform[objectsCount];

        for (var i = 0; i < objectsCount; i++)
        {
            objects[i] = Instantiate(prefab, transform).transform;                              // ф-ия создает дубликаты Prefab в runtime
            objects[i].gameObject.SetActive(true);
        }

    }

    /* private void DispatchShader(int x, int y)
    {
        shader.Dispatch(kernelIndex, x, y, 1);      // вызов кол-ва ядер
    };*/


    private void Update()
    {
        shader.SetFloat("Time", Time.time * speed);
        shader.SetFloat("Spread", spread);
        shader.SetBuffer(kernelIndex: kernelIndex, "Positions", _Buffer);            // pass data on GPU

        var threadGroups = (int)(objectsCount / threadGroupSize);
        shader.Dispatch(kernelIndex, threadGroups, 1, 1);

        _Buffer.GetData(resultPositions);

        for (var i = 0; i < objects.Length; i++)
            objects[i].localPosition = resultPositions[i];

    }

    private void OnDestroy()
    {
        _Buffer.Dispose();                                                   // очищаем буффер

    }

}