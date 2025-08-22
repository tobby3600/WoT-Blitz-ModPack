#include "common.slh"
#include "lighting.slh"
#include "materials-vertex-properties.slh"
#include "texture-coords-transform.slh"
#include "vp-fog-props.slh"

#ensuredefined HIGHLIGHT_WAVE_ANIM 0

#define NEED_CHAIN_TEXCOORD_OFFSETS 1

#if INSTANCED_CHAIN
	#include "instanced-chain.slh"
#endif

vertex_in
{
	float4 localPos : POSITION;
	float3 normal : NORMAL;

	#if PIXEL_LIT
		float3 tangent : TANGENT;
		float3 binormal : BINORMAL;
	#endif

	#if MATERIAL_TEXTURE
		float2 texCoord0 : TEXCOORD0;
	#endif

	#if ALPHA_MASK || USE_VERTEX_DISPLACEMENT
		float2 texCoord1 : TEXCOORD1;
	#endif

	#if USE_VERTEX_DISPLACEMENT || VERTEX_COLOR
		float4 color0 : COLOR0;
	#endif

	#include "skinning-vertex-input.slh"
};

vertex_out
{
	float4 localPos : SV_POSITION;
	float4 projPos : POSITION0;

	#if HIGHLIGHT_WAVE_ANIM || (TILED_DECAL_MASK && TILED_DECAL_SPATIAL_SPREADING)
		float4 displacePos : POSITION1;
	#endif

	#if !PIXEL_LIT && RECEIVE_SHADOW
		float3 worldPos : POSITION2;
		float4 worldNormalSlope : POSITION3;
	#endif

	#if MATERIAL_TEXTURE || PIXEL_LIT || TILED_DECAL_MASK
		float4 texCoord0 : TEXCOORD0;
	#endif

	#if ALPHA_MASK || MATERIAL_DETAIL
		float4 texCoord1 : TEXCOORD1;
	#endif

	#if (!ENVIRONMENT_MAPPING_NORMALMAP && ENVIRONMENT_MAPPING) || (HARD_SKINNING && TILED_DECAL_MASK)
		float4 texCoord2 : TEXCOORD2;
	#endif

	#if PIXEL_LIT
		float3 toLightDir : TEXCOORD3;
		float3 toCamDir : TEXCOORD4;
		float4 tangentToView0 : TANGENTTOVIEW0;
		float4 tangentToView1 : TANGENTTOVIEW1;
		float4 tangentToView2 : TANGENTTOVIEW2;

		#if RECEIVE_SHADOW
			float4 tangentToWorld0 : TANGENTTOWORLD0;
			float4 tangentToWorld1 : TANGENTTOWORLD1;
			float4 tangentToWorld2 : TANGENTTOWORLD2;
		#endif
	#else
		#if SIMPLE_BLINN_PHONG
			float4 diffuseSpecularVector : TEXCOORD3;
		#elif NORMALIZED_BLINN_PHONG
			float3 diffuseVector : TEXCOORD3;
			float4 specularVector : TEXCOORD4;
		#endif
	#endif

	#if USE_VERTEX_FOG
		float4 varFog : TEXCOORD5;
	#endif

	#if TILED_DECAL_ANIMATED_EMISSION && TILED_DECAL_MASK
		float4 aniCamo : COLOR0;
	#endif

	#if VERTEX_COLOR
		float4 vertexColor : COLOR1;
	#endif
};

[auto][a] property float4 lightPosition0;
[auto][a] property float4x4 worldViewInvTransposeMatrix;

#if ENVIRONMENT_MAPPING || RECEIVE_SHADOW
	[auto][a] property float4x4 worldInvTransposeMatrix;
#endif

#if !PIXEL_LIT
	[auto][a] property float3 lightColor0;
	[auto][a] property float4x4 pointLights; // 0,1:(position, radius); 2:3 (color, unused)

	[material][a] property float materialSpecularShininess = 0.5;
	[material][a] property float inSpecularity = 1.0;
	[material][a] property float inGlossiness = 0.5;
	[material][a] property float3 metalFresnelReflectance = float3(0.562, 0.565, 0.578);
#endif

#if HARD_SKINNING && TILED_DECAL_MASK
	[material][a] property float4 jointToDecalTextureMapping;
#endif

#if MATERIAL_DETAIL
	[material][a] property float2 detailTileCoordScale = const1List2;
#endif

#if TEXTURE0_ANIMATION_SHIFT
	[material][a] property float2 tex0ShiftPerSecond = const0List2;
#endif

#if TEXTURE0_SHIFT_ENABLED
	[material][a] property float2 texture0Shift = const0List2;
#endif

