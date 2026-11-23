// Enumerations, with the names and values of the real Managed DirectX 1.1 (1.0.2902.0).
// Generated from the real assemblies with experiments/mdx-dump.

using System;

namespace Microsoft.DirectX.Direct3D {
	public enum Blend {
		Zero = 1,
		One = 2,
		SourceColor = 3,
		InvSourceColor = 4,
		SourceAlpha = 5,
		InvSourceAlpha = 6,
		DestinationAlpha = 7,
		InvDestinationAlpha = 8,
		DestinationColor = 9,
		InvDestinationColor = 10,
		SourceAlphaSat = 11,
		BothSourceAlpha = 12,
		BothInvSourceAlpha = 13,
		BlendFactor = 14,
		InvBlendFactor = 15,
	}

	[Flags]
	public enum ClearFlags {
		Target = 1,
		ZBuffer = 2,
		Stencil = 4,
	}

	public enum ColorSource {
		Material = 0,
		Color1 = 1,
		Color2 = 2,
	}

	[Flags]
	public enum CreateFlags {
		FpuPreserve = 2,
		MultiThreaded = 4,
		PureDevice = 16,
		SoftwareVertexProcessing = 32,
		HardwareVertexProcessing = 64,
		MixedVertexProcessing = 128,
		DisableDriverManagement = 256,
		AdapterGroupDevice = 512,
		DisableDriverManagementEx = 1024,
		NoWindowChanges = 2048,
	}

	public enum Cull {
		None = 1,
		Clockwise = 2,
		CounterClockwise = 3,
	}

	public enum DepthFormat {
		Unknown = 0,
		D16Lockable = 70,
		D32 = 71,
		D15S1 = 73,
		D24S8 = 75,
		D24X8 = 77,
		D24X4S4 = 79,
		D16 = 80,
		L16 = 81,
		D32SingleLockable = 82,
		D24SingleS8 = 83,
	}

	public enum DeviceType {
		Hardware = 1,
		Reference = 2,
		Software = 3,
		NullReference = 4,
	}

	public enum FillMode {
		Point = 1,
		WireFrame = 2,
		Solid = 3,
	}

	public enum Format {
		Unknown = 0,
		R8G8B8 = 20,
		A8R8G8B8 = 21,
		X8R8G8B8 = 22,
		R5G6B5 = 23,
		X1R5G5B5 = 24,
		A1R5G5B5 = 25,
		A4R4G4B4 = 26,
		R3G3B2 = 27,
		A8 = 28,
		A8R3G3B2 = 29,
		X4R4G4B4 = 30,
		A2B10G10R10 = 31,
		A8B8G8R8 = 32,
		X8B8G8R8 = 33,
		G16R16 = 34,
		A2R10G10B10 = 35,
		A16B16G16R16 = 36,
		A8P8 = 40,
		P8 = 41,
		L8 = 50,
		A8L8 = 51,
		A4L4 = 52,
		V8U8 = 60,
		L6V5U5 = 61,
		X8L8V8U8 = 62,
		Q8W8V8U8 = 63,
		V16U16 = 64,
		A2W10V10U10 = 67,
		D16Lockable = 70,
		D32 = 71,
		D15S1 = 73,
		D24S8 = 75,
		D24X8 = 77,
		D24X4S4 = 79,
		D16 = 80,
		L16 = 81,
		D32SingleLockable = 82,
		D24SingleS8 = 83,
		VertexData = 100,
		Q16W16V16U16 = 110,
		R16F = 111,
		G16R16F = 112,
		A16B16G16R16F = 113,
		R32F = 114,
		G32R32F = 115,
		A32B32G32R32F = 116,
		CxV8U8 = 117,
		Multi2Argb8 = 827606349,
		Dxt1 = 827611204,
		Dxt2 = 844388420,
		Yuy2 = 844715353,
		Dxt3 = 861165636,
		Dxt4 = 877942852,
		Dxt5 = 894720068,
		G8R8G8B8 = 1111970375,
		R8G8B8G8 = 1195525970,
		Uyvy = 1498831189,
	}

	public enum LightType {
		Point = 1,
		Spot = 2,
		Directional = 3,
	}

	[Flags]
	public enum LockFlags {
		None = 0,
		ReadOnly = 16,
		NoSystemLock = 2048,
		NoOverwrite = 4096,
		Discard = 8192,
		DoNotWait = 16384,
		NoDirtyUpdate = 32768,
	}

	public enum MultiSampleType {
		None = 0,
		NonMaskable = 1,
		TwoSamples = 2,
		ThreeSamples = 3,
		FourSamples = 4,
		FiveSamples = 5,
		SixSamples = 6,
		SevenSamples = 7,
		EightSamples = 8,
		NineSamples = 9,
		TenSamples = 10,
		ElevenSamples = 11,
		TwelveSamples = 12,
		ThirteenSamples = 13,
		FourteenSamples = 14,
		FifteenSamples = 15,
		SixteenSamples = 16,
	}

	public enum Pool {
		Default = 0,
		Managed = 1,
		SystemMemory = 2,
		Scratch = 3,
	}

	public enum PrimitiveType {
		PointList = 1,
		LineList = 2,
		LineStrip = 3,
		TriangleList = 4,
		TriangleStrip = 5,
		TriangleFan = 6,
	}

	public enum ResourceType {
		Surface = 1,
		Volume = 2,
		Textures = 3,
		VolumeTexture = 4,
		CubeTexture = 5,
		VertexBuffer = 6,
		IndexBuffer = 7,
	}

	public enum SwapEffect {
		Discard = 1,
		Flip = 2,
		Copy = 3,
	}

	public enum TransformType {
		View = 2,
		Projection = 3,
		Texture0 = 16,
		Texture1 = 17,
		Texture2 = 18,
		Texture3 = 19,
		Texture4 = 20,
		Texture5 = 21,
		Texture6 = 22,
		Texture7 = 23,
		World = 256,
		World1 = 257,
		World2 = 258,
		World3 = 259,
	}

	[Flags]
	public enum Usage {
		None = 0,
		RenderTarget = 1,
		DepthStencil = 2,
		WriteOnly = 8,
		SoftwareProcessing = 16,
		DoNotClip = 32,
		Points = 64,
		RTPatches = 128,
		NPatches = 256,
		Dynamic = 512,
		AutoGenerateMipMap = 1024,
		QueryDisplacementMap = 16384,
		QueryLegacyBumpMap = 32768,
		QuerySrgbRead = 65536,
		QueryFilter = 131072,
		QuerySrgbWrite = 262144,
		QueryPostPixelShaderBlending = 524288,
		QueryVertexTexture = 1048576,
		QueryWrapAndMip = 2097152,
	}

	[Flags]
	public enum VertexFormats {
		None = 0,
		Texture0 = 0,
		Position = 2,
		Transformed = 4,
		PositionBlend1 = 6,
		PositionBlend2 = 8,
		TextureCountShift = 8,
		PositionBlend3 = 10,
		PositionBlend4 = 12,
		PositionBlend5 = 14,
		Normal = 16,
		PositionNormal = 18,
		PointSize = 32,
		Diffuse = 64,
		Specular = 128,
		Texture1 = 256,
		Texture2 = 512,
		Texture3 = 768,
		Texture4 = 1024,
		Texture5 = 1280,
		Texture6 = 1536,
		Texture7 = 1792,
		Texture8 = 2048,
		TextureCountMask = 3840,
		LastBetaUByte4 = 4096,
		PositionW = 16386,
		PositionMask = 16398,
		LastBetaD3DColor = 32768,
	}

}
