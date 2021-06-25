void ThirdsRuler_float(float2 uv, float ratio, out float alpha){
    float width = 0.002;
    float verticalLine1 = 1 - step(width / ratio, abs(uv.x - 0.33));
    float verticalLine2 = 1 - step(width / ratio, abs(uv.x - 0.66));
    float horizontalLine1 = 1 - step(width, abs(uv.y - 0.33));
    float horizontalLine2 = 1 - step(width, abs(uv.y - 0.66));

    alpha = saturate(verticalLine1 + verticalLine2 + horizontalLine1 + horizontalLine2);
}