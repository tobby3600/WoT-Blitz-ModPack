#include "common.slh"

#if LOD_TRANSITION
	#include "lod-transition.slh"
#endif

fragment_in
{
	float4 projPos : POSITION0;

	#if ALPHA_MASK || MATERIAL_TEXTURE
		float4 texCoord0 : TEXCOORD0;
	#endif

	#if FLOWMAP || VERTEX_COLOR
		float4 texCoord1 : TEXCOORD1;
	#endif
};

fragment_out
{
	float4 color : SV_TARGET0;
};

#if ALPHATEST && MATERIAL_TEXTURE
	uniform sampler2D albedo;

	#if ALPHA_MASK
		uniform sampler2D alphamask;
	#endif

	#if PBR_TEXTURE_SET
		uniform sampler2D baseColorMap;
	#elif FLOWMAP
		uniform sampler2D flowmap;
	#endif
#endif

#if ALPHATEST && ALPHATESTVALUE && MATERIAL_TEXTURE
	[material][a] property float alphatestThreshold = 0.0;
#endif

#if LOD_TRANSITION
	[material][a] property float lodTransitionThreshold = 0.0;
#endif

fragment_out fp_main(fragment_in input)
{
	fragment_out output;

	float3 projPos = input.projPos.xyz / input.projPos.w;

	#if ALPHA_MASK || MATERIAL_TEXTURE
		float4 texCoord0 = input.texCoord0;
	#endif

	#if ALPHATEST && MATERIAL_TEXTURE
		#if FLOWMAP
			float2 flowDir = tex2D(flowmap, texCoord0.xy).xy * 2.0 - const1List2;

			output.color.a = lerp(tex2D(albedo, flowDir * input.texCoord1.x + texCoord0.xy).a, tex2D(albedo, flowDir * input.texCoord1.y + texCoord0.xy).a, input.texCoord1.z);
		#elif PBR_TEXTURE_SET
			output.color.a = tex2D(baseColorMap, texCoord0.xy).a;
		#else
			output.color.a = tex2D(albedo, texCoord0.xy).a;
		#endif

		#if ALPHA_MASK
			output.color.a *= tex2D(alphamask, texCoord0.zw).a;
		#endif
	#endif

	#if LOD_TRANSITION
		output.color.a *= getLodTransition(projPos.xy, lodTransitionThreshold);
	#endif

	#if MATERIAL_TEXTURE || LOD_TRANSITION
		#if ALPHATEST
			float alpha = output.color.a;

			#if VERTEX_COLOR
				alpha *= input.texCoord1.w;
			#endif

			#if ALPHATESTVALUE
				if (alpha < alphatestThreshold) discard;
			#else
				if (alpha < 0.5) discard;
			#endif
		#endif
	#endif

	float depthColor = projPos.z * 0.5 + 0.5;
	output.color = float4(depthColor, depthColor, depthColor, depthColor);

	return output;
}
