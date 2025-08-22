#define SHADOW_RECEIVER 1

#include "common.slh"
#include "materials-vertex-properties.slh"
#include "texture-coords-transform.slh"
#include "vp-fog-props.slh"

vertex_in
{
	float4 localPos : POSITION;

	#if USE_VERTEX_DISPLACEMENT
		float4 color0 : COLOR0;
	#endif

	#if ENVIRONMENT_MAPPING || MATERIAL_TEXTURE
		float2 texCoord0 : TEXCOORD0;
	#endif

	#if (MATERIAL_LIGHTMAP && VIEW_DIFFUSE) || USE_VERTEX_DISPLACEMENT
		float2 texCoord1 : TEXCOORD1;
	#endif

	#if ENVIRONMENT_MAPPING || RECEIVE_SHADOW || USE_VERTEX_DISPLACEMENT
		float3 normal : NORMAL;
	#endif

	#include "skinning-vertex-input.slh"
};

vertex_out
{
	float4 localPos : SV_POSITION;
	float4 projPos : POSITION0;

	#if RECEIVE_SHADOW
		float3 worldPos : POSITION1;
		float4 worldNormalSlope : POSITION2;
	#endif

	#if ENVIRONMENT_MAPPING || (MATERIAL_TEXTURE || (MATERIAL_LIGHTMAP && VIEW_DIFFUSE))
		float4 texCoord : TEXCOORD0;
	#endif

	#if ENVIRONMENT_MAPPING
		float4 specularVector : TEXCOORD1;
		float4 reflectionVector : TEXCOORD2;
	#endif

	#if USE_VERTEX_FOG
		float4 varFog : TEXCOORD3;
	#endif
};

[auto][a] property float4 lightPosition0;

#if ENVIRONMENT_MAPPING || RECEIVE_SHADOW
	[auto][a] property float4x4 worldInvTransposeMatrix;
	[auto][a] property float4x4 worldViewInvTransposeMatrix;
#endif

#if ENVIRONMENT_MAPPING
	[material][a] property float reflectionBrightenEnvMap = 3.0;
	[material][a] property float reflectionSpecular = 1.0;
	[material][a] property float3 reflectionMetalFresnelReflectance = float3(0.562, 0.565, 0.578);
#endif

#if !SETUP_LIGHTMAP && MATERIAL_LIGHTMAP && VIEW_DIFFUSE
	[material][a] property float2 uvOffset = const0List2;
	[material][a] property float2 uvScale = const0List2;
#endif

vertex_out vp_main(vertex_in input)
{
	vertex_out output;

	#include "materials-vertex-processing.slh"

	#if ENVIRONMENT_MAPPING || USE_VERTEX_FOG
		float3 toCamDir = camPos - worldPos;
	#endif

	#if ENVIRONMENT_MAPPING || RECEIVE_SHADOW || USE_VERTEX_FOG
		float3 toLightDir = -eyePos * lightPosition0.w + lightPosition0.xyz;
		float toLightDis = length(toLightDir);
		toLightDir /= toLightDis;
	#endif

	#if USE_VERTEX_FOG
		#include "vp-fog-math.slh"
	#endif

	#if ENVIRONMENT_MAPPING || MATERIAL_TEXTURE
		output.texCoord.xy = getTexCoordsTransform0(input.texCoord0);
	#endif

	#if MATERIAL_LIGHTMAP && VIEW_DIFFUSE
		output.texCoord.zw = input.texCoord1 * uvScale + uvOffset;

		#if SETUP_LIGHTMAP
			output.texCoord.zw = input.texCoord1;
		#else
	#endif

	#if ENVIRONMENT_MAPPING || RECEIVE_SHADOW
		float3 normal = input.normal;
		float3 worldNormal = normalize(mul(float4(normal, 0.0), worldInvTransposeMatrix).xyz);

		#if SOFT_SKINNING
			normal = softSkinnedNormal(normal, input.indices, input.weights);
		#elif HARD_SKINNING
			normal = hardSkinnedNormal(normal, input.index);
		#endif

		float3 L = toLightDir;
		float3 N = normalize(mul(float4(normal, 0.0), worldViewInvTransposeMatrix).xyz);
		float NdotL = saturate(dot(N, L));
	#endif

	#if ENVIRONMENT_MAPPING
		float3 V = normalize(-eyePos);
		float3 H = normalize(L + V);

		float NdotV = saturate(dot(N, V));
		float NdotH = saturate(dot(N, H));
		float VdotH = saturate(dot(V, H));

		float3 fresnelOut = lerp(reflectionMetalFresnelReflectance, const1List3, pow5Exp(NdotV));

		output.specularVector = float4(fresnelOut * (NdotL * reflectionSpecular / (VdotH * VdotH + 1e-4)), NdotH);
		output.reflectionVector = float4(reflect(normalize(-toCamDir), worldNormal), dot(fresnelOut, rgbMixList * reflectionBrightenEnvMap));
	#endif

	#if RECEIVE_SHADOW
		output.worldPos = worldPos;
		output.worldNormalSlope = float4(worldNormal, 1.0 - NdotL);
	#endif

	return output;
}
