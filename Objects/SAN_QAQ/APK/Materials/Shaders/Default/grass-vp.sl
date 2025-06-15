#include "common.slh"
#include "vp-fog-props.slh"

#ensuredefined FLORA_WAVE_ANIMATION 0
#ensuredefined VEGETATION_DENSITY_CHANNEL 4
#ensuredefined VEGETATION_LIT 0
#ensuredefined VEGETATION_SEPARATE_DENSITY_MAP 0

#if FLORA_WAVE_ANIMATION
	#include "flora-wave-animation.slh"
#endif

vertex_in
{
	[vertex] float4 localPos : POSITION;
	[vertex] float4 texCoord : TEXCOORD0;
	[vertex] float3 pivotPos : TEXCOORD1;

	#if !DRAW_DEPTH_ONLY && VEGETATION_LIT
		[vertex] float3 normal : NORMAL;
		[vertex] float3 tangent : TANGENT;
		[vertex] float3 binormal : BINORMAL;
	#endif

	[instance] float4 tilePos : TEXCOORD2;
	[instance] float4 windWaveOffsetsX : TEXCOORD3;
	[instance] float4 windWaveOffsetsY : TEXCOORD4;
	[instance] float switchLodIndex : TEXCOORD5;
};

vertex_out
{
	float4 localPos : SV_POSITION;

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

uniform sampler2D heightmap;
uniform sampler2D vegetationColorMap;

#if VEGETATION_SEPARATE_DENSITY_MAP
	uniform sampler2D vegetationDensityMap;
#endif

[auto][a] property float heightmapTextureSize;
[auto][a] property float3 cameraPosition;
[auto][a] property float4x4 viewProjMatrix;

#if !DRAW_DEPTH_ONLY
	[auto][a] property float4 lightPosition0;
	[auto][a] property float4x4 viewMatrix;
#endif

#if VEGETATION_BEND
	[auto][a] property float2 viewportSize;
	[auto][a] property float3 cameraDirection;
	[auto][a] property float4 grassBendParams;

	[material][a] property float grassBendWeight;
#endif

[material][a] property float3 worldSize;

vertex_out vp_main(vertex_in input)
{
	vertex_out output;

	int chunkType = int(input.texCoord.z);
	float3 camPos = cameraPosition;
	float3 pivotPos = float3(input.pivotPos.xy + input.tilePos.xy, input.pivotPos.z);
	float3 worldPos = float3(float2(input.texCoord.w * input.windWaveOffsetsX[chunkType], input.texCoord.w * input.windWaveOffsetsY[chunkType]) * 2.25 + (input.localPos.xy + input.tilePos.xy), input.localPos.z);

	float densityScale;
	float2 toCamDirScale;
	float2 texCoord = pivotPos.xy / worldSize.xy + const05List2;
	float2 vegetationTexCoord = float2(texCoord.x, 1.0 - texCoord.y);
	float4 vegetationHeight = tex2Dlod(heightmap, const05List2 / heightmapTextureSize + texCoord, 0.0);
	float4 vegetationColor = tex2Dlod(vegetationColorMap, vegetationTexCoord, 0.0);

	#if HEIGHTMAP_FLOAT_TEXTURE
		float height = vegetationHeight.r;
	#else
		float height = dot(vegetationHeight, heightList);
	#endif

	height *= worldSize.z;
	worldPos.z += height;
	pivotPos.z += height;

	#if VEGETATION_SEPARATE_DENSITY_MAP
		float4 vegetationDensity = tex2Dlod(vegetationDensityMap, vegetationTexCoord, 0.0);

		#if VEGETATION_DENSITY_CHANNEL == 1
			densityScale = vegetationDensity.r;
		#elif VEGETATION_DENSITY_CHANNEL == 2
			densityScale = vegetationDensity.g;
		#elif VEGETATION_DENSITY_CHANNEL == 3
			densityScale = vegetationDensity.b;
		#else
			densityScale = vegetationDensity.a;
		#endif
	#else
		densityScale = vegetationColor.a;
	#endif

	float3 toCamDir = camPos - worldPos;

	#if VEGETATION_BEND
		float toCamDirDot = dot(toCamDir, toCamDir);
		float toCamDirProjLength = dot(toCamDir, normalize(cameraDirection));

		toCamDirScale = viewportSize * float2(pow(toCamDirDot, grassBendParams.w) + grassBendParams.y, -grassBendParams.z);
		toCamDirScale.y /= toCamDirScale.x;
		toCamDirScale.x = clamp((toCamDirProjLength * toCamDirProjLength - toCamDirDot) * toCamDirScale.y, grassBendParams.x, 1.0);
	#else
		toCamDirScale = const1List2;
	#endif

	#if FLORA_WAVE_ANIMATION
		worldPos += getWaveAnim(worldPos) * input.localPos.z;
	#endif

	float finalScale = (densityScale * input.tilePos.z) * (lerp(1.0, toCamDirScale.x, grassBendWeight) * lerp(input.tilePos.w, 1.0, step(abs(input.switchLodIndex - input.localPos.w), 0.1)));
	worldPos = lerp(pivotPos, worldPos, finalScale);

	output.localPos = mul4Fast1(worldPos, viewProjMatrix);
	output.localPos.z = lerp(output.localPos.z, 100000.0, step(finalScale, 0.001));

	#if !DRAW_DEPTH_ONLY
		#if USE_SHADOW_MAP
			output.projPos = output.localPos;
		#endif

		output.texCoord = float4(input.texCoord.xy, worldPos.xy);
		output.vegetationColor = float4(vegetationColor.rgb, worldPos.z);

		float3 eyePos = mul3Fast1(worldPos, viewMatrix);
		float3 viewPos = -eyePos;
		float3 toLightDir = viewPos * lightPosition0.w + lightPosition0.xyz;
		float toLightDis = length(toLightDir);
		toLightDir /= toLightDis;

		#if VEGETATION_LIT
			float3 t = normalize(mul3Fast0(input.tangent, worldViewInvTransposeMatrix));
			float3 b = normalize(mul3Fast0(input.binormal, worldViewInvTransposeMatrix));
			float3 n = normalize(mul3Fast0(input.normal, worldViewInvTransposeMatrix));

			output.toLightDir = float3(dot(toLightDir, t), dot(toLightDir, b), dot(toLightDir, n));
			output.toCamDir = float3(dot(viewPos, t), dot(viewPos, b), dot(viewPos, n));
		#endif
	#endif

	#if USE_VERTEX_FOG
		#include "vp-fog-math.slh"
	#endif

	return output;
}
