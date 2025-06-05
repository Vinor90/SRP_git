using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

[CreateAssetMenu(menuName = "Rendering/Custom Render Pipeline")] // создаем пункт в меню, чтобы появилась вкладка ассет-создать-рендеринг

public class MyPipelineAsset : RenderPipelineAsset // наследуемся от класса, чтобы создать свой конвейер ассет
{
    public bool useDynamicBatching; //динамическое пакетирование и создание экземпляров
    public bool useGPUinstancing;
    public bool useSRPBatcher;
    

    protected override RenderPipeline CreatePipeline()                                      // protected доступ -доступ получает класс, определивший метод или классы, к-ые его расширяют
    {
        return new MyRenderPipeline(useDynamicBatching, useGPUinstancing, useSRPBatcher);
    }
}
