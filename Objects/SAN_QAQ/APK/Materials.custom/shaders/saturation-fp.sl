#include "common.slh"
#include "blending.slh"

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

[material][a] property float saturation;

fragment_out fp_main(fragment_in input)
{
	fragment_out output;

	float2 adjCoef;

	output.color = tex2D(tex, input.texCoord) * input.color;
	adjCoef.x = getLum(output.color.rgb);
	adjCoef.y = saturation * 0.01 + 1.0;
	output.color.rgb = lerp(adjCoef.xxx, output.color.rgb, adjCoef.y);

	return output;
}