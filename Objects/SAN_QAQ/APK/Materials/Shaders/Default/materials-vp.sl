#include "common.slh"
#include "materials-vertex-properties.slh"
#include "texture-coords-transform.slh"
#include "vp-fog-props.slh"

#ensuredefined HIGHLIGHT_WAVE_ANIM 0

vertex_in
{
	float4 localPos : POSITION;

	#if VERTEX_COLOR || USE_VERTEX_DISPLACEMENT
		float4 color0 : COLOR0;
	#endif

	#if MATERIAL_TEXTURE || TILED_DECAL_MASK
		float2 texCoord0 : TEXCOORD0;
	#endif

	#if ALPHA_MASK || MATERIAL_DECAL || (MATERIAL_LIGHTMAP && VIEW_DIFFUSE) || USE_VERTEX_DISPLACEMENT
		float2 texCoord1 : TEXCOORD1;
	#endif

	#if VERTEX_VERTICAL_OFFSET
		float offsetWeight : TEXCOORD5;
	#elif WIND_ANIMATION
		float flexibility : TEXCOORD5;
	#endif

	#if BLEND_BY_ANGLE || RECEIVE_SHADOW || USE_VERTEX_DISPLACEMENT
		float3 normal : NORMAL;
	#endif

	#include "skinning-vertex-input.slh"
};

vertex_out
{
	float4 localPos : SV_POSITION;
	float4 projPos : POSITION0;

	#if RECEIVE_SHADOW || HIGHLIGHT_WAVE_ANIM
		float3 worldPos : POSITION1;
	#endif

	#if VERTEX_COLOR
		float4 vertexColor : COLOR0;
	#endif

	#if MATERIAL_TEXTURE || TILED_DECAL_MASK
		float4 texCoord0 : TEXCOORD0;
	#endif

	#if (ALPHA_MASK || MATERIAL_DECAL || (MATERIAL_LIGHTMAP && VIEW_DIFFUSE)) || MATERIAL_DETAIL
		float4 texCoord1 : TEXCOORD1;
	#endif

	#if BLEND_BY_ANGLE || RECEIVE_SHADOW
		float4 worldNormalSlope : TEXCOORD2;
	#endif

	#if BLEND_BY_ANGLE
		float3 toCamDir : TEXCOORD3;
	#endif

	#if FLOWMAP
		float3 flowData : TEXCOORD4; // For flowmap animations - xy next frame uv. z - frame time
	#endif

	#if USE_VERTEX_FOG
		float4 varFog : TEXCOORD5;
	#endif
};

#if BLEND_BY_ANGLE || RECEIVE_SHADOW
	[auto][a] property float4x4 worldInvTransposeMatrix;
#endif

#if RECEIVE_SHADOW
	[auto][a] property float4x4 worldViewInvTransposeMatrix;
#endif

#if RECEIVE_SHADOW || USE_VERTEX_FOG
	[auto][a] property float4 lightPosition0;
#endif

#if !SETUP_LIGHTMAP && MATERIAL_LIGHTMAP && VIEW_DIFFUSE
	[material][a] property float2 uvOffset = const0List2;
	[material][a] property float2 uvScale = const0List2;
#endif

#if DISTANCE_FADE_OUT && VERTEX_COLOR
	[material][a] property float2 distanceFadeNearFarSq;
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

	#if PUSH_TO_NEAR_PLANE_HACK
		output.localPos.z = (output.localPos.z / output.localPos.w * 0.00005 + 0.00005) * output.localPos.w - output.localPos.w;
	#endif

	#if VERTEX_COLOR
		output.vertexColor = input.color0;

		#if DISTANCE_FADE_OUT
			output.vertexColor.a -= output.vertexColor.a * smoothstep(distanceFadeNearFarSq.x, distanceFadeNearFarSq.y, dot(toCamDir, toCamDir));
		#endif
	#endif

	#if MATERIAL_TEXTURE || TILED_DECAL_MASK
		output.texCoord0.xy = getTexCoordsTransform0(input.texCoord0);

		#if TEXTURE0_SHIFT_ENABLED
			output.texCoord0.xy += texture0Shift;
		#endif

		#if TEXTURE0_ANIMATION_SHIFT
			output.texCoord0.xy += frac(tex0ShiftPerSecond * globalTime);
		#endif
	#endif

	#if TILED_DECAL_MASK
		output.texCoord0.zw = output.texCoord0.xy * decalTileCoordScale;

		#if TILED_DECAL_TRANSFORM
			#if HARD_SKINNING
				output.texCoord0.zw = getTexCoordsTransform2(output.texCoord0.zw, int(input.index * 2.0));
			#elif !SOFT_SKINNING
				output.texCoord0.zw = getTexCoordsTransform1(output.texCoord0.zw);
			#endif
		#endif
	#endif

	#if ALPHA_MASK || MATERIAL_DECAL || (MATERIAL_LIGHTMAP && VIEW_DIFFUSE)
		#if !SETUP_LIGHTMAP && MATERIAL_LIGHTMAP && VIEW_DIFFUSE
			output.texCoord1.xy = input.texCoord1 * uvScale + uvOffset;
		#else
			output.texCoord1.xy = input.texCoord1;
		#endif
	#endif

	#if MATERIAL_DETAIL
		output.texCoord1.zw = output.texCoord0.xy * detailTileCoordScale;
	#endif

	#if BLEND_BY_ANGLE || (DISTANCE_FADE_OUT && VERTEX_COLOR) || USE_VERTEX_FOG
		float3 toCamDir = camPos - worldPos;
	#endif

	#if RECEIVE_SHADOW || USE_VERTEX_FOG
		float3 toLightDir = -eyePos * lightPosition0.w + lightPosition0.xyz;
		float toLightDis = length(toLightDir);
		toLightDir /= toLightDis;
	#endif

	#if RECEIVE_SHADOW || HIGHLIGHT_WAVE_ANIM
		output.worldPos = worldPos;
	#endif

	#if BLEND_BY_ANGLE || RECEIVE_SHADOW
		output.worldNormalSlope.xyz = normalize(mul(float4(input.normal, 0.0), worldInvTransposeMatrix).xyz);
	#endif

	#if RECEIVE_SHADOW
		float3 normal = input.normal;

		#if SOFT_SKINNING
			normal = softSkinnedNormal(normal, input.indices, input.weights);
		#elif HARD_SKINNING
			normal = hardSkinnedNormal(normal, input.index);
		#endif

		output.worldNormalSlope.w = 1.0 - saturate(dot(normalize(mul(float4(normal, 0.0), worldViewInvTransposeMatrix).xyz), toLightDir));
	#endif

	#if BLEND_BY_ANGLE
		output.toCamDir = toCamDir;
	#endif

	#include "flowmap-vec.slh"

	#if USE_VERTEX_FOG
		#include "vp-fog-math.slh"
	#endif

	return output;
}
