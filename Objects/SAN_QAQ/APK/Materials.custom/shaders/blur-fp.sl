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

[material][a] property float2 maxUV;
[material][a] property float2 pixelSize;

fragment_out fp_main(fragment_in input)
{
	fragment_out output;

	#ifdef BLUR_LITE
		#define BLUR_STEP 5
	#else
		#define BLUR_STEP 9
	#endif

	const float2 kernelParams[BLUR_STEP];

	#ifdef BLUR_LITE
		kernelParams[0] = float2(0.66051, 0.14161);
		kernelParams[1] = float2(2.46556, 0.16111);
		kernelParams[2] = float2(4.43823, 0.11007);
		kernelParams[3] = float2(6.41127, 0.06048);
		kernelParams[4] = float2(8.38483, 0.02673);
	#else
		kernelParams[0] = float2(0.66293, 0.10855);
		kernelParams[1] = float2(2.47904, 0.13135);
		kernelParams[2] = float2(4.46232, 0.10406);
		kernelParams[3] = float2(6.44568, 0.07216);
		kernelParams[4] = float2(8.42917, 0.04380);
		kernelParams[5] = float2(10.41281, 0.02328);
		kernelParams[6] = float2(12.39664, 0.01083);
		kernelParams[7] = float2(14.38072, 0.00441);
		kernelParams[8] = float2(16.36501, 0.00157);
	#endif

	float3 blurColor = const0List3;
	float4 offset = const0List4;

	#ifdef VBLUR
		offset.x = pixelSize.x;
	#else
		offset.y = pixelSize.y;
	#endif

	[unroll]
	for (int i = 0; i < BLUR_STEP; i++)
	{
		offset.zw = offset.xy * kernelParams[i].x;
		blurColor += tex2D(tex, clamp(input.texCoord + offset.zw, const0List2, maxUV)).xyz * kernelParams[i].y;
		blurColor += tex2D(tex, clamp(input.texCoord - offset.zw, const0List2, maxUV)).xyz * kernelParams[i].y;
	}

	output.color = input.color * float4(blurColor, 1.0);

	return output;
}
