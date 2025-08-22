#include "common.slh"

#ensuredefined VEGETATION_LIT 0

#if !DRAW_DEPTH_ONLY && VEGETATION_LIT
	#include "lighting.slh"
#endif

#if USE_SHADOW_MAP
	#include "shadow-mapping.slh"
#endif

fragment_in
{
	#if !DRAW_DEPTH_ONLY
		#if USE_SHADOW_MAP
			float4 projPos : POSITION0;
		#endif

		float4 vegetationColor : COLOR0;
		float4 texCoord : TEXCOORD0;

		#if VEGETATION_LIT
			float3 toLightDir : TEXCOORD1;
			float3 toCamDir : TEXCOORD2;
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
	uniform sampler2D albedo;

	#if VEGETATION_LIT
		uniform sampler2D normalmap;

		[auto][a] property float3 lightColor0;

		[material][a] property float inGlossiness = 0.35;
		[material][a] property float inSpecularity = 0.95;
		[material][a] property float normalScale = 1.0;
		[material][a] property float3 metalFresnelReflectance = float3(0.562, 0.565, 0.578);

		#if USE_SHADOW_MAP
			[material][a] property float2 grassShadowDiffuseSpecMult = const05List2;
		#endif
	#endif

	[material][a] property float grassBaseColorMult = 2.0;
#endif

fragment_out fp_main(fragment_in input)
{
	fragment_out output;

	output.color = const1List4;

	#if !DRAW_DEPTH_ONLY
		output.color = tex2D(albedo, input.texCoord);
		output.color.rgb *= input.vegetationColor * grassBaseColorMult;

		#if USE_SHADOW_MAP
			float3 shadowInf = getShadow(float3(input.texCoord.zw, input.vegetationColor.w), input.projPos.xy / input.projPos.z, 0.0);
			output.color.rgb *= lerp(shadowMapShadowColor.rgb, const1List3, shadowInf.x);
		#endif

		#if VEGETATION_LIT
			float3 N = tex2D(normalmap, input.texCoord).rgb * 2.0 - const1List3;
			N.xy *= normalScale;
			N = normalize(N);

			#include "vector-compute.slh"

			float3 diffuse = lightColor0 * (NdotL * _INVERSE_PI);
			float3 specular = lightColor0 * ((getBlinnPhongSpecular(NdotH, inGlossiness * output.color.a) * lerp(dot(metalFresnelReflectance, rgbMixList), 1.0, pow5Exp(NdotV))) * (inSpecularity * NdotL));

			#if USE_SHADOW_MAP
				float2 diffuseSpecularShadowTerm = -grassShadowDiffuseSpecMult * shadowInf.x + (grassShadowDiffuseSpecMult + shadowInf.xx);
				output.color.rgb += diffuse * diffuseSpecularShadowTerm.x;
				output.color.rgb += specular * diffuseSpecularShadowTerm.y;
			#else
				output.color.rgb += diffuse + specular;
			#endif
		#endif

		#include "color-grading.slh"
	#endif

	return output;
}
