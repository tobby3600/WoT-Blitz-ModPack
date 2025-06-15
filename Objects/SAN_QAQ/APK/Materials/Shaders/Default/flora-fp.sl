#include "common.slh"
#include "blending.slh"

#ensuredefined FLORA_AMBIENT_ANIMATION 0
#ensuredefined FLORA_EDGE_MAP 0
#ensuredefined FLORA_FAKE_SHADOW 0
#ensuredefined FLORA_LAYING 0
#ensuredefined FLORA_LOD_TRANSITION_FAR 0
#ensuredefined FLORA_LOD_TRANSITION_NEAR 0
#ensuredefined FLORA_NORMAL_MAP 0
#ensuredefined FLORA_PBR_LIGHTING 0
#ensuredefined FLORA_WIND_ANIMATION 0

#define FLORA_ANIMATION (FLORA_AMBIENT_ANIMATION || FLORA_WIND_ANIMATION)
#define FLORA_LOD_TRANSITION (FLORA_LOD_TRANSITION_FAR || FLORA_LOD_TRANSITION_NEAR)

#if !DRAW_DEPTH_ONLY
	#if FLORA_PBR_LIGHTING
		#include "pbr-lighting.slh"
	#endif

	#if RECEIVE_SHADOW
		#include "shadow-mapping.slh"
	#endif
#endif

#if FLORA_LOD_TRANSITION
	#include "lod-transition.slh"
#endif

fragment_in
{
	float3 worldPos : POSITION0;
	float4 projPos : POSITION1;
	float2 texCoord0 : TEXCOORD0;

	#if !DRAW_DEPTH_ONLY
		#if FLORA_LAYING
			float3 texCoord1 : TEXCOORD1; // .z - layingStrength
		#else
			float2 texCoord1 : TEXCOORD1;
		#endif

		#if USE_VERTEX_FOG
			float4 varFog : TEXCOORD2;
		#endif

		#if FLORA_PBR_LIGHTING
			#if !FLORA_NORMAL_MAP
				#if FLORA_ANIMATION && FLORA_FAKE_SHADOW
					float2 animation : TEXCOORD3;
				#endif

				float4 normal : NORMAL; // .w - localHeight
			#else
				float4 tangentToWorld0 : TANGENTTOWORLD0; // .w - localHeight

				#if FLORA_ANIMATION && FLORA_FAKE_SHADOW
					float4 tangentToWorld1 : TANGENTTOWORLD1; // .w - animation.x
					float4 tangentToWorld2 : TANGENTTOWORLD2; // .w - animation.y
				#else
					float3 tangentToWorld1 : TANGENTTOWORLD1;
					float3 tangentToWorld2 : TANGENTTOWORLD2;
				#endif
			#endif
		#endif
	#endif
};

fragment_out
{
	float4 color : SV_TARGET0;
};

#if FLORA_PBR_LIGHTING
	uniform sampler2D baseColorMap;
#else
	uniform sampler2D albedo;
#endif

#if !DRAW_DEPTH_ONLY
	#if FLORA_PBR_LIGHTING
		uniform sampler2D floraLightmap;
		uniform sampler2D floraPbrColorMap;

		#if FLORA_EDGE_MAP
			uniform sampler2D floraEdgeMap;
		#endif

		#if FLORA_FAKE_SHADOW
			uniform sampler2D floraFakeShadow;
		#endif

		#if FLORA_NORMAL_MAP
			uniform sampler2D baseNormalMap; // RG or AG(DXT5NM) or GA(ASTC) - normal
		#endif
	#else
		uniform sampler2D floraColorMap;
	#endif
#endif

[auto][a] property float3 cameraPosition;

#if !DRAW_DEPTH_ONLY && FLORA_PBR_LIGHTING
	[auto][a] property float lightIntensity0;
	[auto][a] property float3 lightColor0;
	[auto][a] property float4 lightPosition0;
	[auto][a] property float4x4 invViewMatrix;

	[material][a] property float2 floraBottomOcclusionShadow;
	[material][a] property float2 floraRoughnessMetallic;
	[material][a] property float3 worldSize;

	#if FLORA_FAKE_SHADOW
		[material][a] property float floraFakeShadowIntensity;
		[material][a] property float2 floraFakeShadowAnimationFactor;
		[material][a] property float4 floraFakeShadowOffsetScale;
	#endif

	#if FLORA_NORMAL_MAP
		[material][a] property float floraNormalMapScale;
	#endif
#endif

#if !DRAW_DEPTH_ONLY && FLORA_LAYING
	#if FLORA_PBR_LIGHTING
		[material][a] property float3 floraLayingPbrColorFactor;
	#else
		[material][a] property float3 floraLayingColorFactor;
	#endif
#endif

#if (ALPHATEST || FLORA_LOD_TRANSITION) && ALPHATESTVALUE
	[material][a] property float alphatestThreshold = 0.0;
#endif

#if FLORA_LOD_TRANSITION_NEAR
	[material][a] property float2 floraLodTransitionNearRange;
#endif

#if FLORA_LOD_TRANSITION_FAR
	[material][a] property float2 floraLodTransitionFarRange;
#endif

