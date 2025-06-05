// Maksim_Vinogradov
// 05_2025_Render_Programmer_Test

using System;
using System.Collections;
using System.Collections.Generic;
using Unity.Collections.LowLevel.Unsafe;
using Unity.Collections;
using Unity.Jobs;
using UnityEditor;
using UnityEngine;
using UnityEngine.Rendering;
using Unity.Mathematics;
using Unity.Entities;
using Unity.Rendering;
using Unity.Transforms;
using Unity.Entities.Graphics;
using System.Linq;
using UnityEngine.Experimental.Rendering;
using NUnit.Framework;

public class MyRenderPipeline : RenderPipeline //наследование класса
{

    bool useDynamicBatching, useGPUInstancing; // локальные переменные

    CameraRenderer renderer = new CameraRenderer();

    public MyRenderPipeline(bool useDynamicBatching, bool useGPUInstancing, bool useSRPBatcher) // (список параметров MyPipelineAsset)
    {
        this.useDynamicBatching = useDynamicBatching;
        this.useGPUInstancing = useGPUInstancing;
        GraphicsSettings.useScriptableRenderPipelineBatching = useSRPBatcher;
        GraphicsSettings.lightsUseLinearIntensity = true; // вкл линейные преобразования по умолчанию


    }

    protected override void Render(ScriptableRenderContext context, Camera[] cameras  // используем данные для рендеринга сцены
    )
    { }

    protected override void Render(ScriptableRenderContext context, List<Camera> cameras)
    {

        foreach (var camera in cameras)
        {
            // Передаем систему в рендерер камеры
            renderer.Render(context, camera, useDynamicBatching, useGPUInstancing);
        }
    }

    public class Lighting
    {
        static int
            dirLightColorId = Shader.PropertyToID("_DirectionalLightColor"),
            dirLightDirectionId = Shader.PropertyToID("_DirectionalLightDirection");

        CommandBuffer lightBuffer = new CommandBuffer
        {
            name = "Light Buffer"
        };

        public void Setup(ScriptableRenderContext context)
        {
            lightBuffer.BeginSample("Light Buffer");
            SetupDirectionalLight();
            lightBuffer.EndSample("Light Buffer");
            context.ExecuteCommandBuffer(lightBuffer);
            lightBuffer.Clear();
        }

        void SetupDirectionalLight()
        {
            Light light = RenderSettings.sun;
            // Проверка на наличие источника света
            if (light == null || !light.isActiveAndEnabled)
            {
                lightBuffer.SetGlobalVector(dirLightColorId, Vector4.zero);
                lightBuffer.SetGlobalVector(dirLightDirectionId, Vector4.zero);
                return;
            }

            lightBuffer.SetGlobalVector(dirLightColorId, light.color.linear * light.intensity);
            lightBuffer.SetGlobalVector(dirLightDirectionId, -light.transform.forward);


        }


    }
    public class CameraRenderer // класс, предназначенный для рендеринга одной камеры
                                // для проверки открываем frame debugger и смотрим, что наделали


