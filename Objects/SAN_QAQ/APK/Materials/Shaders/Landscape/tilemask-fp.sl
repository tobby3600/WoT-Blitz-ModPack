#include "common.slh"

#if LANDSCAPE_PBR
	#include "pbr-lighting.slh"
#endif

#if RECEIVE_SHADOW
	#include "shadow-mapping.slh"
#endif

#define USE_LANDSCAPE_SCALED_TILES_NON_PBR (LANDSCAPE_SCALED_TILES_NON_PBR && LANDSCAPE_HEIGHT_BLEND_ALLOWED)

fragment_in
{
	float4 projPos : POSITION0;

	#if !DRAW_DEPTH_ONLY
		#if LANDSCAPE_PBR || RECEIVE_SHADOW
			float3 worldPos : POSITION1;
		#endif

		#if LANDSCAPE_MORPHING_COLOR
			float4 morphColor : COLOR0;
		#endif

		float4 texCoord : TEXCOORD0;
	#endif

	#if USE_VERTEX_FOG
		float4 varFog : TEXCOORD1;
	#endif
};

fragment_out
{
	float4 color : SV_TARGET0;
};

#if (LANDSCAPE_HEIGHT_BLEND_ALLOWED && LANDSCAPE_HEIGHT_BLEND) || LANDSCAPE_PBR
	uniform sampler2D tileMaskHeightBlend;

	#if !LANDSCAPE_PBR
		uniform sampler2D tileHeightTexture;
	#endif
#else
	uniform sampler2D tileMask;
#endif

#if LANDSCAPE_PBR
	uniform sampler2D pbrAlbedoRoughnessMap; // RGB - global Albedo attenuation, A - global Roughness attenuation
	uniform sampler2D pbrLandscapeNormalMap; // RG or AG(DXT5NM) or GA(ASTC) - global Normal
	uniform sampler2D pbrLandscapeLightmap; // RG or AG(DXT5NM) or GA(ASTC) - baked shadow / baked AO
	uniform sampler2DArray tileAlbedoHeightArray; // RGB - Albedo, A - Height for heightblending
	uniform sampler2DArray tileNormalArray; // RG or AG(DXT5NM) or GA(ASTC) - normal
	uniform sampler2DArray tileRoughnessAOArray; // RG or AG(DXT5NM) or GA(ASTC) - roughness / AO

	[auto][a] property float lightIntensity0;
	[auto][a] property float3 cameraPosition;
	[auto][a] property float3 lightColor0;
	[auto][a] property float4 lightPosition0;
	[auto][a] property float4x4 invViewMatrix;
#else
	uniform sampler2D tileTexture0;
	uniform sampler2D colorTexture;

	[material][instance] property float3 tileColor0 = const1List3;
	[material][instance] property float3 tileColor1 = const1List3;
	[material][instance] property float3 tileColor2 = const1List3;
	[material][instance] property float3 tileColor3 = const1List3;
#endif

#if LANDSCAPE_USE_RELAXMAP
	uniform sampler2D relaxmap;

	[material][instance] property float relaxmapScale = 1.0;
#endif

#if LANDSCAPE_PBR || USE_LANDSCAPE_SCALED_TILES_NON_PBR
	[material][instance] property float tileScale0 = 1.0;
	[material][instance] property float tileScale1 = 1.0;
	[material][instance] property float tileScale2 = 1.0;
	[material][instance] property float tileScale3 = 1.0;
#endif

#if (LANDSCAPE_HEIGHT_BLEND_ALLOWED && LANDSCAPE_HEIGHT_BLEND) || LANDSCAPE_PBR
	[material][instance] property float tilemaskWeight = 0.15;
	[material][instance] property float4 heightMapScaleColor;
	[material][instance] property float4 heightMapOffsetColor;
	[material][instance] property float4 heightMapSoftnessColor;
#endif

#if CURSOR
	uniform sampler2D cursorTexture;

	[material][instance] property float4 cursorCoordSize = float4(const0List2, const1List2);
#endif

