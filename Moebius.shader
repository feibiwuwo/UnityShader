Shader "Custom/Moebius"
{
    Properties
    {
        _Color ("Color", Color) = (1, 1, 1, 1)                       // ������ɫ
        _MainTex ("Albedo (RGB)", 2D) = "white" {}                   // ������
        _RampTex ("Ramp Texture", 2D) = "white" {}                   // ��������
        _NormalMap ("Normal Map", 2D) = "bump" {}                    // ������ͼ
        _NormalIntensity ("Normal Intensity", Range(0, 10)) = 1.0    // ����ǿ��
        [Range(0, 1)] _Metallic ("Metallic", Range(0, 1)) = 0.0      // ������
        _Cutoff ("Cutoff", Range(0, 1)) = 0.5                        // ���սض�
        [Range(0, 1)] _Specular ("Specular", Range(0, 1)) = 0.5      // ����߹�ǿ��
        [Range(0, 1)] _Gloss ("Gloss", Range(0, 1)) = 0.5            // ����߹��С
        _EdgeColor ("Edge Color", Color) = (0, 0, 0, 1)              // ��Ե��ɫ
        _EdgeWidth ("Edge Width", Range(0.01, 0.1)) = 0.05           // ��Ե���
        [NoScaleOffset]_EmissionMap ("Emission", 2D) = "black" {}    // ������ͼ
        _EmissionColor ("Emission Color", Color) = (1, 1, 1, 1)      // ������ɫ
        _EmissionStrength ("Emission Strength", Range(0, 10)) = 1.0  // ����ǿ��
        _OutlineColor ("Outline Color", Color) = (0, 0, 0, 1)        // ���������ɫ
        _OutlineWidth ("Outline Width", Range(0, 1.0)) = 0.0         // ������߿��
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
            fixed3 Albedo;      // ��������ɫ
            fixed3 Normal;      // ���߿ռ䷨��
            fixed3 Emission;    // �Է�����ɫ
            half Specular;      // ����߹�ǿ��
            half Gloss;         // ����߹��С
            half Alpha;         // ͸����
            half Metallic;      // ������
        };

        // ����������
        void vert(inout appdata_full v, out Input o)
        {
            UNITY_INITIALIZE_OUTPUT(Input, o);
            o.uv_MainTex = v.texcoord;
            o.uv_NormalMap = v.texcoord;
            o.viewDir = normalize(ObjSpaceViewDir(v.vertex));
            o.worldNormal = mul((float3x3)UNITY_MATRIX_IT_MV, v.normal);
        }

        // �Զ������ģ��
        fixed4 LightingToonRamp(SurfaceOutputCustom s, fixed3 lightDir, fixed3 viewDir, fixed atten)
        {
            // ������
            fixed diff = max(0, dot(s.Normal, lightDir));
            diff = smoothstep(0, _Cutoff, diff);
            fixed3 diffuse = pow(1 - s.Metallic, 2) * s.Albedo * _LightColor0.rgb * diff * atten * 2;

            // ���淴��
            fixed3 reflectDir = reflect(-lightDir, s.Normal);
            fixed specDot = max(0, dot(viewDir, reflectDir));
            fixed3 specular =  s.Specular * _LightColor0.rgb * s.Albedo * pow(specDot, 10 * (1.001 - s.Gloss)) * atten;

            fixed3 finalColor = diffuse + specular;
            fixed4 c;
            c.rgb = finalColor;
            c.a = s.Alpha;
            return c;
        }

        // ������ɫ
        void surf(Input IN, inout SurfaceOutputCustom o)
        {
            // ���������
            fixed4 c = tex2D(_MainTex, IN.uv_MainTex) * _Color;
            o.Albedo = c.rgb;
            o.Alpha = c.a;

            // ��������
            half grayScale = dot(c.rgb, fixed3(0.299, 0.587, 0.114));
            fixed4 rampColor = tex2D(_RampTex, float2(grayScale, 0.5));
            o.Albedo *= rampColor.rgb;

            // ���ߴ���
            fixed4 normalTex = tex2D(_NormalMap, IN.uv_NormalMap);
            float3 normal = UnpackNormal(normalTex);
            normal.xy *= _NormalIntensity;
            normal = normalize(normal);
            o.Normal = normal;

            // ������
            o.Metallic = _Metallic;

            // ����߹�ǿ��
            o.Specular =_Specular;

            // ����߹��С
            o.Gloss = _Gloss;

            // ��Ե����
            half edge = 1.0 - smoothstep(0.0, _EdgeWidth, abs(dot(IN.worldNormal, IN.viewDir)));
            o.Emission += _EdgeColor.rgb * edge;

            //�Է���
            fixed4 emissionTex = tex2D(_EmissionMap, IN.uv_MainTex);
            o.Emission += emissionTex.rgb * _EmissionColor.rgb * _EmissionStrength;
        }
        ENDCG

        // ������ߣ�������������
        Pass
        {
            // �޳�����
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

            // ��������
            v2f vertOutline(appdata v)
            {
                v2f o;
                float4 newVertex = v.vertex + float4(v.normal, 0) * _OutlineWidth;
                o.vertex = UnityObjectToClipPos(newVertex);
                return o;
            }

            // �����ɫ
            fixed4 fragOutline() : SV_Target
            {
                return _OutlineColor;
            }
            ENDCG
        }
    }
    FallBack "Diffuse"
}