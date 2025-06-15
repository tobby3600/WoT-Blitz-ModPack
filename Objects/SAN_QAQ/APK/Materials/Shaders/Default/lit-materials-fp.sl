#include "common.slh"
#include "blending.slh"
#include "highlight-animation.slh"
#include "lighting.slh"

#if LOD_TRANSITION
	#include "lod-transition.slh"
#endif

#if RECEIVE_SHADOW
	#include "shadow-mapping.slh"
#endif

#if TILED_DECAL_MASK && TILED_DECAL_SPREADING
	#include "decal-spreading.slh"
#endif

fragment_in
{
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

fragment_out
{
	float4 color : SV_TARGET0;
};

#if ALPHA_MASK
	uniform sampler2D alphamask;
#endif

#if MATERIAL_DETAIL
	uniform sampler2D detail;
#endif

#if MATERIAL_TEXTURE
	uniform sampler2D albedo;
#endif

#if PIXEL_LIT
	uniform sampler2D normalmap;
#endif

#if TILED_DECAL_MASK
	uniform sampler2D decalmask;
	uniform sampler2D decaltexture;

	#if HARD_SKINNING
		uniform sampler2D decalTexture1;
		uniform sampler2D decalTexture2;
		uniform sampler2D decalTexture3;
	#endif
#endif

#if ENVIRONMENT_MAPPING
	uniform samplerCUBE cubemap;
#endif

[auto][a] property float3 lightColor0;

#if VIEW_AMBIENT
	[auto][a] property float3 lightAmbientColor0;
#endif

#if PIXEL_LIT
	[auto][a] property float4x4 invViewMatrix;
	[auto][a] property float4x4 pointLights; // 0,1:(position, radius); 2,3:(color, unused)

	[material][a] property float inSpecularity = 1.0;
	[material][a] property float normalScale = 1.0;
	[material][a] property float3 metalFresnelReflectance = float3(0.562, 0.565, 0.578);
#endif

#if LOD_TRANSITION || MATERIAL_TEXTURE
	#if ALPHABLEND && ALPHASTEPVALUE
		[material][a] property float alphaStepValue = 0.5;
	#endif

	#if ALPHATEST && ALPHATESTVALUE
		[material][a] property float alphatestThreshold = 0.0;
	#endif
#endif

#if BLEND_WITH_CONST_ALPHA
	[material][a] property float flatAlpha = 1.0;
#endif

#if ENVIRONMENT_MAPPING
	[material][a] property float3 cubemapIntensity = const1List3;
#endif

#if FLATCOLOR || FLATALBEDO
	[material][a] property float4 flatColor = const1List4;
#endif

#if LOD_TRANSITION
	[material][a] property float lodTransitionThreshold = 0.0;
#endif

#if NORMALIZED_BLINN_PHONG && VIEW_SPECULAR
	[material][a] property float inGlossiness = 0.5;
#endif

#if TILED_DECAL_MASK
	[material][a] property float4 decalTileColor = const1List4;

	#if HARD_SKINNING
		[material][a] property float4 decalTileColor1 = const1List4;
		[material][a] property float4 decalTileColor2 = const1List4;
		[material][a] property float4 decalTileColor3 = const1List4;
	#endif
#endif

fragment_out fp_main(fragment_in input)
{
	fragment_out output;

	float2 projPos = input.projPos.xy / input.projPos.w;

	#if MATERIAL_TEXTURE || PIXEL_LIT || TILED_DECAL_MASK
		float4 texCoord0 = input.texCoord0;
	#endif

	float4 outColor = const1List4;
	output.color = const0List4;

	#if MATERIAL_TEXTURE
		outColor = tex2D(albedo, texCoord0.xy);

		#if TEST_OCCLUSION
			outColor.rgb *= outColor.a;
		#endif

		#if ALPHA_MASK
			outColor.a *= tex2D(alphamask, input.texCoord1.xy).a;
		#endif
	#endif

	#if FLATALBEDO
		outColor *= flatColor;
	#endif

	#if LOD_TRANSITION
		outColor.a *= getLodTransition(projPos, lodTransitionThreshold);
	#endif

	#if LOD_TRANSITION || MATERIAL_TEXTURE
		#if ALPHATEST
			float alpha = outColor.a;

			#if VERTEX_COLOR
				alpha *= input.vertexColor.a;
			#endif

			#if ALPHATESTVALUE
				if (alpha < alphatestThreshold) discard;
			#else
				if (alpha < 0.5) discard;
			#endif
		#endif

		#if ALPHABLEND && ALPHASTEPVALUE
			outColor.a = step(alphaStepValue, outColor.a);
		#endif
	#endif

	#if PIXEL_LIT
		float3 N = tex2D(normalmap, texCoord0.xy).rgb * 2.0 - const1List3;

		#if RECEIVE_SHADOW
			float3 NShady = N;
			NShady.xy *= shadowLitNormalScale;
			NShady = normalize(NShady);
		#endif

		N.xy *= normalScale;
		N = normalize(N);

		#include "vector-compute.slh"

		float3 diffuse = lightColor0 * (NdotL * _INVERSE_PI);
		float3 specular = const0List3;

		float3x3 tangentToViewMatrix = float3x3(input.tangentToView0.xyz, input.tangentToView1.xyz, input.tangentToView2.xyz);

		#if NORMALIZED_BLINN_PHONG
			#if MAX_POINT_LIGHTS > 0
				float3 viewNormal = float3(dot(N, tangentToViewMatrix[0]), dot(N, tangentToViewMatrix[1]), dot(N, tangentToViewMatrix[2]));
				float3 viewPosition = float3(input.tangentToView0.w, input.tangentToView1.w, input.tangentToView2.w);

				diffuse += getBlinnPhongPointLight(pointLights[0].w, pointLights[2], pointLights[0].xyz + viewPosition, viewNormal);
			#endif

			#if MAX_POINT_LIGHTS > 1
				diffuse += getBlinnPhongPointLight(pointLights[1].w, pointLights[3], pointLights[1].xyz + viewPosition, viewNormal);
			#endif

			#if VIEW_SPECULAR
				specular += lightColor0 * (getBlinnPhongSpecular(NdotH, inGlossiness * outColor.a) * inSpecularity * NdotL);

				#if ENVIRONMENT_MAPPING
					#if ENVIRONMENT_MAPPING_NORMALMAP
						float3 envTexCoord = mul3Fast0(float3(dot(R, tangentToViewMatrix[0]), dot(R, tangentToViewMatrix[1]), dot(R, tangentToViewMatrix[2])), invViewMatrix);
					#else
						float3 envTexCoord = input.texCoord2.xyz;
					#endif

					specular += texCUBE(cubemap, envTexCoord).rgb * cubemapIntensity * outColor.a;
				#endif

				specular *= lerp(metalFresnelReflectance, const1List3, pow5Exp(NdotV));
			#endif
		#endif

		#if RECEIVE_SHADOW
			float slope = 1.0 - saturate(dot(NShady, L));
			float3 shadowInf = getShadow(float3(dot(input.tangentToWorld0.xyz, NShady), dot(input.tangentToWorld1.xyz, NShady), dot(input.tangentToWorld2.xyz, NShady)) * (shadowNormalSlopeOffset * slope) + float3(input.tangentToWorld0.w, input.tangentToWorld1.w, input.tangentToWorld2.w), projPos, slope);

			#if VIEW_DIFFUSE
				diffuse *= (-shadowLitDiffuseSpecAmbientMult.x * shadowInf.x) + (shadowLitDiffuseSpecAmbientMult.x + shadowInf.x);
			#endif

			#if VIEW_SPECULAR
				specular *= (-shadowLitDiffuseSpecAmbientMult.y * shadowInf.x) + (shadowLitDiffuseSpecAmbientMult.y + shadowInf.x);
			#endif
		#endif

		#if VIEW_AMBIENT
			#if RECEIVE_SHADOW
				output.color.rgb += lightAmbientColor0 * saturate(lerp(shadowMapShadowColor.rgb, const1List3, shadowInf.x) * shadowLitDiffuseSpecAmbientMult.z);
			#else
				output.color.rgb += lightAmbientColor0;
			#endif
		#endif

		#if VIEW_DIFFUSE
			output.color.rgb += diffuse;
		#endif

		#if VIEW_SPECULAR
			output.color.rgb += specular;
		#endif

		#if VIEW_ALBEDO
			#include "emission.slh"
		#endif

		#if VIEW_ALBEDO && !VIEW_AMBIENT && !VIEW_DIFFUSE && !VIEW_SPECULAR
			output.color.rgb = outColor.rgb;
		#endif
	#else
		#if RECEIVE_SHADOW
			float3 shadowInf = getShadow(input.worldNormalSlope.xyz * (shadowNormalSlopeOffset * input.worldNormalSlope.w) + input.worldPos, projPos, input.worldNormalSlope.w);
			float3 shadowColor = lerp(shadowMapShadowColor.rgb, const1List3, shadowInf.x);
		#endif

		#if SIMPLE_BLINN_PHONG || NORMALIZED_BLINN_PHONG
			#if VIEW_AMBIENT
				#if RECEIVE_SHADOW
					output.color.rgb += lightAmbientColor0 * saturate(shadowColor * shadowLitDiffuseSpecAmbientMult.z);
				#else
					output.color.rgb += lightAmbientColor0;
				#endif
			#endif

			#if VIEW_DIFFUSE
				#if SIMPLE_BLINN_PHONG
					output.color.rgb += input.diffuseSpecularVector.rgb;
				#elif NORMALIZED_BLINN_PHONG
					output.color.rgb += input.diffuseVector;
				#endif
			#endif

			#if VIEW_ALBEDO
				#include "emission.slh"
			#endif
		#endif

		#if VIEW_SPECULAR
			#if SIMPLE_BLINN_PHONG
				output.color.rgb += lightColor0 * (input.diffuseSpecularVector.a * outColor.a);
			#elif NORMALIZED_BLINN_PHONG
				output.color.rgb += lightColor0 * input.specularVector.rgb * getBlinnPhongSpecular(input.specularVector.a, inGlossiness * outColor.a);
			#endif
		#endif

		#if RECEIVE_SHADOW
			output.color.rgb *= shadowColor;
		#endif

		#if VIEW_ALBEDO && !VIEW_AMBIENT && !VIEW_DIFFUSE && !VIEW_SPECULAR
			output.color.rgb = outColor.rgb;
		#endif
	#endif

	#if MATERIAL_DETAIL
		output.color.rgb *= tex2D(detail, input.texCoord1.zw).rgb * 2.0;
	#endif

	#if ALPHABLEND && MATERIAL_TEXTURE
		output.color.a = outColor.a;
	#else
		output.color.a = 1.0;
	#endif

	#if VERTEX_COLOR
		output.color *= input.vertexColor;
	#endif

	#if FLATCOLOR
		output.color *= flatColor;
	#endif

	#if BLEND_WITH_CONST_ALPHA
		output.color.a = flatAlpha;
	#endif

	#if HIGHLIGHT_COLOR || HIGHLIGHT_WAVE_ANIM
		output.color = getHighlightAnim(output.color, input.displacePos.w);
	#endif

	#if USE_VERTEX_FOG
		output.color.rgb = lerp(output.color.rgb, input.varFog.rgb, input.varFog.a);
	#endif

	#include "color-grading.slh"

	return output;
}
