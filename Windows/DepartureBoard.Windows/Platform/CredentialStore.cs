using System;
using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Text;

namespace DepartureBoard.Windows.Platform;

internal sealed class CredentialStore(string target = "com.skyline23.departureboard/AeroDataBox")
{
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    private struct Credential
    {
        public uint Flags;
        public uint Type;
        public nint TargetName;
        public nint Comment;
        public long LastWritten;
        public uint BlobSize;
        public nint Blob;
        public uint Persist;
        public uint AttributeCount;
        public nint Attributes;
        public nint TargetAlias;
        public nint UserName;
    }

    public string Read()
    {

        if (!CredRead(target, 1, 0, out var pointer))
        {
            return "";
        }

        try
        {
            var credential = Marshal.PtrToStructure<Credential>(pointer);
            var bytes = new byte[credential.BlobSize];
            Marshal.Copy(credential.Blob, bytes, 0, bytes.Length);
            return Encoding.UTF8.GetString(bytes);
        }
        finally
        {
            CredFree(pointer);
        }
    }

    public void Save(string value)
    {

        if (string.IsNullOrWhiteSpace(value))
        {
            return;
        }

        var bytes = Encoding.UTF8.GetBytes(value.Trim());
        var targetPointer = Marshal.StringToCoTaskMemUni(target);
        var blob = Marshal.AllocHGlobal(bytes.Length);

        try
        {
            Marshal.Copy(bytes, 0, blob, bytes.Length);
            var credential = new Credential
            {
                Type = 1,
                TargetName = targetPointer,
                BlobSize = (uint)bytes.Length,
                Blob = blob,
                Persist = 2,
            };

            if (!CredWrite(ref credential, 0))
            {
                throw new Win32Exception(Marshal.GetLastWin32Error());
            }
        }
        finally
        {
            Array.Clear(bytes);
            Marshal.FreeHGlobal(blob);
            Marshal.FreeCoTaskMem(targetPointer);
        }
    }

    public void Delete()
    {

        if (!CredDelete(target, 1, 0) && Marshal.GetLastWin32Error() != 1168)
        {
            throw new Win32Exception(Marshal.GetLastWin32Error());
        }
    }

    [DllImport(
        "advapi32.dll",
        EntryPoint = "CredDeleteW",
        CharSet = CharSet.Unicode,
        SetLastError = true
    )]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool CredDelete(string target, uint type, uint flags);

    [DllImport(
        "advapi32.dll",
        EntryPoint = "CredReadW",
        CharSet = CharSet.Unicode,
        SetLastError = true
    )]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool CredRead(string target, uint type, uint flags, out nint credential);

    [DllImport(
        "advapi32.dll",
        EntryPoint = "CredWriteW",
        CharSet = CharSet.Unicode,
        SetLastError = true
    )]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool CredWrite(ref Credential credential, uint flags);

    [DllImport("advapi32.dll")]
    private static extern void CredFree(nint credential);
}
