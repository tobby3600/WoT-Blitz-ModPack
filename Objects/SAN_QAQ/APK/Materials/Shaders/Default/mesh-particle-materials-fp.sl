#define SHADOW_RECEIVER 1

#include "common.slh"
#include "blending.slh"

#if RECEIVE_SHADOW
	#include "shadow-mapping.slh"
#endif

#if RETRIEVE_FRAG_DEPTH_AVAILABLE && SOFT_PARTICLES
	#include "depth-fetch.slh"
#endif

fragment_in
{
	#if RECEIVE_SHADOW || (RETRIEVE_FRAG_DEPTH_AVAILABLE && SOFT_PARTICLES)
		float4 projPos : POSITION0;
	#endif

	#if RECEIVE_SHADOW
		float3 worldPos : POSITION1;
		float4 worldNormalSlope : POSITION2;
	#endif

	float4 vertexColor : COLOR0;

	#if PARTICLES_MASK
		float4 texCoord0 : TEXCOORD0;
	#else
		float2 texCoord0 : TEXCOORD0;
	#endif

	#if FRAME_BLEND || PARTICLES_FLOWMAP
		float4 texCoord1 : TEXCOORD1;
	#endif

	#if PARTICLES_FLOWMAP
		float4 texCoord2 : TEXCOORD2;
	#endif

	#if PARTICLES_NOISE
		#if PARTICLES_FRESNEL_TO_ALPHA
			float4 texCoord3 : TEXCOORD3; // xy - noise uv, z - noise scale, w - fresnel.
		#else
			float3 texCoord3 : TEXCOORD3; // xy - noise uv, z - noise scale.
		#endif
	#elif PARTICLES_FRESNEL_TO_ALPHA
		float texCoord3 : TEXCOORD3; // Fresnel.
	#endif

	#if USE_VERTEX_FOG
		float4 varFog : TEXCOORD4;
	#endif
};

fragment_out
{
	float4 color : SV_TARGET0;
};

uniform sampler2D albedo;

#if PARTICLES_FLOWMAP
	uniform sampler2D flowmap;
#endif

#if PARTICLES_MASK
	uniform sampler2D mask;
#endif

#if PARTICLES_NOISE
	uniform sampler2D noiseTex;
#endif

#if ALPHABLEND
	#if ALPHA_EROSION
		[material][a] property float alphaErosionAcceleration = 2.0;
	#endif

	#if ALPHASTEPVALUE
		[material][a] property float alphaStepValue = 0.5;
	#endif
#endif

#if ALPHATEST && ALPHATESTVALUE
	[material][a] property float alphatestThreshold = 0.0;
#endif

#if FLATCOLOR || FLATALBEDO
	[material][a] property float4 flatColor = const1List4;
#endif

#if RETRIEVE_FRAG_DEPTH_AVAILABLE && SOFT_PARTICLES
	[material][a] property float depthDifferenceSlope = 2.0;
#endif

fragment_out fp_main(fragment_in input)
{
	fragment_out output;

	float4 textureColor0 = const1List4;

	#if RECEIVE_SHADOW || (RETRIEVE_FRAG_DEPTH_AVAILABLE && SOFT_PARTICLES)
		float3 projPos = input.projPos.xyz / input.projPos.w;
	#endif

	#if PARTICLES_FLOWMAP
		float2 flowDir = tex2D(flowmap, input.texCoord2.xy).xy * 2.0 - const1List2;
	#endif

	#if ALPHATEST || ALPHABLEND
		#if PARTICLES_FLOWMAP
			#if PARTICLES_NOISE
				flowDir *= tex2D(noiseTex, input.texCoord3.xy).r * input.texCoord3.z;
			#endif

			textureColor0 = lerp(tex2D(albedo, flowDir * input.texCoord2.z + input.texCoord0.xy), tex2D(albedo, flowDir * input.texCoord2.w + input.texCoord0.xy), input.texCoord1.w);
		#else
			float2 albedoTexCoord = input.texCoord0.xy;

			#if PARTICLES_NOISE
				float2 noiseSample = tex2D(noiseTex, input.texCoord3.xy).rr * 2.0 - const1List2;

				albedoTexCoord += noiseSample * input.texCoord3.z;
			#endif

			textureColor0 = tex2D(albedo, albedoTexCoord);
		#endif
	#else
		#if PARTICLES_FLOWMAP
			textureColor0.rgb = lerp(tex2D(albedo, flowDir * input.texCoord2.z + input.texCoord0.xy).rgb, tex2D(albedo, flowDir * input.texCoord2.w + input.texCoord0.xy).rgb, input.texCoord1.w);
		#else
			float4 albedoSample = tex2D(albedo, input.texCoord0.xy);
			textureColor0.rgb = albedoSample.rgb;

			#if TEST_OCCLUSION
				textureColor0.rgb *= albedoSample.a;
			#endif
		#endif
	#endif

	#if FRAME_BLEND
		textureColor0 = lerp(textureColor0, tex2D(albedo, input.texCoord1.xy), input.texCoord1.z);
	#endif

	#if FLATALBEDO
		textureColor0 *= flatColor;
	#endif

	#if ALPHATEST
		float alpha = textureColor0.a * input.vertexColor.a;

		#if ALPHATESTVALUE
			if (alpha < alphatestThreshold) discard;
		#else
			if (alpha < 0.5) discard;
		#endif
	#endif

	#if ALPHABLEND
		#if ALPHASTEPVALUE
			textureColor0.a = step(alphaStepValue, textureColor0.a);
		#endif
	#else
		textureColor0.a = 1.0;
	#endif

	output.color = textureColor0 * input.vertexColor;

	#if FLATCOLOR
		output.color *= flatColor;
	#endif

	#if PARTICLES_MASK
		output.color *= tex2D(mask, input.texCoord0.zw);
	#endif

	#if ALPHABLEND && ALPHA_EROSION
		float srcA = tex2D(albedo, input.texCoord0.xy).a;
		float opacity = saturate(1.0 - input.vertexColor.a);
		output.color.a = (srcA * alphaErosionAcceleration - alphaErosionAcceleration) * opacity + (srcA - opacity);
	#endif

	#if PARTICLES_FRESNEL_TO_ALPHA
		#if PARTICLES_NOISE
			output.color.a *= input.texCoord3.w;
		#else
			output.color.a *= input.texCoord3;
		#endif
	#endif

	#if RECEIVE_SHADOW
		float3 shadowInf = getShadow(input.worldNormalSlope.xyz * (shadowNormalSlopeOffset * input.worldNormalSlope.w) + input.worldPos, projPos.xy, input.worldNormalSlope.w);
		output.color.rgb *= lerp(shadowMapShadowColor.rgb, const1List3, shadowInf.x);
	#endif

	#if USE_VERTEX_FOG
		output.color.rgb = lerp(output.color.rgb, input.varFog.rgb, input.varFog.a);
	#endif

	#if RETRIEVE_FRAG_DEPTH_AVAILABLE && SOFT_PARTICLES
		#include "depth-diff.slh"

		float distanceDifference = max(depthPosition.x / max(depthPosition.y, 0.0001) - depthPosition.z / max(depthPosition.w, 0.0001), 0.0);
		float scale = exp2((-distanceDifference * distanceDifference) * (depthDifferenceSlope * _LOG2_E));

		#if BLENDING == BLENDING_ADDITIVE
			output.color -= output.color * scale;
		#else
			output.color.a -= output.color.a * scale;
		#endif
	#endif

	#include "color-grading.slh"

	return output;
}
