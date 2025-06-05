// Maksim_Vinogradov
// 05_2025_Render_Programmer_Test

using UnityEngine;
using UnityEngine.Rendering;

namespace EntitiesGraphics
{
    internal class RenderContext
    {
        private ScriptableRenderContext context;
        private CullingResults cullingResults;
        private Camera camera;

        public RenderContext(ScriptableRenderContext context, CullingResults cullingResults, Camera camera)
        {
            this.context = context;
            this.cullingResults = cullingResults;
            this.camera = camera;
        }
    }
}