    {   // Параметры освещения
        const int maxVisibleLights = 2;                         // кол-во ист освещения соответствует кол-ву в шэйдере 
        static int visibleLightColorsId =                    // создаем переменные и указываем явные названия как в коде  Shader
            Shader.PropertyToID("_VisibleLightColors");     // принимает строку и возвращает число
        static int visibleLightDirectionsOrPositionsId =
            Shader.PropertyToID("_VisibleLightDirectionsOrPositions");
        Vector4[] visibleLightColors = new Vector4[maxVisibleLights];
        Vector4[] visibleLightDirectionsOrPositions = new Vector4[maxVisibleLights];

        //Параметры теней
        RenderTexture shadowMap;                                        // Render target для карты теней
        static int shadowMapId = Shader.PropertyToID("_ShadowMap");     // создаем переменные и указываем явные названия как в коде Shader
        static int worldToShadowMatrixId =
        Shader.PropertyToID("_WorldToShadowMatrix");
        static int shadowBiasId = Shader.PropertyToID("_ShadowBias");

        static ShaderTagId unlitshaderTagId = new ShaderTagId("SRPDefaultUnlit");  // Тэги для отображения шэйдеров 
        static ShaderTagId litShaderTagId = new ShaderTagId("CustomLit");

        static ShaderTagId[] legacyShaderTagIds = {                           // Массив тэгов неиспользуемых старыми шейдерами
        new ShaderTagId("Always"),
        new ShaderTagId("ForwardBase"),
        new ShaderTagId("PrepassBase"),
        new ShaderTagId("Vertex"),
        new ShaderTagId("VertexLMRGBM"),
        new ShaderTagId("VertexLM")
    };                          // Отличные шэйдеры от нашего пайплайна   
        static Material errorMaterial;                                          // кэшируем материал для null объектов
                                                                                // Добавляем шейдерные теги для DOTS Instancing
        static List<ShaderTagId> dotsInstancingShaderTags = new List<ShaderTagId> {
        new ShaderTagId("SRPDefaultUnlit"),
        new ShaderTagId("CustomLit")
    };
        // Создаем командные буферы
        // один для base pass, другой для  shadow pass
        CommandBuffer colorBuffer = new CommandBuffer
        {
            name = "Color Buffer"
        };
        CommandBuffer shadowBuffer = new CommandBuffer
        {
            name = "Render Shadows"
        };
        ScriptableRenderContext context;
        Camera camera;


#if UNITY_EDITOR      // Отрисовка гизмо в редакторе

        void DrawGizmos()
        {
            if (Handles.ShouldRenderGizmos())
            {
                context.DrawGizmos(camera, GizmoSubset.PreImageEffects);
                context.DrawGizmos(camera, GizmoSubset.PostImageEffects);
            }
        }

#endif

        Lighting lighting = new Lighting();

        void RenderShadows(ScriptableRenderContext context, ref CullingResults cullingResults)
        {
            if (cullingResults.visibleLights.Length == 0) return;

            for (int i = 0; i < cullingResults.visibleLights.Length; i++)
            {
                VisibleLight visibleLight = cullingResults.visibleLights[i];

                if (visibleLight.light == null ||
                    !visibleLight.light.isActiveAndEnabled ||
                    visibleLight.light.shadows == LightShadows.None ||
                    visibleLight.lightType != LightType.Directional || // Только Directional
                    !cullingResults.GetShadowCasterBounds(i, out _))
                {
                    continue;
                }

                try
                {
                    ShadowDrawingSettings shadowSettings = new ShadowDrawingSettings(
                        cullingResults,
                        i,
                        BatchCullingProjectionType.Orthographic
                    );

                    cullingResults.ComputeDirectionalShadowMatricesAndCullingPrimitives(
                        i,
                        0,
                        1,
                        Vector3.zero,
                        1024,
                        visibleLight.light.shadowNearPlane,
                        out Matrix4x4 viewMatrix,
                        out Matrix4x4 projectionMatrix,
                        out ShadowSplitData splitData

                    );

                    shadowMap = RenderTexture.GetTemporary(1024, 1024, 16, RenderTextureFormat.Shadowmap); // разрешение и битность текстуры, формат текстуры
                    shadowMap.filterMode = FilterMode.Bilinear;
                    shadowMap.wrapMode = TextureWrapMode.Clamp;

                    CoreUtils.SetRenderTarget(shadowBuffer, shadowMap, RenderBufferLoadAction.DontCare,  // команды для GPU
                                              RenderBufferStoreAction.Store, ClearFlag.Depth);
                    shadowBuffer.BeginSample("Render Shadows");                                         // начало отрисовки, выполнение, очистка
                    context.ExecuteCommandBuffer(shadowBuffer);
                    shadowBuffer.Clear();

                    // Matrix4x4 viewMatrix, projectionMatrix;
                    //ShadowSplitData splitData;                                                      // Cascades Shadow Map разделение
                    cullingResults.ComputeDirectionalShadowMatricesAndCullingPrimitives(            // номер ист света, CSM параметры, размер карты теней,clipping plane
                        0, 0, 1, Vector3.zero, 1024,
                        cullingResults.visibleLights[0].light.shadowNearPlane,
                        out viewMatrix, out projectionMatrix, out splitData);
                    shadowBuffer.SetViewProjectionMatrices(viewMatrix, projectionMatrix);           // матрицы виды и проекции
                    shadowBuffer.SetGlobalFloat(
                        shadowBiasId, cullingResults.visibleLights[0].light.shadowBias);
                    context.ExecuteCommandBuffer(shadowBuffer);
                    shadowBuffer.Clear();

                    // var shadowSettings = new ShadowDrawingSettings(cullingResults, 0);
                    context.DrawShadows(ref shadowSettings);

                    if (SystemInfo.usesReversedZBuffer)                                         // Особенности разных API для Z buffer (направление или от нас или к нам)
                    {
                        projectionMatrix.m20 = -projectionMatrix.m20;
                        projectionMatrix.m21 = -projectionMatrix.m21;
                        projectionMatrix.m22 = -projectionMatrix.m22;
                        projectionMatrix.m23 = -projectionMatrix.m23;
                    }
                    var scaleOffset = Matrix4x4.TRS(Vector3.one * 0.5f, Quaternion.identity, Vector3.one * 0.5f);  // Нам нужно от Clip Space перейти в Texture Space
                                                                                                                   // т.е. от диапазона [-1,1] к [0,1]
                    Matrix4x4 worldToShadowMatrix = scaleOffset * (projectionMatrix * viewMatrix);
                    shadowBuffer.SetGlobalMatrix(worldToShadowMatrixId, worldToShadowMatrix);
                    shadowBuffer.SetGlobalTexture(shadowMapId, shadowMap);                              // указываем шэйдеру, что он должен использовать для _ShadowMap
                    shadowBuffer.EndSample("Render Shadows");
                    context.ExecuteCommandBuffer(shadowBuffer);
                    shadowBuffer.Clear();


                    shadowSettings.splitData = splitData;
                    // shadowSettings.SetShadowMatrices(viewMatrix, projMatrix);

                    context.DrawShadows(ref shadowSettings);
                }
                catch (System.Exception e)
                {
                    Debug.LogError($"Shadow rendering error for light {i}: {e.Message}");
                }
            }
        }

        public void Render(ScriptableRenderContext context, Camera camera, bool dynamicBatching, bool GPUInstancing)    // рендер для камеры
        {
            this.context = context;
            this.camera = camera;
            // только для редактора
            #if UNITY_EDITOR
                        if (camera.cameraType == CameraType.SceneView)
                        {
                            ScriptableRenderContext.EmitWorldGeometryForSceneView(camera);
                        }
            #endif


            ScriptableCullingParameters cullingParameters;
            if (!camera.TryGetCullingParameters(out cullingParameters))
            {
                return;
            }
            cullingParameters.shadowDistance = 50; // подбираем значение по отладчику

            var cullingResults = context.Cull(ref cullingParameters); // вызываем результаты отбраковки (ref -передача по ссылке)
                                                                      // Вызываем рендер теней

            RenderShadows(context, ref cullingResults);

            ConfigureLighting(ref cullingResults);
            Setup();
            lighting.Setup(context);
            DrawVisibleGeometry();
             DrawDOTSInstancingGeometry(GPUInstancing);
            DrawUnsupportedShaders();
            Submit();
           
            if (shadowMap != null)
            {
                RenderTexture.ReleaseTemporary(shadowMap);
                shadowMap = null;
            }

            /*  void RenderShadows(ScriptableRenderContext context)
              {
                  if (cullingResults.visibleLights.Length == 0) return;

                  shadowMap = RenderTexture.GetTemporary(1024, 1024, 16, RenderTextureFormat.Shadowmap); // разрешение и битность текстуры, формат текстуры
                  shadowMap.filterMode = FilterMode.Bilinear;
                  shadowMap.wrapMode = TextureWrapMode.Clamp;

                  CoreUtils.SetRenderTarget(shadowBuffer, shadowMap, RenderBufferLoadAction.DontCare,  // команды для GPU
                                            RenderBufferStoreAction.Store, ClearFlag.Depth);
                  shadowBuffer.BeginSample("Render Shadows");                                         // начало отрисовки, выполнение, очистка
                  context.ExecuteCommandBuffer(shadowBuffer);
                  shadowBuffer.Clear();

                  Matrix4x4 viewMatrix, projectionMatrix;
                  ShadowSplitData splitData;                                                      // Cascades Shadow Map разделение
                  cullingResults.ComputeDirectionalShadowMatricesAndCullingPrimitives(            // номер ист света, CSM параметры, размер карты теней,clipping plane
                      0, 0, 1, Vector3.zero, 1024,
                      cullingResults.visibleLights[0].light.shadowNearPlane,
                      out viewMatrix, out projectionMatrix, out splitData);
                  shadowBuffer.SetViewProjectionMatrices(viewMatrix, projectionMatrix);           // матрицы виды и проекции
                  shadowBuffer.SetGlobalFloat(
                      shadowBiasId, cullingResults.visibleLights[0].light.shadowBias);
                  context.ExecuteCommandBuffer(shadowBuffer);
                  shadowBuffer.Clear();

                  var shadowSettings = new ShadowDrawingSettings(cullingResults, 0);
                  context.DrawShadows(ref shadowSettings);

                  if (SystemInfo.usesReversedZBuffer)                                         // Особенности разных API для Z buffer (направление или от нас или к нам)
                  {
                      projectionMatrix.m20 = -projectionMatrix.m20;
                      projectionMatrix.m21 = -projectionMatrix.m21;
                      projectionMatrix.m22 = -projectionMatrix.m22;
                      projectionMatrix.m23 = -projectionMatrix.m23;
                  }
                  var scaleOffset = Matrix4x4.TRS(Vector3.one * 0.5f, Quaternion.identity, Vector3.one * 0.5f);  // Нам нужно от Clip Space перейти в Texture Space
                                                                                                                 // т.е. от диапазона [-1,1] к [0,1]
                  Matrix4x4 worldToShadowMatrix = scaleOffset * (projectionMatrix * viewMatrix);
                  shadowBuffer.SetGlobalMatrix(worldToShadowMatrixId, worldToShadowMatrix);
                  shadowBuffer.SetGlobalTexture(shadowMapId, shadowMap);                              // указываем шэйдеру, что он должен использовать для _ShadowMap
                  shadowBuffer.EndSample("Render Shadows");
                  context.ExecuteCommandBuffer(shadowBuffer);
                  shadowBuffer.Clear();
              }
            */

            void Setup()
            {
                context.SetupCameraProperties(camera);                                      // определяет матрицу VP и др св-ва камеры
                camera.cullingMask = -1;
                colorBuffer.ClearRenderTarget(true, false, Color.clear);                    // очищаем render target (z depth,color,цвет очистки)
                colorBuffer.SetGlobalVectorArray(visibleLightColorsId, visibleLightColors); // устанавливаем переменные из нашего shadera
                colorBuffer.SetGlobalVectorArray(visibleLightDirectionsOrPositionsId,
                                                   visibleLightDirectionsOrPositions);
                colorBuffer.BeginSample("Color Buffer");
                ExecuteBuffer();

            }
            void ConfigureLighting(ref CullingResults cullingResults)
            {
                int realMaxLights = Mathf.Min(cullingResults.visibleLights.Length, maxVisibleLights);
                for (int i = 0; i < realMaxLights; i++)
                {
                    VisibleLight light = cullingResults.visibleLights[i];
                    visibleLightColors[i] = light.finalColor;

                    if (light.lightType == LightType.Directional)
                    {
                        Vector4 v = light.localToWorldMatrix.GetColumn(2);
                        visibleLightDirectionsOrPositions[i] = new Vector4(-v.x, -v.y, -v.z, 0);
                    }
                    else
                    {
                        visibleLightDirectionsOrPositions[i] = light.localToWorldMatrix.GetColumn(3);
                        visibleLightDirectionsOrPositions[i].w = 1; // Для точечных источников
                    }
                }

                colorBuffer.SetGlobalVectorArray(visibleLightColorsId, visibleLightColors);
                colorBuffer.SetGlobalVectorArray(visibleLightDirectionsOrPositionsId, visibleLightDirectionsOrPositions);
            }
            void Submit()
            {
                colorBuffer.EndSample("Color Buffer");
                ExecuteBuffer();
                context.Submit();
            }
            void ExecuteBuffer()
            {
                context.ExecuteCommandBuffer(colorBuffer); // вызывает буффер и копирует команды из него
                colorBuffer.Clear();
            }
            // Новый метод для рендеринга DOTS-объектов


            void DrawDOTSInstancingGeometry(bool GPUInstancing)
            {
                if (!GPUInstancing) return;

                var sortingSettings = new SortingSettings(camera)
                {
                    criteria = SortingCriteria.CommonOpaque
                };

                var drawingSettings = new DrawingSettings(dotsInstancingShaderTags[0], sortingSettings)
                {
                    enableDynamicBatching = false,
                    enableInstancing = true,
                    perObjectData = PerObjectData.Lightmaps |
                                   PerObjectData.LightProbe |
                                   PerObjectData.LightProbeProxyVolume |
                                   PerObjectData.ReflectionProbes
                };

                for (int i = 1; i < dotsInstancingShaderTags.Count; i++)
                {
                    drawingSettings.SetShaderPassName(i, dotsInstancingShaderTags[i]);
                }

                var filteringSettings = new FilteringSettings(RenderQueueRange.all);
                context.DrawRenderers(cullingResults, ref drawingSettings, ref filteringSettings);
            }

            void DrawVisibleGeometry() // отрисовка геометрии
            {

                var sortingSettings = new SortingSettings(camera)
                { criteria = SortingCriteria.CommonOpaque };
                var drawingSettings = new DrawingSettings(unlitshaderTagId, sortingSettings)
                {
                    enableDynamicBatching = dynamicBatching,
                    enableInstancing = GPUInstancing
                };
                drawingSettings.SetShaderPassName(1, litShaderTagId);

                var filteringSettings = new FilteringSettings(RenderQueueRange.opaque); // отрисовка непрозрачных объектов

                context.DrawRenderers(
                    cullingResults, ref drawingSettings, ref filteringSettings
                );

                context.DrawSkybox(camera); // отображение скайбокса

                sortingSettings.criteria = SortingCriteria.CommonTransparent; // отрисовка прозрачных объектов
                drawingSettings.sortingSettings = sortingSettings;
                filteringSettings.renderQueueRange = RenderQueueRange.transparent;

                context.DrawRenderers(
                    cullingResults, ref drawingSettings, ref filteringSettings
                );
            }
            void DrawUnsupportedShaders()
            {
                if (errorMaterial == null)
                {
                    errorMaterial =
                        new Material(Shader.Find("Hidden/InternalErrorShader"));
                }

                var drawingSettings = new DrawingSettings(
                legacyShaderTagIds[0], new SortingSettings(camera)
                )
                {
                    overrideMaterial = errorMaterial

                };
                for (int i = 1; i < legacyShaderTagIds.Length; i++)
                {
                    drawingSettings.SetShaderPassName(i, legacyShaderTagIds[i]);
                }
                var filteringSettings = FilteringSettings.defaultValue;
                context.DrawRenderers(
                cullingResults, ref drawingSettings, ref filteringSettings
                );


            }

            RenderTexture.ReleaseTemporary(shadowMap);      // освобождаем память для карты, т.к. не очищаются сборщиком мусора

        }
    }
}
