#include "common.slh"

vertex_in
{
	float4 localPos : POSITION;
	[instance] float4 worldMatrix0 : TEXCOORD1;
	[instance] float4 worldMatrix1 : TEXCOORD2;
	[instance] float4 worldMatrix2 : TEXCOORD3;
};

vertex_out
{
	float4 localPos : SV_POSITION;
};

[auto][a] property float4x4 viewProjMatrix;

vertex_out vp_main(vertex_in input)
{
	vertex_out output;

	float4x4 worldMatrix = vecToMat(input.worldMatrix0, input.worldMatrix1, input.worldMatrix2);

	output.localPos = mul(mul4Fast1(input.localPos.xyz, worldMatrix), viewProjMatrix);

	return output;
}
