// Maksim_Vinogradov
// 05_2025_Render_Programmer_Test

Shader "Custom/PBR"
{	
    Properties {	 
		// GUI и ПАРАМЕТРЫ********************************************************************************************************************************************************
		//[KeywordEnum(Directional,IBL)] _Light ("Lighting Mode", Float) = 0				// режим освещения
		_TintColor("Tint Color", Color) = (1.0, 1.0, 1.0, 1.0)							// Окрашивание диффузного цвета
		_DiffuseMap("Diffuse map", 2D) = "white" {}										// текстура Альбедо
		_diffuseFactor("Diffuse %",Range(0.3,1)) = 1										// поправочный коэффициент
		_Cutoff ("Alpha Cutoff", Range(0.0, 1.0)) = 0.5									// Alpha Cutoff
		[Toggle(_CLIPPING)] _Clipping ("Alpha Clipping", Float) = 0						// Clipping
		[KeywordEnum(Off,On)] _USE_NORMAL_MAP ("Use Normal Map?", Float) = 0			// использовать ли Normal map?
		_NormalMap("Normal map", 2D) = "bump" {}										// текстура Нормалей
		_NormalScale("Normal Scale", Range(0, 2)) = 1									// Normal strength
		[KeywordEnum(Iso,Aniso)] _Spec ("Specular Reflection Type", Float) = 0			// выбор зеркальных отражений
		//[Toggle(_METALL)] _Metall ("Is Metallic?", Float) = 0							// Металл?
		_MetallicMap("Metallic map", 2D) = "white" {}									// текстура Металличности
		_metallicFactor("Metallic %",Range(0,1)) = 0									// параметр отражения по Fresnel F0
		_RoughnessMap("Roughness map", 2D) = "white" {}									// текстура Шероховатости
		_roughnessFactor("Roughness", Range(0.0, 1)) = 0.5								// параметр Шероховатости
		_shadowFactor("ShadowClamp", Range(0.0, 1)) = 0.5								// мягкость теней

		_TangentMap ("Tangent Map", 2D) = "white" {}
		_AnisoU("Aniso nU", Float) = 1													// параметры, котнролирующие Блик зеркальных отражений
		_AnisoV("Aniso nV", Float) = 1
		_SpecularPower("Specular_Power", Range(0, 2)) = 1								// пар-р Блика
		
		 //СВОЙСТВА ДЛЯ IMAGE BASED LIGHTING
		_CubeMap ("Reflection Cubemap", CUBE) = "white" {}								// кубическая текстура для IBL
		_etaRatio ("Eta Ratio", Range(0.01,3)) = 1.5									// отношение коэф преломления IOR
		[KeywordEnum(Off, Refl, Refr, Fres)] _IBLMode ("IBL Mode", Float) = 0			// режимы отображения
		_ReflectionFactor("Reflection %",Range(0,1)) = 1
		_Detail ("Reflection Detail", Range(1,9)) = 1.0
		_ReflectionExposure("HDR Exposure", float) = 1.0
		_RefractionFactor("Refraction %",Range(0,1)) = 1
		_FresnelWidth("FresnelWidth", Range(0,1)) = 0.3

		[Enum(UnityEngine.Rendering.BlendMode)] _SrcBlend ("Src Blend", Float) = 1		// выбор режима смешивания передний фон Src
		[Enum(UnityEngine.Rendering.BlendMode)] _DstBlend ("Dst Blend", Float) = 0		// выбор режима смешивания задний фон Dst
        [Enum(Off, 0, On, 1)] _ZWrite ("Z Write", Float) = 1							// записываем ли буфер глубины?
	}
	
	SubShader {
		
		// STANDART Pass /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

		Pass
		{
			Tags { "LightMode" = "CustomLit" }
			Blend [_SrcBlend] [_DstBlend]
            ZWrite [_ZWrite]
			HLSLPROGRAM
			// команды компилятору  **********************************************************************************************************************************************************
			// shader_feature - only used compiled variation in build
			// multi_compile - all compiled variation included
			#pragma target 4.5														// DOTS Instancing поддерживают от 4.5 версии и выше
			#pragma multi_compile_instancing										// для gpu instancing
			#pragma vertex myVertexShader											// вершинный шэйдер
			#pragma fragment myFragmentShader										// пиксельный шэйдер
			#pragma shader_feature _CLIPPING
			#pragma shader_feature _USE_NORMAL_MAP_ON _USE_NORMAL_MAP_OFF			// ifdef _USE_NORMALMAP_ON #else будет означать (_USE_NORMAL_MAP_OFF)
			#pragma shader_feature _METALL											
			#pragma shader_feature _SPEC_ISO _SPEC_ANISO 							// !!!ВАЖНО ПИСАТЬ ЗДЕСЬ И В ТЕКСТЕ КАПСОМ и НАЗВАНИЕ В СВ_ВАХ ДОЛЖНЫ СОВПАДАТЬ!
			#pragma shader_feature _IBLMODE_OFF _IBLMODE_REFL _IBLMODE_REFR _IBLMODE_FRES
			#define UNITY_MATRIX_M unity_ObjectToWorld								// UNITY_MATRIX_M это матрица unity_ObjectToWorld для инстансов
			#define UNITY_MATRIX_I_M unity_WorldToObject							// обратная матрица
			#define UNITY_MATRIX_V unity_MatrixV									// View матрица
			#define UNITY_MATRIX_VP unity_MatrixVP									// ViewProjection матрица
			#define UNITY_MATRIX_P glstate_matrix_projection						// Projection матрица

						
			// ПОДГРУЖАЕМ БИБЛИОТЕКИ и Макросы **********************************************************************************************************************************************
			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/UnityInstancing.hlsl"
			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Packing.hlsl"
			// CBUFFER_START (END) - Макросы из Core RP library (Asset Packages)
			// Св-ва материалов заключаем внутри буффера памяти, а не на глобальном уровне
			// Проверяем как отрабатывает batching  в окне Statistics при запуске игры
			
			//БУФФЕРЫ ДАННЫХ *****************************************************************************************************************************************************************


			//задаем данные для каждого материала
			CBUFFER_START(UnityPerMaterial)
				float4 _TintColor;
				float4 _DiffuseMap_ST;					
				float _metallicFactor;	
				float _Roughness;
				float _roughnessFactor;	
				float _diffuseFactor;	
				float _NormalScale;
				float _Cutoff;
				float _SpecularPower;
				float _SpecularFactor;
				float _ReflectionExposure;			
				float _RefractionFactor;
				float _ReflectionFactor;
				float _FresnelWidth;
				float _etaRatio;
				float _Detail;
				float _shadowFactor;
				float _AnisoU;
				float _AnisoV; 
			CBUFFER_END

			// задаем параметры для освещения
			// также задаем эти параметры в commandBuffer в MyRenderPipeline
			#define MAX_VISIBLE_LIGHTS 2		// макс число источников освещения

			CBUFFER_START(UnityPerFrame)										// одинаковые параметры для всех объектов в кадре (камеры, свет)
				float4 _VisibleLightColors[MAX_VISIBLE_LIGHTS];
				float4x4 _WorldToShadowMatrix;									// clipspace  (с точки зрения света как камеры)
				float3 _WorldSpaceLightPos0;
				float4 _WorldSpaceCameraPos;
				float4 _VisibleLightDirectionsOrPositions[MAX_VISIBLE_LIGHTS];	// координата w указывает на point или dir light (1 или 0)
				float3 _DirectionalLightColor;
				float3 _DirectionalLightDirection;
			CBUFFER_END


				float4x4 unity_MatrixVP;					
			CBUFFER_START(UnityPerDraw)											// параметры, зависящие от конкретного объекта
				float4x4 unity_ObjectToWorld;
				float4x4 _WorldToObject;
				float4 unity_LODFade;
				real4 unity_WorldTransformParams;
			CBUFFER_END
									
			
			// ГЛОБАЛЬНЫЕ ПРЕМЕННЫЕ (UNIFORM) **********************************************************************************************************************************************
			// определяются не из шэйдера, а задаются программой, скриптом и тд
				
			// Текстуры и сэмплеры не могут быть одними для каждого инстанса
				TEXTURE2D(_DiffuseMap);				// карта Альбедо
				SAMPLER(sampler_DiffuseMap);		// sampler для диффузной карты
				TEXTURE2D(_MetallicMap);
				SAMPLER(sampler_MetallicMap);
				TEXTURE2D(_RoughnessMap);
				SAMPLER(sampler_RoughnessMap);
				TEXTURE2D(_NormalMap);
				TEXTURE2D(_TangentMap);
				TEXTURE2D_SHADOW (_ShadowMap);		// карта теней для определения находится ли пиксель в тени
				SAMPLER_CMP (sampler_ShadowMap);	// sampler CMP - сравнение по Z

			//	#if defined (_IBL_MODE)
					samplerCUBE _CubeMap;			// Sampler для Кубическая карта
			//	#endif

			// СТРУКТУРЫ - контейнеры с данными ******************************************************************************************************************************************************************
			
			// INPUT DATA from CPU
			//  Vertex Attribute -  input data для вершинного шэйдера (позиция, нормали, цвет, индексы и тд) в ObjectSpace
			//	название переменной : СЕМАНТИКА
			
			struct VertexAttributes
			{
				float3 positionOS	: POSITION;					// позиция как аттрибут, где OS - Object Space
				float3 normal		: NORMAL;					// нормали как аттрибут
				float4 tangent		: TANGENT;					// касательные как аттрибут
																// бинормали как аттрибут высчитываются через cross product
				float2 UV			: TEXCOORD;					// текстурные координаты как аттрибут

				UNITY_VERTEX_INPUT_INSTANCE_ID					// инстанс ID объекта как аттрибут
			};
			
	
			//INTERPOLATION DATA (Fragment shader input)
			// output data из вершинного шэйдера (позиция, нормали, цвет и тд)
			// название : СЕМАНТИКА присваиваются в регистры и передаются растеризатору для интерполяции

			struct Varyings 
			{
				float4 positionCLIP : SV_POSITION;		// пололжение вершин в ClipSpace (NDS Space), (регистр позиции SV_POSITION)
				float3 positionWS	: TEXCOORD0;		// пололжение вершин в WorldSpace
				float2 UV			: TEXCOORD1;		// текстурные координаты UV
				float2 normalUV		: TEXCOORD5;	
				float2 tangentUV	: TEXCOORD6;
				float3 normalWS		: TEXCOORD2;		// инф о нормалях в WS
				float4 tangentWS	: TEXCOORD3;		// инф о касательных в WS
				float3 binormalWS	: TEXCOORD4;		// инф о бинормалях в WS 
				
				UNITY_VERTEX_INPUT_INSTANCE_ID 
			};


			// FUNCTIONS ***********************************************************************************************************************************************************
			// Функции - контейнеры с инструкциями. Все функции можно записать в отдельный файл и ссылаться на них в коде, #include Function.hlsl и тд
			// В коде шэйдера мы вызываем функцию по имени и задаем (рассчитываем) нужные значения для функции в (input data)
			// далее функция высчитывает выходные данные (output data), используя заданные в шэйдере значения и выдает результат для шэйдера
			
			/*float3 SampleNormal(float2 uv, float3 normalWS, float3 tangentWS, float3 bitangentWS)
			{
				float3 normalTS = SAMPLE_TEXTURE2D(_NormalMap, sampler_DiffuseMap, uv).xyz * 2 - 1;
				float3x3 TBN = float3x3(tangentWS, bitangentWS, normalWS);
				return normalize(mul(normalTS, TBN));
			}*/
			float3 DecodeNormal (float4 sample, float scale)
			{
				#if defined (UNITY_NO_DXT5nm)
					return normalize(UnpackNormalRGB(sample, scale));
				#else
					return normalize(UnpackNormalmapRGorAG(sample, scale));			// от цвета [0,1] к вектору [-1,1] 
				#endif
			}
			
			float3 get_normal_Tangent_Space (TEXTURE2D(_NormalMap), SAMPLER (_DiffuseMap_ST), float2 normalUV, float3 tangentWS, 
											 float3 binormalWS, float3 normalWS)
			{
					// Определяем цвет пикселя, используя карту нормалей (Tangent Space)
					
					float4 colorAtPixel = SAMPLE_TEXTURE2D(_NormalMap, _DiffuseMap_ST, normalUV);
					// 
					float scale = _NormalScale;
					float3 normalAtPixel = DecodeNormal(colorAtPixel,scale);
					
					normalWS = normalize(normalWS); 
					tangentWS = normalize(tangentWS);
					binormalWS = normalize(binormalWS);
					// Составляем матрицу TBN
					float3x3 TBNWorld = float3x3(tangentWS, binormalWS, normalWS);

					return normalize(mul(normalAtPixel, TBNWorld));	
			}

			float3 TransformObjectToWorld(float3 positionOS) {
				return mul(unity_ObjectToWorld, float4(positionOS, 1.0)).xyz;
			}
			
			float4 TransformWorldToHClip(float3 positionWS) {
				return mul(unity_MatrixVP, float4(positionWS, 1.0));
			}

			//**************************************************************************************************************************************************************
			//															The RENDERING EQUATION 
			//**************************************************************************************************************************************************************	
			//									 Lo(Wo) = Интеграл{Li(Wi) * f(Wi,Wo) * max(0,NdotL)dWi} + L_emission(Wo)
			//***************************************************************************************************************************************************************
			// В общем случае для единицы пов-ти учитывает поступающий свет от всех источников освещения со всех направлений
			// Li(Wi) = L_direct(Wi) + L_indirect(Wi)  - где direct - свет от ист. освещения, indirect - свет от других объектов
			// f(Wi,Wo) = BSDF или BRDF
			//	BSDF = учитывает поступающий свет со всех направлений по сфере (BRDF+BSSDF)
			//  BRDF = учитывает поступающий свет по полусфере (исключает Subsurface scattering и Refractions)
			//	IBL = ImageBasedLighting, т.е. свет поступающий от кубической карты, имитирующую окружающую среду

			// Approximation

			// FINAL_COLOR_at_pixel = LIGHT_term * MATERIAL_term * Geometry_term
			// FINALCOLOR = LIGHT_term * pi * BRDF(L,V) * Geometry_term 
			// LIGHT_term = различные св-ва света (position,direction,type of lightsource,color,intencity,attenuation,number of lights...)
			// Geometry term = max(0,NdotL) = кол-во света, поступающего на пов-ть 
			// MATERIAL_term = BRDF 

			// BRDF = RADIANCE/IRRADIANCE (отношение кол-ва света, отраженного от ед. пов-ти / кол-во света, поступающего на ед. пов-ти от источников света
			// BRDF(L,V) = какой % света из направления L (ист света) отражается в направлении V (в к-ом я смотрю на пов-ть) 
			// BRDF_lambert_blinn_phong = Диффузные Мdiff и Зеркальные отражения Mspec

			// FINALCOLOR = LIGHT_term * (BRDF_diff + BRDF_spec) * max(0,NdotL);

			// ДЛЯ ОДНОГО DIRECTIONAL LIGHT
			// LIGHT_term = LightColor * lightAttenuation = LightColor * 1  (+тени)

			// Classic Diffuse Lambert lighting model BRDF_diff = Mdiff/pi = TintColor * diffuseMap * коэффициент
			// Classic Specular lighting model Blinn-Phong BRDF_spec = (Mspec/pi)*(NdotH)^s/NdotL 


			// IZOTROPIC BRDF = BRDF_diff + BRDF_spec = Mdiff/pi + D(NdotH) * F(VdotH) * G(n,L,V)/ 4(NdotL)(NdotV)

			// D - Distribution term , F - Reflection (Fresnel term),  G - Geometry term (степень затенения/маскировки)
			// D - Distribution term - Roughness или Glossiness map или GGX microfacet distribution
			// F - Reflection (Fresnel term)
			// Schlick approximation Fresnel(V,H) = F0 + (1-F0)(1-VdotH)^5

			// METALL !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
			// F0 определяет цвет блика у металлов/неметаллов (F0 = 0.04 для диэлектриков и F0 ~ 0.5- 0.9 у металлов)
			// У МЕТАЛЛОВ ТОЛЬКО SPECULAR REFLECTIONS (Mdiff = 0) =>> Mdiff = diffuseMap * TintColor * (1-MetallicFactor)
			// specColor у металлов окрашивается, у диэлектриков всегда белый (specColor = 1 )

			// *************************************************************************************************************************************************************
			// FINALCOLOR = LightTerm * (DiffuseMap * TintColor * (1-MetallicFactor)  + BRDF_spec * _Tint_Specular) * max(0,NdotL)			
			// *************************************************************************************************************************************************************


			// Izotropic BRDF - отражения не изменяются при вращении пов-ти, Anizotropic - отражения меняются в зав-ти от вращения пов-ти

			// Specular Cook_Torrance_BRDF = D(NdotH) * F(VdotH) * G(n,L,V) / 4(NdotL)(NdotV)
			// Specular Cook_Torrance_BRDF = D_GGX_term * Fresnel_term * G_GGX_term / 4(NdotL)(NdotV)
			// Specular Cook_Torrance_BRDF = R^2/pi[(NdotH)^2(R^2-1)+1]^2 * Fresnel term * (NdotV)/(VdotH)(1-R/2)+R/2] / 4(NdotL)(NdotV)

			float Spec_Cook_Torrance_BRDF (float roughnessMap,float roughnessFactor, float3 normalDir, float3 lightDir,float3 viewDir, 
											float metallicMap, float metallicFactor, float specularPower, float3 lightColor)
			{	float gloss = 1-roughnessFactor;
				float R = roughnessMap * pow((1-0.95*gloss),2);
				float pi = 3.141592;
				float3 halfwayVector = normalize(lightDir + viewDir);                                              
				float3 NdotH = dot(normalDir, halfwayVector);														
				float3 NdotL = dot(normalDir, lightDir);
				float3 NdotV = dot(normalDir, viewDir);
				float3 VdotH = dot(viewDir, halfwayVector);
				float Dterm = pow(R,2) / pi;
				float power = pow((NdotH),2)*(pow(R,2)-1)+1;
				  Dterm /= pow(power,2);

				float Gterm = NdotV;
				Gterm /= (VdotH) * (1-R/2) + R/2;

				float fresnel_F0 = lerp (0.04, 1, metallicFactor);
				float Fresnel = fresnel_F0 + (1 - fresnel_F0) * pow(1.0 - VdotH, 5.0);
				
				float BRDF_spec = Dterm * Gterm * Fresnel;

				return BRDF_spec;
			}

			// ANIZOTROPIC SPECULAR BRDF
			// SpecularReflection = [sqrt((nU+1)(nV+1))*((NdotH)^ ((nU(HdotT)^2)+nV(NdotB)^2)/1-(NdotH)^2)* Fresnel term ]/8pi(VdotH)max((NdotL),(NdotV))
			
			float Spec_AshikhminShirleyPremoze_BRDF (float roughnessMap,float roughnessFactor,float nU, float nV, float3 tangentDir, float3 normalDir, float3 lightDir,
												float3 viewDir, float metallicMap, float metallicFactor, float specularPower, float3 lightColor)
			{	//float gloss = 1-roughnessFactor;
				//float R = roughnessMap * pow((1-0.95*gloss),2);
				float pi = 3.141592;
				float3 halfwayVector = normalize(lightDir + viewDir);                                       // H - вектор между View и Light
				float3 NdotH = dot(normalDir, halfwayVector);												// T - tangent / B - binormal / N - normal
				float3 NdotL = dot(normalDir, lightDir);
				float3 NdotV = dot(normalDir, viewDir);
				float3 HdotT = dot(halfwayVector, tangentDir);
				float3 HdotB = dot(halfwayVector, cross(tangentDir, normalDir));
				float3 VdotH = dot(viewDir, halfwayVector);
				float power = nU * pow(HdotT,2) + nV * pow(HdotB,2);
				power /= 1.0 - pow(NdotH,2);
				float BRDF_spec = sqrt((nU + 1) * (nV + 1)) * pow(NdotH, power);
				BRDF_spec /= 8.0 * pi * VdotH * max(NdotL, NdotV);

				float fresnel_F0 = lerp (0.04, 1, metallicFactor);
				float Fresnel = fresnel_F0 + (1 - fresnel_F0) * pow(1.0 - VdotH, 5.0);
				
				BRDF_spec *= Fresnel;
				return BRDF_spec;
			}
			// IMAGE BASED LIGHTING
			// отраженный и преломленный вектор попадают на кубическую карту и принимают цвет пикселя
			// для размытия (эффект blur) применяется texCUBElod

			float3 IBLRefl (samplerCUBE _CubeMap, float detail, float3 reflectWS, float exposure, float reflectionFactor)
			{
				float4 cubeMapCol = texCUBElod(_CubeMap, float4(reflectWS, detail)).rgba;
				return reflectionFactor * cubeMapCol.rgb * (cubeMapCol.a * exposure);
			}

			// VERTEX SHADER ********************************************************************************************************************************************************
			// инструкции выполняются для каждой вершины
			// функция myVertexShader выдает структуру Varyings, используя входные параметры (Vertex Attributes, также могут быть параметры освещения и тд)
			// ВЫЧИСЛЕНИЯ ДОЛЖНЫ БЫТЬ ВЫПОЛНЕНЫ В ОДНОМ ПРОСТРАНСТВЕ!

			Varyings myVertexShader (VertexAttributes input) 								// Берем данные из структуры VertexAttributes (input - название структуры)
			{	
				Varyings output;															// Структуру Varyings называем output
				UNITY_SETUP_INSTANCE_ID(input);
				UNITY_TRANSFER_INSTANCE_ID(input, output);
				output.positionWS = TransformObjectToWorld(input.positionOS);				// положение вершин в WS (w для points = 1) 
				output.positionCLIP = TransformWorldToHClip(output.positionWS);								// положение вершин в Clip Space
				output.normalWS = normalize(mul((float3x3)unity_ObjectToWorld, input.normal));	// трансформация нормалей из OS в WS (умножаем вектор столбец на транспон. обратную матрицу)
																								// записывая input.normal вначале = trans((float3x3)_unity_WorldToObject) * input.normal);
				output.tangentWS =  (normalize(mul((float3x3)unity_ObjectToWorld, input.tangent.xyz)),input.tangent.w);
				output.binormalWS = normalize(cross(output.normalWS, output.tangentWS) * input.tangent.w);

				output.UV = TRANSFORM_TEX(input.UV, _DiffuseMap);									// TRANSFORM_TEX = (input.UV.xy * _DiffuseMap_ST.xy + _DiffuseMap_ST.zw);
				output.normalUV = TRANSFORM_TEX(input.UV, _DiffuseMap);
				output.tangentUV = TRANSFORM_TEX(input.UV, _DiffuseMap);
				return output;

			}
			

			// FRAGMENT SHADER  ******************************************************************************************************************************************************
			// инструкции для каждого пикселя (данные интреполированы) 
			// функция myFragmentShader выдает цвет пикселя в COLOR BUFFER (SV_TARGET), используя входные параметры (Varyings, также могут быть параметры освещения и тд)
			// ВЫЧИСЛЕНИЯ ДОЛЖНЫ БЫТЬ ВЫПОЛНЕНЫ В ОДНОМ ПРОСТРАНСТВЕ!

		    float4 myFragmentShader (Varyings input) : SV_TARGET
			{
				UNITY_SETUP_INSTANCE_ID(input);

				float4 finalColor = float4(0,0,0,_TintColor.a);

				//CLIPPING
				#if defined(_CLIPPING)
					clip(_TintColor.a -_Cutoff);
				#endif


				// NORMALS

				#if defined (_USE_NORMAL_MAP_ON)
					float3 normalAtPixelWS = get_normal_Tangent_Space(_NormalMap,sampler_DiffuseMap, input.normalUV.xy, 
																	input.tangentWS.xyz, input.binormalWS.xyz, input.normalWS.xyz);
				#else
					float3 normalAtPixelWS = input.normalWS.xyz;
				#endif


				// LIGHT TERM_____________________________________________________________________________________________________________________________________________
				// ДЛЯ ОДНОГО DIRECTINAL LIGHT
				float3 lightDir  = normalize(_WorldSpaceLightPos0.xyz);
				float lightAttenuation = 1;																					// для Direction light
				float3 lightColor = _DirectionalLightColor.rgb;
				//LIGHT_term = lightColor * lightAttenuation;

				/* ДЛЯ НЕСКОЛЬКИХ ИСТОЧНИКОВ СВЕТА
					float3 lightColor = 0;
					for (int i = 0; i < MAX_VISIBLE_LIGHTS; i++) 
					{
						float3 lightDir = _VisibleLightDirectionsOrPositions[i].xyz 
									- input.positionWS * _VisibleLightDirectionsOrPositions[i].w;
						lightDir = normalize(lightDir);
						lightColor += _VisibleLightColors[i].rgb * saturate(dot(normalAtPixelWS, lightDir));
					}*/

				float4 shadowPos = mul(_WorldToShadowMatrix, float4(input.positionWS, 1.0)); 					// lighting calculation происходит в World Space
				shadowPos.xyz /= shadowPos.w;																	// perspective divide
				float shadowAttenuation = SAMPLE_TEXTURE2D_SHADOW(_ShadowMap, sampler_ShadowMap, shadowPos.xyz); // координаты точек xy на карте теней сравниваются по z координате 


				// DIFFUSE COLOR
				
				//Vectors
				float3 viewDirectionWS = normalize(_WorldSpaceCameraPos - input.positionWS);								// V View вектор
				float3 halfwayVector = normalize(lightDir + viewDirectionWS);												// H halfwayVector

			
				// SPECULAR COLOR

				float4 metallicMap = SAMPLE_TEXTURE2D (_MetallicMap,sampler_MetallicMap,input.UV);
				float4 roughnessMap = SAMPLE_TEXTURE2D (_RoughnessMap,sampler_RoughnessMap,input.UV);
				float4 tangentMap = SAMPLE_TEXTURE2D (_TangentMap,sampler_DiffuseMap,input.UV);


				#if defined (_SPEC_ISO)
					float3 Mspec = Spec_Cook_Torrance_BRDF (roughnessMap.r, _roughnessFactor,normalAtPixelWS, lightDir, viewDirectionWS, 
																	metallicMap.r, _metallicFactor, _SpecularPower,lightColor);
				#endif
					
				#if defined (_SPEC_ANISO)
					float3 Mspec = Spec_AshikhminShirleyPremoze_BRDF (roughnessMap.r, _roughnessFactor,_AnisoU, _AnisoV, tangentMap.xyz, normalAtPixelWS, 
																lightDir, viewDirectionWS, metallicMap.r, _metallicFactor, _SpecularPower,lightColor);
				#endif 


				//float4 diffuseMap = tex2D(_DiffuseMap,input.UV);
				//		_DiffuseMap.Sample(sampler_DiffuseMap, input.UV);
				float4 diffuseMap = SAMPLE_TEXTURE2D (_DiffuseMap,sampler_DiffuseMap,input.UV);   

				//float3 Mdiff = _TintColor * (1-_metallicFactor);
				
				float3 LIGHT_term =  lightColor * lightAttenuation * clamp(shadowAttenuation, _shadowFactor , 1);  


				// Geometry_term
				float3 NdotL = dot(normalAtPixelWS, lightDir);
				float Geometry_term = max(0,NdotL);


				//FINAL COLOR
				
				float3 specColor = lerp (1, _TintColor, _metallicFactor);

				//****************************************************************************************************************************************************************************
				finalColor.rgb +=  (diffuseMap * _diffuseFactor * _TintColor * (1-_metallicFactor) + Mspec * specColor *_SpecularPower )* LIGHT_term * Geometry_term;

				// РАССЧИТЫВАЕМ IBL

     		    float3 incidentWS = normalize(input.positionWS - _WorldSpaceCameraPos.xyz);						// определяем вектор падения 

				#if _IBLMODE_OFF
					return finalColor;
				#endif
				#if _IBLMODE_REFL
     				float3 reflectWS = reflect(incidentWS, normalAtPixelWS);										// вектор отражения	
					finalColor.rgb *= IBLRefl (_CubeMap, _Detail, reflectWS,  _ReflectionExposure, _ReflectionFactor);
				#endif
					
				#if _IBLMODE_REFR
					 float3 refractWS = refract(incidentWS, normalAtPixelWS, _etaRatio);								// вектор преломления
					 finalColor.rgb *= IBLRefl (_CubeMap, _Detail, refractWS,  _ReflectionExposure, _RefractionFactor);
				#endif
					
				#if _IBLMODE_FRES
					float3 reflectWS = reflect(incidentWS, normalAtPixelWS);
					float3 reflColor = IBLRefl (_CubeMap, _Detail, reflectWS,  _ReflectionExposure, _ReflectionFactor);
						
					float fresnel = 1 - saturate(dot(viewDirectionWS,normalAtPixelWS));
					fresnel = smoothstep( 1 - _FresnelWidth, 1, fresnel);
					finalColor.rgb = lerp(finalColor.rgb, finalColor.rgb * reflColor, fresnel);
				#endif
			
				return finalColor;
			}
			ENDHLSL
		}
		// SHADOW PASS ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

			Pass 
		{		
			Name "ShadowCaster"
				Tags { "LightMode" = "ShadowCaster" }
			
            HLSLPROGRAM
            
                       
			#pragma target 4.5					// 
			#pragma multi_compile_instancing  // для gpu instancing
			#pragma vertex MyVertexShadow		// вершинный шэйдер
			#pragma fragment MyFragmentShadow		// пиксельный шэйдер
			
			#define UNITY_MATRIX_M unity_ObjectToWorld			// UNITY_MATRIX_M это матрица unity_ObjectToWorld для инстансов
			#define UNITY_MATRIX_I_M unity_WorldToObject		// обратная матрица
			#define UNITY_MATRIX_V unity_MatrixV				// View матрица
			#define UNITY_MATRIX_VP unity_MatrixVP				// ViewProjection матрица
			#define UNITY_MATRIX_P glstate_matrix_projection	//Projection матрица
						
			// подгружаем библиотеки и Макросы
			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl" 
			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/UnityInstancing.hlsl"

			#define MAX_VISIBLE_LIGHTS 2	

			CBUFFER_START(UnityPerFrame)
				float4 _VisibleLightColors[MAX_VISIBLE_LIGHTS];
				float4 _VisibleLightDirectionsOrPositions[MAX_VISIBLE_LIGHTS];	
				float _ShadowBias;
				float4 _WorldSpaceCameraPos;
			CBUFFER_END
			float4x4 unity_MatrixVP;					

			CBUFFER_START(UnityPerDraw)											// параметры, зависящие от конкретного объекта
				float4x4 unity_ObjectToWorld;
				float4x4 _WorldToObject;
				float4 unity_LODFade;
				real4 unity_WorldTransformParams;
			CBUFFER_END
			float3 TransformObjectToWorld(float3 positionOS) {
				return mul(unity_ObjectToWorld, float4(positionOS, 1.0)).xyz;
			}
			
			float4 TransformWorldToHClip(float3 positionWS) {
				return mul(unity_MatrixVP, float4(positionWS, 1.0));
			}

			struct VertexInput {
				float3 positionOS : POSITION;
				UNITY_VERTEX_INPUT_INSTANCE_ID 
			};

			struct Varyings {
				float4 positionCLIP : SV_POSITION;
				float3 positionWS	: TEXCOORD0;
				UNITY_VERTEX_INPUT_INSTANCE_ID 
			};

			Varyings MyVertexShadow (VertexInput input) {
				Varyings output;
    
				UNITY_SETUP_INSTANCE_ID(input);
				UNITY_TRANSFER_INSTANCE_ID(input, output);
				output.positionWS = TransformObjectToWorld(input.positionOS);			
				output.positionCLIP = TransformWorldToHClip(output.positionWS);								
			
				#if UNITY_REVERSED_Z
					output.positionCLIP.z -= _ShadowBias;
				#else
					output.positionCLIP.z += _ShadowBias;
   				#endif
				return output;
			}

			float4 MyFragmentShadow (Varyings input) : SV_TARGET {
				return 0;
			}

						ENDHLSL
        }
    }
}