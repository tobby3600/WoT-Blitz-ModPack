#include "common.slh"
#include "blending.slh"

fragment_in
{
	float2 texCoord : TEXCOORD0;
};

fragment_out
{
	float4 color : SV_TARGET0;
};

uniform sampler2D tex;

[material][a] property float2 maxUV;
[material][a] property float2 pixelSize;

fragment_out fp_main(fragment_in input)
{
	fragment_out output;

	const float2 kernelParams[5];
	kernelParams[0] = float2(0.66051, 0.14161);
	kernelParams[1] = float2(2.46556, 0.16111);
	kernelParams[2] = float2(4.43823, 0.11007);
	kernelParams[3] = float2(6.41127, 0.06048);
	kernelParams[4] = float2(8.38483, 0.02673);

	float2 blurColor = const0List2;
	float4 offset = const0List4;

	#ifdef VBLUR
		offset.x = pixelSize.x;
	#else
		offset.y = pixelSize.y;
	#endif

	[unroll]
	for (int i = 0; i < 5; i++)
	{
		offset.zw = offset.xy * kernelParams[i].x;
		blurColor += tex2D(tex, clamp(input.texCoord + offset.zw, const0List2, maxUV)).xw * kernelParams[i].y;
		blurColor += tex2D(tex, clamp(input.texCoord - offset.zw, const0List2, maxUV)).xw * kernelParams[i].y;
	}

	#ifdef USE_RED_TEXTURE_CHANNEL
		output.color.r = blurColor.r;
	#else
		output.color.r = blurColor.g;
	#endif

	output.color.gba = const1List3;

	return output;
}
