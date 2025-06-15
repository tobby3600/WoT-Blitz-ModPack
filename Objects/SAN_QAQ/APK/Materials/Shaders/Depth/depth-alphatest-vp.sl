#include "common.slh"

#define DRAW_DEPTH_ONLY 1
#define NEED_CHAIN_TEXCOORD_OFFSETS 1

#include "materials-vertex-properties.slh"

#if INSTANCED_CHAIN
	#include "instanced-chain.slh"
#endif

vertex_in
{
	float4 localPos : POSITION;

	#if MATERIAL_TEXTURE
		float2 texCoord0 : TEXCOORD0;
	#endif

	#if ALPHA_MASK || USE_VERTEX_DISPLACEMENT
		float2 texCoord1 : TEXCOORD1;
	#endif

	#if VERTEX_VERTICAL_OFFSET
		float offsetWeight : TEXCOORD5;
	#elif WIND_ANIMATION
		float flexibility : TEXCOORD5;
	#endif

	#if USE_VERTEX_DISPLACEMENT
		float3 normal : NORMAL;
	#endif

	#if VERTEX_COLOR || USE_VERTEX_DISPLACEMENT
		float4 color0 : COLOR0;
	#endif

	#include "skinning-vertex-input.slh"
};

vertex_out
{
	float4 localPos : SV_POSITION;
	float4 projPos : POSITION0;

	#if ALPHA_MASK || MATERIAL_TEXTURE
		float4 texCoord0 : TEXCOORD0;
	#endif

	#if FLOWMAP || VERTEX_COLOR
		float4 texCoord1 : TEXCOORD1;
	#endif
};

#if FLOWMAP
	[material][a] property float flowAnimOffset = 0.0;
	[material][a] property float flowAnimSpeed = 0.0;
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

	#if MATERIAL_TEXTURE
		output.texCoord0.xy = input.texCoord0;

		#if INSTANCED_CHAIN
			output.texCoord0.y = output.texCoord0.y * segPerChunkLength + getTexCoordOffset(instanceId + uint(1));
		#endif

		#if TEXTURE0_ANIMATION_SHIFT
			output.texCoord0.xy += frac(tex0ShiftPerSecond * globalTime);
		#endif

		#if TEXTURE0_SHIFT_ENABLED
			output.texCoord0.xy += texture0Shift;
		#endif
	#endif

	#if ALPHA_MASK
		output.texCoord0.zw = input.texCoord1;
	#endif

	#if FLOWMAP
		float scaledTime = globalTime * flowAnimSpeed;
		float2 flowPhase = frac(float2(scaledTime, scaledTime + 0.5)) - const05List2;
		output.texCoord1.xyz = float3(flowPhase * flowAnimOffset, abs(flowPhase.x) * 2.0);
	#endif

	#if VERTEX_COLOR
		output.texCoord1.w = input.color0.a;
	#endif

	return output;
}