fragment_out fp_main(fragment_in input)
{
	fragment_out output;

	float3 worldPos = input.worldPos;
	float3 projPos = input.projPos.xyz / input.projPos.w;

	#if FLORA_PBR_LIGHTING
		float4 baseColor = tex2D(baseColorMap, input.texCoord0);
	#else
		float4 baseColor = tex2D(albedo, input.texCoord0);
	#endif

	#if ALPHATEST || FLORA_LOD_TRANSITION
		#if ALPHATEST
			float alpha = baseColor.a;
		#else
			float alpha = 1.0;
		#endif

		#if FLORA_LOD_TRANSITION
			float toCamDis = length(cameraPosition.xy - worldPos.xy);

			#if FLORA_LOD_TRANSITION_NEAR
				alpha *= getLodTransition(projPos.xy, smoothstep(floraLodTransitionNearRange.x, floraLodTransitionNearRange.y, toCamDis));
			#endif

			#if FLORA_LOD_TRANSITION_FAR
				alpha *= getLodTransition(projPos.xy, smoothstep(floraLodTransitionFarRange.x, floraLodTransitionFarRange.y, toCamDis) - 1.0);
			#endif
		#endif

		#if ALPHATESTVALUE
			if (alpha < alphatestThreshold) discard;
		#else
			if (alpha < 0.5) discard;
		#endif
	#endif

	#if DRAW_DEPTH_ONLY
		float depthColor = projPos.z * 0.5 + 0.5;
		output.color = float4(depthColor, depthColor, depthColor, depthColor);
	#else
		#if FLORA_PBR_LIGHTING
			float4 floraColor = tex2D(floraPbrColorMap, input.texCoord1.xy);
			baseColor.rgb *= floraColor.rgb;
		#else
			float4 floraColor = tex2D(floraColorMap, input.texCoord1.xy);
			baseColor.rgb *= floraColor.rgb * floraColor.a;
		#endif

		#if FLORA_LAYING
			#if FLORA_PBR_LIGHTING;
				float3 layingColorFactor = floraLayingPbrColorFactor;
			#else
				float3 layingColorFactor = floraLayingColorFactor;
			#endif

			baseColor.rgb *= lerp(const1List3, layingColorFactor, input.texCoord1.z);
		#endif

		output.color = baseColor;

		#if RECEIVE_SHADOW
			float3 shadowInf = getShadow(worldPos, projPos.xy, 0.0);
		#endif

		#if FLORA_PBR_LIGHTING
			#if FLORA_NORMAL_MAP
				float3 N = unpackNormal(tex2D(baseNormalMap, input.texCoord0).ga);
				N.xy *= floraNormalMapScale;
				N = normalize(float3(dot(N, input.tangentToWorld0.xyz), dot(N, input.tangentToWorld1.xyz), dot(N, input.tangentToWorld2.xyz)));

				float3 polygonN = normalize(float3(input.tangentToWorld0.z, input.tangentToWorld1.z, input.tangentToWorld2.z));
			#else
				float3 N = normalize(input.normal.xyz);
				float3 polygonN = N;
			#endif

			float3 L = normalize(mul3Fast0(lightPosition0.xyz, invViewMatrix));
			float3 V = normalize(cameraPosition - worldPos);
			float3 H = normalize(L + V);

			float2 worldTexCoord = worldPos.xy / worldSize.xy + const05List2;
			worldTexCoord.y = 1.0 - worldTexCoord.y;

			#if FLORA_EDGE_MAP
				float edgeFactor = tex2D(floraEdgeMap, worldTexCoord).r;
			#endif

			#if FLORA_NORMAL_MAP
				float localHeight = input.tangentToWorld0.w;
			#else
				float localHeight = input.normal.w;
			#endif

			float2 lightmapDirAndAO = tex2D(floraLightmap, worldTexCoord).ga;

			#if FLORA_EDGE_MAP
				float2 occlusionShadow = lerp(floraBottomOcclusionShadow, const1List2, lerp(localHeight, 1.0, edgeFactor));
			#else
				float2 occlusionShadow = lerp(floraBottomOcclusionShadow, const1List2, localHeight);
			#endif

			occlusionShadow.x *= lightmapDirAndAO.y;

			#if RECEIVE_SHADOW
				occlusionShadow.y *= lerp(lightmapDirAndAO.x, shadowInf.z, shadowInf.y);
			#else
				occlusionShadow.y *= lightmapDirAndAO.x;
			#endif

			#if FLORA_FAKE_SHADOW
				float2 fakeShadowTexCoord = input.texCoord0 * floraFakeShadowOffsetScale.zw + floraFakeShadowOffsetScale.xy;

				#if FLORA_ANIMATION
					#if FLORA_NORMAL_MAP
						float2 animation = float2(input.tangentToWorld1.w, input.tangentToWorld2.w);
					#else
						float2 animation = input.animation;
					#endif

					fakeShadowTexCoord += animation * (floraFakeShadowAnimationFactor * localHeight);
				#endif

				float fakeShadow = floraFakeShadowIntensity;

				#if FLORA_EDGE_MAP
					fakeShadow -= fakeShadow * edgeFactor;
				#endif

				#if FLORA_LAYING
					fakeShadow -= fakeShadow * input.texCoord1.z;
				#endif

				occlusionShadow.y *= lerp(1.0, tex2D(floraFakeShadow, fakeShadowTexCoord).r, fakeShadow);
			#endif

			baseColor.rgb = saturate(baseColor.rgb);
			float roughness = saturate(floraRoughnessMetallic.x);
			occlusionShadow.x = saturate(occlusionShadow.x);

			output.color.rgb = getPBR(polygonN, N, L, V, H, lightColor0 * lightIntensity0, baseColor.rgb, floraRoughnessMetallic.y, roughness, occlusionShadow.x, occlusionShadow.y, const0List3);
			output.color.rgb = toSRGB(output.color.rgb);
		#elif RECEIVE_SHADOW
			output.color.rgb *= lerp(shadowMapShadowColor.rgb, const1List3, shadowInf.x);
		#endif

		#if USE_VERTEX_FOG
			output.color.rgb = lerp(output.color.rgb, input.varFog.rgb, input.varFog.a);
		#endif

		#include "color-grading.slh"
	#endif

	return output;
}
