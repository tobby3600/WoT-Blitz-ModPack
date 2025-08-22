#include "blending.slh"

blending { src=dst_color dst=zero }

fragment_in
{
	float2 texCoord : TEXCOORD0;
	float4 color : COLOR0;
};

fragment_out
{
	float4 color : SV_TARGET0;
};

uniform sampler2D tex;

[material][a] property float2 maxUV;

fragment_out fp_main(fragment_in input)
{
	fragment_out output;

	output.color = input.color;
	output.color.a *= tex2D(tex, input.texCoord).a > 0.0 ? 1.0 : 0.0;

	return output;
}