#include "common.slh"

#ensuredefined WATER_DEFORMATION 0

#if PIXEL_LIT && REAL_REFLECTION && RETRIEVE_FRAG_DEPTH_AVAILABLE
	#include "depth-fetch.slh"
#endif

#if RECEIVE_SHADOW
	#include "shadow-mapping.slh"
#endif

#if SPECULAR
	#include "lighting.slh"
#endif

#if FRESNEL_TO_ALPHA
	blending { src=src_alpha dst=inv_src_alpha }
#endif

fragment_in
{
	float4 projPos : POSITION0;

	#if !DRAW_DEPTH_ONLY
		#if WATER_DEFORMATION
			float4 worldPos : POSITION1;
		#else
			float3 worldPos : POSITION1;
		#endif

		float4 texCoord : TEXCOORD0;

		#if PIXEL_LIT
			float3 toLightDir : TEXCOORD1;
			float3 toCamDir : TEXCOORD2;

			#if REAL_REFLECTION
				float4 reflectionPos : POSITION2;
			#else
				float3 tangentToWorld0 : TANGENTTOWORLD0;
				float3 tangentToWorld1 : TANGENTTOWORLD1;
				float3 tangentToWorld2 : TANGENTTOWORLD2;
			#endif
		#else
			float2 decalTexCoord : TEXCOORD1;
			float3 reflectionTexCoord : TEXCOORD2;
		#endif
	#endif

	#if USE_VERTEX_FOG
		float4 varFog : TEXCOORD3;
	#endif
};

fragment_out
{
	float4 color : SV_TARGET0;
};

#if !DRAW_DEPTH_ONLY
	#if PIXEL_LIT
		uniform sampler2D normalmap;

		#if REAL_REFLECTION
			uniform sampler2D dynamicReflection;
		#endif
	#else
		uniform sampler2D albedo;
		uniform sampler2D decal;
	#endif

	#if !REAL_REFLECTION
		uniform samplerCUBE cubemap;
	#endif

	#if PIXEL_LIT
		[auto][a] property float3 cameraPosition;
		[auto][a] property float4 lightPosition0;
		[auto][a] property float4x4 invViewMatrix;

		#if SPECULAR
			[auto][a] property float3 lightColor0;
		#endif

		[material][a] property float fresnelBias = 0.0;
		[material][a] property float fresnelPow = 0.0;
		[material][a] property float3 reflectionTintColor = const1List3;

		#if REAL_REFLECTION
			[material][a] property float distortionFallSquareDist = 1.0;
			[material][a] property float reflectionDistortion = 0.0;

			#if SPECULAR
				[material][a] property float inGlossiness = 0.5;
				[material][a] property float inSpecularity = 0.5;
			#endif
		#endif

		#if RECEIVE_SHADOW
			[material][a] property float3 pixelLitShadowColor = const05List3;
		#endif
	#else
		[material][a] property float3 decalTintColor = const0List3;
		[material][a] property float3 reflectanceColor = float3(0.5, 0.25, 0.75);
	#endif

	#if WATER_DEFORMATION
		[material][a] property float4 foamColor = const1List4;
	#endif
#endif

fragment_out fp_main(fragment_in input)
{
	fragment_out output;

	float3 projPos = input.projPos.xyz / input.projPos.w;

	#if DRAW_DEPTH_ONLY
		float depthColor = projPos.z * 0.5 + 0.5;
		output.color = float4(depthColor, depthColor, depthColor, depthColor);
	#else
		float coastLine = 1.0;
		float fresnel = 1.0;
		float3 worldPos = input.worldPos.xyz;

		#if WATER_DEFORMATION
			float foamFactor = input.worldPos.w * foamColor.a;
		#endif

		#if PIXEL_LIT
			float3 base = tex2D(normalmap, input.texCoord.xy).rgb * 2.0 - float3(const1List2, 0.0);
			float3 detail = tex2D(normalmap, input.texCoord.zw).rgb * float3(-const2List2, 2.0) + float3(const1List2, -1.0);
			float3 N = base * dot(base.xy, detail.xy) + (base * detail.z - detail);

			#include "vector-compute.slh"

			fresnel = lerp(fresnelBias, 1.0, pow(1.0 - saturate(NdotV), fresnelPow));

			#if WATER_DEFORMATION
				fresnel = lerp(fresnel, 1.0, foamFactor);
			#endif

			#if REAL_REFLECTION
				float2 waveOffset = N.xy * max(distortionFallSquareDist * input.reflectionPos.w + 1.0, 0.1);

				#if RETRIEVE_FRAG_DEPTH_AVAILABLE
					#include "depth-diff.slh"

					float distanceDifference = depthPosition.x / max(depthPosition.y, 0.0001) - depthPosition.z / max(depthPosition.w, 0.0001);
					coastLine = saturate(saturate(abs(distanceDifference * 2.0) / projPos.z) * (-length(waveOffset) * 2.5 + 1.5));
					fresnel *= coastLine;
					waveOffset *= coastLine;
				#endif

				float derivativeScale = 2.0 - abs(V.z);
				float2 reflectionTexCoord = waveOffset * reflectionDistortion + (input.reflectionPos.xy / input.reflectionPos.z * 0.5 + const05List2);
				float2 ddxUV = ddx(reflectionTexCoord) * derivativeScale;
				float2 ddyUV = ddy(reflectionTexCoord) * derivativeScale;
				float3 reflectionColor = tex2Dlod(dynamicReflection, reflectionTexCoord, max(log2(max(length(ddxUV), length(ddyUV))), log2(max(abs(ddxUV.x * ddyUV.y - ddxUV.y * ddyUV.x), 0.00000001)) * 0.5)).rgb;
				output.color.rgb = reflectionColor * reflectionTintColor;

				#if SPECULAR
					reflectionColor *= lightColor0;
					output.color.rgb += reflectionColor * (NdotL * _INVERSE_PI);
					output.color.rgb += reflectionColor * (getBlinnPhongSpecular(NdotH, inGlossiness) * inSpecularity * fresnel);
				#endif
			#else
				R.z = abs(R.z);
				output.color.rgb += texCUBE(cubemap, float3(dot(R, input.tangentToWorld0), dot(R, input.tangentToWorld1), dot(R, input.tangentToWorld2))).rgb * reflectionTintColor;
			#endif
		#else
			output.color.rgb = (tex2D(albedo, input.texCoord.xy).rgb * tex2D(albedo, input.texCoord.zw).rgb) * (tex2D(decal, input.decalTexCoord).rgb * decalTintColor) * 3.0;
			output.color.rgb += texCUBE(cubemap, input.reflectionTexCoord).rgb * reflectanceColor;
		#endif

		output.color.a = fresnel;

		#if WATER_DEFORMATION
			output.color.rgb = lerp(output.color.rgb, foamColor.rgb, foamFactor);
		#endif

		#if RECEIVE_SHADOW
			float3 shadowInf = getShadow(worldPos, projPos.xy, 0.0);

			#if PIXEL_LIT
				output.color.rgb *= lerp(pixelLitShadowColor, const1List3, shadowInf.x);
			#else
				output.color.rgb *= lerp(shadowMapShadowColor.rgb, const1List3, shadowInf.x);
			#endif
		#endif

		#if USE_VERTEX_FOG
			output.color.rgb = lerp(output.color.rgb, input.varFog.rgb, input.varFog.a * coastLine);
		#endif
	#endif

	return output;
}