#if LANDSCAPE_HEIGHT_BLEND_ALLOWED && LANDSCAPE_HEIGHT_BLEND
	inline float3 getHeightBlend(float3 input1, float3 input2, float3 input3, float3 input4, float4 height)
	{
		float heightMax = max(max(max(height.x, height.y), height.z), height.w);
		float4 a = max(height + heightMapSoftnessColor - float4(heightMax, heightMax, heightMax, heightMax), constBiasList4);
		float4 b = a / dot(a, const1List4);

		return (input1 * b.x + input2 * b.y) + (input3 * b.z + input4 * b.w);
	}
#endif

#if LANDSCAPE_PBR
	inline float4 getPBRHeightBlend(float4 height)
	{
		float heightMax = max(max(max(height.x, height.y), height.z), height.w);
		float4 a = max(height + heightMapSoftnessColor - float4(heightMax, heightMax, heightMax, heightMax), const0List4);

		return a / dot(a, const1List4);
	}
#endif

fragment_out fp_main(fragment_in input)
{
	fragment_out output;

	float3 projPos = input.projPos.xyz / input.projPos.w;

	#if DRAW_DEPTH_ONLY
		float depthColor = projPos.z * 0.5 + 0.5;
		output.color = float4(depthColor, depthColor, depthColor, depthColor);
	#else
		float4 texCoord = input.texCoord;

		#if LANDSCAPE_PBR || RECEIVE_SHADOW
			float3 worldPos = input.worldPos;
		#endif

		output.color = const1List4;

		#if LANDSCAPE_RELAXMAP && LANDSCAPE_USE_RELAXMAP
			texCoord.zw *= tex2D(relaxmap, texCoord.xy).xy / relaxmapScale - (const05List2 / relaxmapScale - texCoord.xy);
		#endif

		#if LANDSCAPE_PBR || USE_LANDSCAPE_SCALED_TILES_NON_PBR
			float2 texCoords[4];
			texCoords[0] = texCoord.zw * tileScale0;
			texCoords[1] = texCoord.zw * tileScale1;
			texCoords[2] = texCoord.zw * tileScale2;
			texCoords[3] = texCoord.zw * tileScale3;
		#endif

		#if (LANDSCAPE_HEIGHT_BLEND_ALLOWED && LANDSCAPE_HEIGHT_BLEND) || LANDSCAPE_PBR
			float4 mask = tex2D(tileMaskHeightBlend, texCoord.xy);
		#else
			float4 mask = tex2D(tileMask, texCoord.xy);
		#endif

		#if LANDSCAPE_PBR
			float2 bakedAO = tex2D(pbrLandscapeLightmap, texCoord.xy).ga;
			float4 bakedAlbedoRoughness = tex2D(pbrAlbedoRoughnessMap, texCoord.xy) * 2.0;
			float4 albedoHeight[4];
			float4 misc[4];

			[unroll]
			for (int i = 0; i < 4; i++)
			{
				albedoHeight[i] = tex2Darray(tileAlbedoHeightArray, texCoords[i], i);
				misc[i].xy = tex2Darray(tileNormalArray, texCoords[i], i).ga;
				misc[i].zw = tex2Darray(tileRoughnessAOArray, texCoords[i], i).ga;
			}

			float4 legacyHeight = saturate(tilemaskWeight * (mask * 2.0 - 1.0) + (heightMapScaleColor * dot(float4(albedoHeight[0].w, albedoHeight[1].w, albedoHeight[2].w, albedoHeight[3].w), const1List4) * 0.25 + heightMapOffsetColor));
			float4 blendFactor = getPBRHeightBlend(legacyHeight);
			float4 blendedAlbedoHeight = blendFactor.x * albedoHeight[0] + blendFactor.y * albedoHeight[1] + blendFactor.z * albedoHeight[2] + blendFactor.w * albedoHeight[3];
			float4 blendedMisc = blendFactor.x * misc[0] + blendFactor.y * misc[1] + blendFactor.z * misc[2] + blendFactor.w * misc[3];
			float3 baseColor = saturate(blendedAlbedoHeight.rgb * bakedAlbedoRoughness.rgb);
			float roughness = saturate(blendedMisc.b * bakedAlbedoRoughness.a);
			float occlusion = saturate(blendedMisc.a * bakedAO.g);

			float3 N = blendNormal(unpackNormal(tex2D(pbrLandscapeNormalMap, float2(texCoord.x, 1.0 - texCoord.y)).ga), unpackNormal(blendedMisc.rg));
			float3 L = normalize(mul(float4(lightPosition0.xyz, 0.0), invViewMatrix).xyz);
			float3 V = normalize(cameraPosition - worldPos);
			float3 H = normalize(L + V);

			#if RECEIVE_SHADOW
				float slope = 1.0 - saturate(dot(N, L));
				float3 shadowInf = getShadow(N * (shadowNormalSlopeOffset * slope) + worldPos, projPos.xy, slope);
				float shadow = lerp(bakedAO.r, shadowInf.z, shadowInf.y);
			#else
				float shadow = bakedAO.r;
			#endif

			output.color.rgb = getPBR(N, L, V, H, lightColor0 * lightIntensity0, baseColor, 0.0, roughness, occlusion, shadow, const0List3);
			output.color.rgb = toSRGB(output.color.rgb);
		#else
			float4 colorMap = tex2D(colorTexture, texCoord.xy);

			#if LANDSCAPE_SEPARATE_LIGHTMAP_CHANNEL
				colorMap.rgb *= colorMap.a;
			#endif

			#if RECEIVE_SHADOW
				float3 shadowInf = getShadow(worldPos, projPos.xy, 0.0);

				#if LANDSCAPE_SEPARATE_LIGHTMAP_CHANNEL
					float3 shadowColor = lerp(shadowMapShadowColor.rgb * lerp(shadowLMGateFactor.w, 1.0, saturate(colorMap.a * shadowLMGateFactor.z)), const1List3, shadowInf.x) * colorMap.rgb;
				#else
					float3 shadowColor = lerp(colorMap.rgb, lerp(shadowMapShadowColor.rgb, const1List3, shadowInf.x) * lerp(colorMap.rgb * shadowLMGateFactor.w, colorMap.rgb, saturate(dot(colorMap.rgb, rgbMixList) * shadowLMGateFactor.z)), shadowInf.y);
				#endif
			#else
				float3 shadowColor = colorMap.rgb;
			#endif

			#if USE_LANDSCAPE_SCALED_TILES_NON_PBR
				float4 tile = float4(tex2D(tileTexture0, texCoords[0]).r, tex2D(tileTexture0, texCoords[1]).g, tex2D(tileTexture0, texCoords[2]).b, tex2D(tileTexture0, texCoords[3]).a);
			#else
				float4 tile = tex2D(tileTexture0, texCoord.zw);
			#endif

			#if LANDSCAPE_HEIGHT_BLEND_ALLOWED && LANDSCAPE_HEIGHT_BLEND
				#if USE_LANDSCAPE_SCALED_TILES_NON_PBR
					float4 heightMap = float4(tex2D(tileHeightTexture, texCoords[0]).r, tex2D(tileHeightTexture, texCoords[1]).g, tex2D(tileHeightTexture, texCoords[2]).b, tex2D(tileHeightTexture, texCoords[3]).a);
				#else
					float4 heightMap = tex2D(tileHeightTexture, texCoord.zw);
				#endif

				output.color.rgb = getHeightBlend(tileColor0 * tile.r, tileColor1 * tile.g, tileColor2 * tile.b, tileColor3 * tile.a, saturate(heightMap * heightMapScaleColor + (mask * tilemaskWeight * 2.0 + (heightMapOffsetColor - tilemaskWeight)))) * shadowColor;
			#else
				tile *= mask;
				output.color.rgb = ((tileColor0 * tile.r + tileColor1 * tile.g) + (tileColor2 * tile.b + tileColor3 * tile.a)) * shadowColor;
			#endif

			output.color.rgb *= 2.0;
		#endif

		#if LANDSCAPE_LOD_MORPHING && LANDSCAPE_MORPHING_COLOR
			output.color = output.color * 0.25 + input.morphColor * 0.75;
		#endif

		#if CURSOR
			float4 cursorColor = tex2D(cursorTexture, texCoord.xy / cursorCoordSize.zw + (cursorCoordSize.xy / cursorCoordSize.zw + const05List2));
			output.color.rgb -= output.color.rgb * cursorColor.a;
			output.color.rgb += cursorColor.rgb * cursorColor.a;
		#endif

		#include "color-grading.slh"
	#endif

	return output;
}
