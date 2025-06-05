// Maksim_Vinogradov
// 05_2025_Render_Programmer_Test

Shader "Custom/NewUnlitShader"
{
    Properties 
	{
		_BaseColor("Color", Color) = (1.0, 1.0, 1.0, 1.0)
		[Enum(UnityEngine.Rendering.BlendMode)] _SrcBlend ("Src Blend", Float) = 1	
		[Enum(UnityEngine.Rendering.BlendMode)] _DstBlend ("Dst Blend", Float) = 0
        [Enum(Off, 0, On, 1)] _ZWrite ("Z Write", Float) = 1			
		[HideInInspector]_ComputeMeshIndex("Compute Mesh Buffer Index Offset", Float) = 0
	}
	
	SubShader {
		
		Pass	{Tags { "LightMode" = "CustomLit" }
			Blend [_SrcBlend] [_DstBlend]
            ZWrite [_ZWrite]
			Cull Off

		HLSLPROGRAM
			// команды компилятору
			#pragma target 4.5					
			#pragma multi_compile_instancing 
			#pragma vertex myVertexShader			
			#pragma fragment MyFragment		
			#pragma instancing_options renderinglayer
			#pragma multi_compile _ DOTS_INSTANCING_ON
			#define UNITY_MATRIX_M unity_ObjectToWorld
			#define UNITY_MATRIX_I_M unity_WorldToObject
			#define UNITY_MATRIX_V unity_MatrixV
			#define UNITY_MATRIX_I_V unity_MatrixInvV
			#define UNITY_MATRIX_VP unity_MatrixVP
			#define UNITY_PREV_MATRIX_M unity_prev_MatrixM
			#define UNITY_PREV_MATRIX_I_M unity_prev_MatrixIM
			#define UNITY_MATRIX_P glstate_matrix_projection
			// подгружаем библиотеки и Макросы
			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl" 
			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/UnityInstancing.hlsl"
			//#include "Packages/com.unity.entities.graphics/ShaderLibrary/EntityLighting.hlsl"

			CBUFFER_START(UnityPerDraw)
				float4x4 unity_ObjectToWorld;
				float4x4 unity_WorldToObject;
				float4x4 unity_MatrixV;
				float4x4 unity_MatrixInvV;
				float4x4 unity_prev_MatrixIM;
				float4x4 glstate_matrix_projection;
			CBUFFER_END

				float4x4 unity_MatrixVP;

				
            CBUFFER_START(UnityPerMaterial)
                float4 _BaseColor;
            CBUFFER_END

			#ifdef UNITY_DOTS_INSTANCING_ENABLED
                UNITY_DOTS_INSTANCING_START(MaterialPropertyMetadata)
                    UNITY_DOTS_INSTANCED_PROP(float4, _BaseColor)
                UNITY_DOTS_INSTANCING_END(MaterialPropertyMetadata)
                #define _BaseColor UNITY_ACCESS_DOTS_INSTANCED_PROP_WITH_DEFAULT(float4, _BaseColor)
            #endif

			

			struct VertexAttributes
			{
				float3 positionOS : POSITION;		
				
				
				UNITY_VERTEX_INPUT_INSTANCE_ID				
			};

			struct Varyings
			{
				float4 positionCLIP : SV_POSITION; 
				float3 positionWS	: TEXCOORD0;
				
				
				UNITY_VERTEX_INPUT_INSTANCE_ID 

			};

				Varyings myVertexShader (VertexAttributes input) 								
			{	
				Varyings output;															
				UNITY_SETUP_INSTANCE_ID(input);
				UNITY_TRANSFER_INSTANCE_ID(input, output);
				float4 positionWS = mul(UNITY_MATRIX_M, float4(input.positionOS, 1.0));
				output.positionWS = positionWS.xyz;
				//output.positionWS = TransformObjectToWorld(input.positionOS);				
				output.positionCLIP = mul(UNITY_MATRIX_VP, positionWS);
				return output;
			
			}

			
			float4 MyFragment(Varyings input) : SV_TARGET {
				UNITY_SETUP_INSTANCE_ID(input);
                return  _BaseColor;
			}
			ENDHLSL
		}
	}
}