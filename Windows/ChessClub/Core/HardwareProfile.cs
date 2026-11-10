using System.Runtime.InteropServices;

namespace ChessClub.Core;

public sealed record HardwareProfile(int LogicalProcessors, long MemoryMB, int Threads, int HashMB, int Depth)
{
    public static HardwareProfile Detect()
    {
        long memory = GC.GetGCMemoryInfo().TotalAvailableMemoryBytes / 1024 / 1024;
        if (OperatingSystem.IsWindows())
        {
            var status = new MemoryStatus { Length = (uint)Marshal.SizeOf<MemoryStatus>() };
            if (GlobalMemoryStatusEx(ref status)) memory = (long)Math.Min(status.TotalPhysical, status.AvailablePhysical + status.AvailablePhysical / 2) / 1024 / 1024;
        }
        return ForHardware(Environment.ProcessorCount, memory);
    }
    public static HardwareProfile ForHardware(int logicalProcessors, long memoryMB)
    {
        var cores = Math.Max(1, logicalProcessors);
        var memory = Math.Max(0, memoryMB);
        var threads = Math.Clamp(cores - 2, 1, 32);
        // Reserve at least 2 GB for the OS and bound Stockfish's transposition table.
        var budget = Math.Max(16, Math.Min(memory / 8, memory - 2048));
        var hash = 16;
        while (hash < 4096 && hash * 2 <= budget) hash *= 2;
        var depth = threads >= 12 && hash >= 512 ? 30 : threads >= 6 && hash >= 256 ? 28 : threads >= 3 ? 26 : 24;
        return new(cores, memory, threads, hash, depth);
    }
    [StructLayout(LayoutKind.Sequential)]
    private struct MemoryStatus
    {
        public uint Length, Load;
        public ulong TotalPhysical, AvailablePhysical, TotalPageFile, AvailablePageFile, TotalVirtual, AvailableVirtual, AvailableExtendedVirtual;
    }
    [DllImport("kernel32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool GlobalMemoryStatusEx(ref MemoryStatus buffer);
}
