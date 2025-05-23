#include "common.slh"

fragment_in {};

fragment_out
{
	float4 color : SV_TARGET0;
};

[material][a] property float4 silhouetteColor;

fragment_out fp_main(fragment_in input)
{
	fragment_out output;

	output.color = silhouetteColor;
	output.color.rgb = toLinear(output.color.rgb);

	#include "color-grading.slh"

	return output;
}
