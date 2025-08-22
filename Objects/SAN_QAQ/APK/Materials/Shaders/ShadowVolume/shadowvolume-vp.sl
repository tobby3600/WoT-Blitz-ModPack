#include "common.slh"
#include "materials-vertex-properties.slh"

vertex_in
{
	float4 localPos : POSITION;
	float3 normal : NORMAL;

	#if HARD_SKINNING
		float index : BLENDINDICES;
	#endif
};

vertex_out
{
	float4 localPos : SV_POSITION;
};

[auto][instance] property float4 lightPosition0;
[auto][instance] property float4x4 worldViewMatrix;
[auto][instance] property float4x4 worldViewInvTransposeMatrix;
[auto][global] property float4x4 projMatrix;

#if FORCED_SHADOW_DIRECTION
	[auto][global] property float4x4 viewMatrix;

	[material][global] property float3 forcedShadowDirection = float3(const0List2, -1.0);
#endif

vertex_out vp_main(vertex_in input)
{
	vertex_out output;

	#if HARD_SKINNING
		float4 localPos = hardSkinnedPosition(input.localPos.xyz, input.index);
		float4 jQ = jointQuaternions[int(input.index)];
		float3 tmp = cross(jQ.xyz, input.normal) * 2.0;
		float3 normal = normalize(mul(float4(tmp * jQ.w + (input.normal + cross(jQ.xyz, tmp)), 0.0), worldViewInvTransposeMatrix).xyz);
	#else
		float4 localPos = float4(input.localPos.xyz, 1.0);
		float3 normal = normalize(mul(float4(input.normal, 0.0), worldViewInvTransposeMatrix).xyz);
	#endif

	float3 eyePos = mul(float4(localPos, 1.0), worldViewMatrix).xyz;
	float4 projPos = mul(float4(eyePos, 1.0), projMatrix);

	#if FORCED_SHADOW_DIRECTION
		float3 lightPos = normalize(mul(float4(forcedShadowDirection, 0.0), viewMatrix).xyz);
	#else
		float3 lightPos = normalize(eyePos * lightPosition0.w - lightPosition0.xyz);
	#endif

	float4 lightProjPos = mul(float4(lightPos, 0.0), projMatrix);

	float2 gSl = sign(lightProjPos.xy) * 1.5;
	float2 evRes = (gSl * projPos.w - projPos.xy) / (-gSl * lightProjPos.w + lightProjPos.xy);
	evRes = lerp(evRes, float2(250.0, 250.0), step(evRes, float2(0.0, 0.0)));

	output.localPos = lerp(lightProjPos * min(evRes.x, evRes.y) + projPos, projPos, float(dot(normal, lightPos) == 0.0));

	return output;
};
