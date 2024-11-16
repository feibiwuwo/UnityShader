Shader "Custom/Moebius"
{
    Properties
    {
        _Color ("Color", Color) = (1, 1, 1, 1)                       // 基础颜色
        _MainTex ("Albedo (RGB)", 2D) = "white" {}                   // 主纹理
        _RampTex ("Ramp Texture", 2D) = "white" {}                   // 渐变纹理
        _NormalMap ("Normal Map", 2D) = "bump" {}                    // 法线贴图
        _NormalIntensity ("Normal Intensity", Range(0, 10)) = 1.0    // 法线强度
        [Range(0, 1)] _Metallic ("Metallic", Range(0, 1)) = 0.0      // 金属度
        _Cutoff ("Cutoff", Range(0, 1)) = 0.5                        // 光照截断
        [Range(0, 1)] _Specular ("Specular", Range(0, 1)) = 0.5      // 镜面高光强度
        [Range(0, 1)] _Gloss ("Gloss", Range(0, 1)) = 0.5            // 镜面高光大小
        _EdgeColor ("Edge Color", Color) = (0, 0, 0, 1)              // 边缘颜色
        _EdgeWidth ("Edge Width", Range(0.01, 0.1)) = 0.05           // 边缘宽度
        [NoScaleOffset]_EmissionMap ("Emission", 2D) = "black" {}    // 发光贴图
        _EmissionColor ("Emission Color", Color) = (1, 1, 1, 1)      // 发光颜色
        _EmissionStrength ("Emission Strength", Range(0, 10)) = 1.0  // 发光强度
        _OutlineColor ("Outline Color", Color) = (0, 0, 0, 1)        // 轮廓描边颜色
        _OutlineWidth ("Outline Width", Range(0, 1.0)) = 0.0         // 轮廓描边宽度
    }
    SubShader
    {
        Tags { "RenderType" = "Opaque" }
        LOD 200

        CGPROGRAM
        #pragma surface surf ToonRamp fullforwardshadows vertex:vert
        #pragma target 3.0

        fixed4 _Color;
        sampler2D _MainTex;
        sampler2D _RampTex;
        sampler2D _NormalMap;
        float _NormalIntensity;
        half _Metallic;
        half _Cutoff;
        half _Specular;
        half _Gloss;
        fixed4 _EdgeColor;
        half _EdgeWidth;
        sampler2D _EmissionMap;
        fixed4 _EmissionColor;
        half _EmissionStrength;

        struct Input
        {
            float2 uv_MainTex;
            float2 uv_NormalMap;
            float3 viewDir;
            float3 worldNormal;
            INTERNAL_DATA
        };

        struct SurfaceOutputCustom
        {
            fixed3 Albedo;      // 漫反射颜色
            fixed3 Normal;      // 切线空间法线
            fixed3 Emission;    // 自发光颜色
            half Specular;      // 镜面高光强度
            half Gloss;         // 镜面高光大小
            half Alpha;         // 透明度
            half Metallic;      // 金属度
        };

        // 处理顶点数据
        void vert(inout appdata_full v, out Input o)
        {
            UNITY_INITIALIZE_OUTPUT(Input, o);
            o.uv_MainTex = v.texcoord;
            o.uv_NormalMap = v.texcoord;
            o.viewDir = normalize(ObjSpaceViewDir(v.vertex));
            o.worldNormal = mul((float3x3)UNITY_MATRIX_IT_MV, v.normal);
        }

        // 自定义光照模型
        fixed4 LightingToonRamp(SurfaceOutputCustom s, fixed3 lightDir, fixed3 viewDir, fixed atten)
        {
            // 漫反射
            fixed diff = max(0, dot(s.Normal, lightDir));
            diff = smoothstep(0, _Cutoff, diff);
            fixed3 diffuse = pow(1 - s.Metallic, 2) * s.Albedo * _LightColor0.rgb * diff * atten * 2;

            // 镜面反射
            fixed3 reflectDir = reflect(-lightDir, s.Normal);
            fixed specDot = max(0, dot(viewDir, reflectDir));
            fixed3 specular =  s.Specular * _LightColor0.rgb * s.Albedo * pow(specDot, 10 * (1.001 - s.Gloss)) * atten;

            fixed3 finalColor = diffuse + specular;
            fixed4 c;
            c.rgb = finalColor;
            c.a = s.Alpha;
            return c;
        }

        // 表面着色
        void surf(Input IN, inout SurfaceOutputCustom o)
        {
            // 主纹理采样
            fixed4 c = tex2D(_MainTex, IN.uv_MainTex) * _Color;
            o.Albedo = c.rgb;
            o.Alpha = c.a;

            // 渐变纹理
            half grayScale = dot(c.rgb, fixed3(0.299, 0.587, 0.114));
            fixed4 rampColor = tex2D(_RampTex, float2(grayScale, 0.5));
            o.Albedo *= rampColor.rgb;

            // 法线处理
            fixed4 normalTex = tex2D(_NormalMap, IN.uv_NormalMap);
            float3 normal = UnpackNormal(normalTex);
            normal.xy *= _NormalIntensity;
            normal = normalize(normal);
            o.Normal = normal;

            // 金属度
            o.Metallic = _Metallic;

            // 镜面高光强度
            o.Specular =_Specular;

            // 镜面高光大小
            o.Gloss = _Gloss;

            // 边缘高亮
            half edge = 1.0 - smoothstep(0.0, _EdgeWidth, abs(dot(IN.worldNormal, IN.viewDir)));
            o.Emission += _EdgeColor.rgb * edge;

            //自发光
            fixed4 emissionTex = tex2D(_EmissionMap, IN.uv_MainTex);
            o.Emission += emissionTex.rgb * _EmissionColor.rgb * _EmissionStrength;
        }
        ENDCG

        // 轮廓描边（法线外扩法）
        Pass
        {
            // 剔除正面
            Cull Front

            CGPROGRAM
            #pragma vertex vertOutline
            #pragma fragment fragOutline

            float4 _OutlineColor;
            float _OutlineWidth;

            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;
            };

            // 法线外扩
            v2f vertOutline(appdata v)
            {
                v2f o;
                float4 newVertex = v.vertex + float4(v.normal, 0) * _OutlineWidth;
                o.vertex = UnityObjectToClipPos(newVertex);
                return o;
            }

            // 描边颜色
            fixed4 fragOutline() : SV_Target
            {
                return _OutlineColor;
            }
            ENDCG
        }
    }
    FallBack "Diffuse"
}