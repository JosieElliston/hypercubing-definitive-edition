// Generated from the real Microsoft.DirectX.Direct3DX 1.0.2902.0 with experiments/mdx-dump.

using System;

namespace Microsoft.DirectX.Direct3D {
	[Flags]
	public enum MeshFlags {
		SimplifyVertex = 1,
		Use32Bit = 1,
		DoNotClip = 2,
		SimplifyFace = 2,
		Points = 4,
		RtPatches = 8,
		VbSystemMem = 16,
		VbManaged = 32,
		VbWriteOnly = 64,
		VbDynamic = 128,
		IbSystemMem = 256,
		SystemMemory = 272,
		IbManaged = 512,
		Managed = 544,
		IbWriteOnly = 1024,
		WriteOnly = 1088,
		IbDynamic = 2048,
		Dynamic = 2176,
		VbShare = 4096,
		UseHardwareOnly = 8192,
		NPatches = 16384,
		VbSoftwareProcessing = 32768,
		IbSoftwareProcessing = 65536,
		SoftwareProcessing = 98304,
		OptimizeDeviceIndependent = 4194304,
		OptimizeCompact = 16777216,
		OptimizeAttributeSort = 33554432,
		OptimizeVertexCache = 67108864,
		OptimizeStripeReorder = 134217728,
		OptimizeIgnoreVerts = 268435456,
		OptimizeDoNotSplit = 536870912,
	}

}
