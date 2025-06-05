# SRP_git
ScriptableRenderPipeline 
Vinogradov Maksim

Переделал проект. Версия Unity 2022.3.62f

3 сцены: Sample scene, Dots, Compute shader

1. Sample scene - основная сцена
- Iso / Anisotropic BRDF переключаются в материале
- SRP Batcher работает
- в папке Scripts лежат скрипты SRP, SRPAsset и основа Shader PBR
  
2. Compute shader 
- хаотичное движение по окружности

3. Dots
- отображаются в scene, в game система определяет entities (шейдер не смог донастроить, ошибка с макросами)


P.S Кодировки исправил, ошибки при запуске проекта теперь нет, багов не наблюдал (скачивал и проверял на разных компьютерах)
