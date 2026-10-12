Add-Type @'
using System;
using System.Runtime.InteropServices;
namespace Wanwan {
 public static class Power {
  [StructLayout(LayoutKind.Sequential)] struct LUID { public uint LowPart; public int HighPart; }
  [StructLayout(LayoutKind.Sequential)] struct TOKEN_PRIVILEGES { public uint Count; public LUID Luid; public uint Attributes; }
  [DllImport("advapi32.dll",SetLastError=true)] static extern bool OpenProcessToken(IntPtr p,uint access,out IntPtr token);
  [DllImport("advapi32.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern bool LookupPrivilegeValue(string system,string name,out LUID luid);
  [DllImport("advapi32.dll",SetLastError=true)] static extern bool AdjustTokenPrivileges(IntPtr token,bool disable,ref TOKEN_PRIVILEGES state,uint length,IntPtr prev,IntPtr result);
  [DllImport("kernel32.dll")] static extern IntPtr GetCurrentProcess();
  [DllImport("kernel32.dll")] static extern bool CloseHandle(IntPtr handle);
  [DllImport("user32.dll",EntryPoint="ExitWindowsEx",SetLastError=true)] static extern bool ExitNative(uint flags,uint reason);
  public static int LastError {get;private set;}
  public static int TokenStructureSize {get{return Marshal.SizeOf(typeof(TOKEN_PRIVILEGES));}}
  public static bool TryEnableShutdownPrivilege(){
   LastError=0;IntPtr token;
   if(!OpenProcessToken(GetCurrentProcess(),0x28,out token)){LastError=Marshal.GetLastWin32Error();return false;}
   try {
    LUID luid;if(!LookupPrivilegeValue(null,"SeShutdownPrivilege",out luid)){LastError=Marshal.GetLastWin32Error();return false;}
    var state=new TOKEN_PRIVILEGES{Count=1,Luid=luid,Attributes=2};
    bool ok=AdjustTokenPrivileges(token,false,ref state,0,IntPtr.Zero,IntPtr.Zero);
    LastError=Marshal.GetLastWin32Error();return ok && LastError==0;
   }finally{CloseHandle(token);}
  }
  public static bool ExitWindowsEx(uint flags,uint reason){
   if(flags!=1)throw new ArgumentException("Only normal shutdown is supported");
   if(!TryEnableShutdownPrivilege())return false;
   bool ok=ExitNative(flags,reason);LastError=ok?0:Marshal.GetLastWin32Error();return ok;
  }
 }
}
'@
