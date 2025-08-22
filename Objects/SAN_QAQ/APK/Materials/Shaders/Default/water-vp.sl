#include "common.slh"
#include "vp-fog-props.slh"

#ensuredefined WATER_DEFORMATION 0
#ensuredefined WATER_RENDER_OBJECT 0
#ensuredefined WATER_TESSELLATION 0

vertex_in
{
	[vertex] float4 localPos : POSITION;

	#if WATER_RENDER_OBJECT
		#if WATER_TESSELLATION
			[instance] float2 texCoord0 : TEXCOORD0;
		#elif !PIXEL_LIT
			[vertex] float2 texCoord1 : TEXCOORD1; // decal
		#endif
	#else
		[vertex] float2 texCoord0 : TEXCOORD0;

		#if !PIXEL_LIT
			[vertex] float2 texCoord1 : TEXCOORD1; // decal
		#endif

		[vertex] float3 normal : NORMAL;
		[vertex] float3 tangent : TANGENT;
	#endif
};

vertex_out
{
	float4 localPos : SV_POSITION;
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

#if WATER_DEFORMATION
	uniform sampler2D dynamicWaterDeformationMap;
#endif

[auto][a] property float3 cameraPosition;
[auto][a] property float4 lightPosition0;
[auto][a] property float4x4 viewMatrix;
[auto][a] property float4x4 viewProjMatrix;
[auto][a] property float4x4 worldMatrix;

#if WATER_DEFORMATION
	[auto][a] property float3 cameraDirection;
	[auto][a] property float4 waterDeformationParams; // xy - fadeOutRange, z - maxDeformation, w - cameraBias
	[auto][a] property float4x4 waterDeformationViewProj;
#endif

#if !DRAW_DEPTH_ONLY
	[auto][a] property float globalTime;
	[auto][a] property float4x4 worldInvTransposeMatrix;

	#if PIXEL_LIT
		#if REAL_REFLECTION
			[auto][a] property float projectionFlip;
		#endif

		[auto][a] property float4x4 worldViewInvTransposeMatrix;
	#endif

	#if WATER_RENDER_OBJECT
		[material][a] property float3 inputTangent;
		[material][a] property float4 texCoordTransform0;
	#endif

	[auto][instance] property float4x4 viewMatrix;

	[material][instance] property float normal0Scale = 1.0;
	[material][instance] property float normal1Scale = 1.0;
	[material][instance] property float2 normal0ShiftPerSecond = const0List2;
	[material][instance] property float2 normal1ShiftPerSecond = const0List2;
#endif

vertex_out vp_main(vertex_in input)
{
	vertex_out output;

	float3 localPos = input.localPos.xyz;
	float3 camPos = cameraPosition;

	#if WATER_RENDER_OBJECT && WATER_TESSELLATION
		localPos.xy += input.texCoord0.xy;
	#endif

	float3 worldPos = mul(float4(localPos, 1.0), worldMatrix).xyz;
	float3 toCamDir = camPos - worldPos;

	#if WATER_DEFORMATION
		float4 waveCoef = float4(mul(float4(worldPos, 1.0), waterDeformationViewProj).xyz, 1.0 - smoothstep(waterDeformationParams.x, waterDeformationParams.y, length(cameraDirection.xy * waterDeformationParams.w + toCamDir.xy)));
		float2 waveTexCoord = waveCoef.xy * float2(0.5, -0.5) + const05List2;
		float2 offset = float2(0.025 / waterDeformationParams.y, 0.0);

		float4 waveX = tex2Dlod(dynamicWaterDeformationMap, waveTexCoord + offset, 0.0) * waveCoef.w;
		float4 waveY = tex2Dlod(dynamicWaterDeformationMap, waveTexCoord - offset.yx, 0.0) * waveCoef.w;
		float4 waveZ = tex2Dlod(dynamicWaterDeformationMap, waveTexCoord, 0.0) * waveCoef.w;
		float3 wave = float3(waveX.b - waveX.r, waveY.b - waveY.r, waveZ.r - waveZ.b);
		worldPos.z += wave.z * waterDeformationParams.z;
	#endif

	float3 eyePos = mul(float4(worldPos, 1.0), viewMatrix).xyz;
	float3 viewPos = -eyePos;
	output.localPos = mul(float4(worldPos, 1.0), viewProjMatrix);
	output.projPos = output.localPos;

	float3 toLightDir = viewPos * lightPosition0.w + lightPosition0.xyz;
	float toLightDis = length(toLightDir);
	toLightDir /= toLightDis;

	#if USE_VERTEX_FOG
		#include "vp-fog-math.slh"
	#endif

	#if !DRAW_DEPTH_ONLY
		output.worldPos.xyz = worldPos;

		#if WATER_DEFORMATION
			output.worldPos.w = waveZ.g;
		#endif

		#if WATER_RENDER_OBJECT
			float2 texCoord = float2(dot(localPos.xy, texCoordTransform0.xz), dot(localPos.xy, texCoordTransform0.yw));

			#if WATER_DEFORMATION
				float3 normal = normalize(float3(wave.xy + wave.zz, 0.05));
				float3 tangent = normalize(normal * dot(-inputTangent, normal) + inputTangent);
			#else
				float3 normal = float3(const0List2, 1.0);
				float3 tangent = inputTangent;
			#endif
		#else
			float2 texCoord = input.texCoord0;
			float3 normal = input.normal;
			float3 tangent = input.tangent;
		#endif

		output.texCoord = float4(texCoord * normal0Scale + frac(normal0ShiftPerSecond * globalTime), float2(texCoord.x + texCoord.y, texCoord.y - texCoord.x) * normal1Scale + frac(normal1ShiftPerSecond * globalTime));

		#if PIXEL_LIT
			float3 n = normalize(mul(float4(normal, 0.0), worldViewInvTransposeMatrix).xyz);
			float3 t = normalize(mul(float4(tangent, 0.0), worldViewInvTransposeMatrix).xyz);
			float3 b = cross(n, t);

			output.toLightDir = float3(dot(toLightDir, t), dot(toLightDir, b), dot(toLightDir, n));
			output.toCamDir = float3(dot(viewPos, t), dot(viewPos, b), dot(viewPos, n));

			#if REAL_REFLECTION
				output.reflectionPos = float4(output.projPos.xyw, dot(eyePos, viewPos));
				output.reflectionPos.y *= projectionFlip;
			#else
				n = normalize(mul(float4(normal, 0.0), worldInvTransposeMatrix).xyz);
				t = normalize(mul(float4(tangent, 0.0), worldInvTransposeMatrix).xyz);
				b = cross(n, t);

				output.tangentToWorld0 = float3(t.x, b.x, n.x);
				output.tangentToWorld1 = float3(t.y, b.y, n.y);
				output.tangentToWorld2 = float3(t.z, b.z, n.z);
			#endif
		#else
			output.reflectionTexCoord = reflect(normalize(-toCamDir), normalize(mul(float4(normal, 0.0), worldInvTransposeMatrix).xyz));

			#if WATER_TESSELLATION
				output.decalTexCoord = const0List2;
			#else
				output.decalTexCoord = input.texCoord1;
			#endif
		#endif
	#endif

	return output;
}