vertex_out vp_main(vertex_in input)
{
	vertex_out output;

	#include "materials-vertex-processing.slh"

	float3 toCamDir = camPos - worldPos;
	float3 toLightDir = viewPos * lightPosition0.w + lightPosition0.xyz;
	float toLightDis = length(toLightDir);
	toLightDir /= toLightDis;

	float3 L = toLightDir;
	float3 V = normalize(viewPos);

	#if USE_VERTEX_FOG
		#include "vp-fog-math.slh"
	#endif

	#if PIXEL_LIT
		float3 normal = input.normal;
		float3 binormal = input.binormal;
		float3 tangent = input.tangent;

		#if INSTANCED_CHAIN
			normal.yz = rotate(normal.yz, segmentDir);
			binormal.yz = rotate(binormal.yz, segmentDir);
			tangent.yz = rotate(tangent.yz, segmentDir);
			normal = normalize(normal);
			binormal = normalize(binormal);
			tangent = normalize(tangent);
		#endif

		#if SOFT_SKINNING
			float3x3 tbn = softSkinnedTBN(tangent, binormal, normal, input.indices, input.weights);
			tangent = tbn[0];
			binormal = tbn[1];
			normal = tbn[2];
		#elif HARD_SKINNING
			float3x3 tbn = hardSkinnedTBN(tangent, binormal, normal, input.index);
			tangent = tbn[0];
			binormal = tbn[1];
			normal = tbn[2];
		#endif

		float3 t = normalize(mul(float4(tangent, 0.0), worldViewInvTransposeMatrix).xyz);
		float3 b = normalize(mul(float4(binormal, 0.0), worldViewInvTransposeMatrix).xyz);
		float3 n = normalize(mul(float4(normal, 0.0), worldViewInvTransposeMatrix).xyz);

		output.tangentToView0 = float4(t.x, b.x, n.x, viewPos.x);
		output.tangentToView1 = float4(t.y, b.y, n.y, viewPos.y);
		output.tangentToView2 = float4(t.z, b.z, n.z, viewPos.z);
		output.toLightDir = float3(dot(toLightDir, t), dot(toLightDir, b), dot(toLightDir, n));
		output.toCamDir = float3(dot(viewPos, t), dot(viewPos, b), dot(viewPos, n));

		#if RECEIVE_SHADOW
			t = normalize(mul(float4(tangent, 0.0), worldInvTransposeMatrix).xyz);
			b = normalize(mul(float4(binormal, 0.0), worldInvTransposeMatrix).xyz);
			n = normalize(mul(float4(normal, 0.0), worldInvTransposeMatrix).xyz);

			output.tangentToWorld0 = float4(t.x, b.x, n.x, worldPos.x);
			output.tangentToWorld1 = float4(t.y, b.y, n.y, worldPos.y);
			output.tangentToWorld2 = float4(t.z, b.z, n.z, worldPos.z);
		#endif
	#else
		float3 normal = input.normal;

		#if INSTANCED_CHAIN
			normal.yz = rotate(normal.yz, segmentDir);
			normal = normalize(normal);
		#elif SOFT_SKINNING
			normal = softSkinnedNormal(normal, input.indices, input.weights);
		#elif HARD_SKINNING
			normal = hardSkinnedNormal(normal, input.index);
		#endif

		float3 N = normalize(mul(float4(normal, 0.0), worldViewInvTransposeMatrix).xyz);
		float NdotL = saturate(dot(N, L));

		#if RECEIVE_SHADOW
			output.worldNormalSlope = float4(normalize(mul(float4(input.normal, 0.0), worldInvTransposeMatrix).xyz), 1.0 - NdotL);
		#endif

		#if SIMPLE_BLINN_PHONG
			output.diffuseSpecularVector= float4(NdotL, NdotL, NdotL, pow(saturate(dot(N, normalize(L + V))), materialSpecularShininess));
		#elif NORMALIZED_BLINN_PHONG
			float3 H = normalize(L + V);

			float NdotV = saturate(dot(N, V));
			float NdotH = saturate(dot(N, H));
			float VdotH = saturate(dot(V, H));

			output.diffuseVector = lightColor0 * (NdotL * _INVERSE_PI);
			output.specularVector = float4(lerp(metalFresnelReflectance, const1List3, pow5Exp(NdotV)) * (NdotL * inSpecularity / (VdotH * VdotH + 1e-4)), NdotH);

			#if MAX_POINT_LIGHTS > 0
				output.diffuseVector += getBlinnPhongPointLight(pointLights[0].w, pointLights[2], pointLights[0].xyz + viewPos, N);
			#endif

			#if MAX_POINT_LIGHTS > 1
				output.diffuseVector += getBlinnPhongPointLight(pointLights[1].w, pointLights[3], pointLights[1].xyz + viewPos, N);
			#endif
		#endif
	#endif

	#if VERTEX_COLOR
		output.vertexColor = input.color0;
	#endif

	#if MATERIAL_TEXTURE || TILED_DECAL_MASK
		output.texCoord0.xy = input.texCoord0;

		#if INSTANCED_CHAIN
			output.texCoord0.y = output.texCoord0.y * segPerChunkLength + getTexCoordOffset(instanceId + uint(1));
		#endif

		output.texCoord0.xy = getTexCoordsTransform0(output.texCoord0.xy);
	#endif

	#if MATERIAL_TEXTURE
		#if TEXTURE0_ANIMATION_SHIFT
			output.texCoord0.xy += frac(tex0ShiftPerSecond * globalTime);
		#endif

		#if TEXTURE0_SHIFT_ENABLED
			output.texCoord0.xy += texture0Shift;
		#endif
	#endif

	#if TILED_DECAL_MASK
		#include "decal-mask.slh"
	#endif

	#if ALPHA_MASK
		output.texCoord1.xy = input.texCoord1;
	#endif

	#if MATERIAL_DETAIL
		output.texCoord1.zw = output.texCoord0.xy * detailTileCoordScale;
	#endif

	#if !ENVIRONMENT_MAPPING_NORMALMAP && ENVIRONMENT_MAPPING
		output.texCoord2.xyz = reflect(normalize(-toCamDir), normalize(mul(float4(input.normal, 0.0), worldInvTransposeMatrix).xyz));
	#endif

	#if HARD_SKINNING && TILED_DECAL_MASK
		output.texCoord2.w = jointToDecalTextureMapping[int(clamp(input.index, 0.0, 3.0))];
	#endif

	#if TILED_DECAL_MASK && TILED_DECAL_SPATIAL_SPREADING
		output.displacePos.xyz = displacePos;
	#endif

	#if HIGHLIGHT_WAVE_ANIM
		output.displacePos.w = worldPos.z;
	#endif

	#if !PIXEL_LIT && RECEIVE_SHADOW
		output.worldPos = worldPos;
	#endif

	return output;
}
