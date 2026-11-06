param(
  [string]$Out = "D:\Projects\CardMind\spike\nsh-editor-md-probe\logs\window.png",
  [int]$ClickX = -1,
  [int]$ClickY = -1,
  [int]$SleepMs = 600
)
$ProgressPreference = 'SilentlyContinue'
Add-Type -AssemblyName System.Drawing.Common
$src = @'
using System;
using System.Text;
using System.Runtime.InteropServices;
public class ProbeWin {
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc cb, IntPtr lParam);
  public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
  [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr hWnd, StringBuilder text, int count);
  [DllImport("user32.dll")] public static extern int GetClassName(IntPtr hWnd, StringBuilder text, int count);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint pid);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hWnd);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT rect);
  [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr hWnd, IntPtr after, int x, int y, int cx, int cy, uint flags);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int cmd);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
  [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr hWnd, IntPtr hdc, uint flags);
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
  [DllImport("user32.dll")] public static extern void mouse_event(uint flags, uint dx, uint dy, uint data, UIntPtr extra);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
  public static void Click(int x, int y) { SetCursorPos(x, y); mouse_event(0x0002, 0, 0, 0, UIntPtr.Zero); mouse_event(0x0004, 0, 0, 0, UIntPtr.Zero); }
}
'@
Add-Type -TypeDefinition $src
$windows = New-Object System.Collections.ArrayList
$cb = [ProbeWin+EnumWindowsProc]{
  param($hWnd, $lParam)
  $pidOut = 0
  [void][ProbeWin]::GetWindowThreadProcessId($hWnd, [ref]$pidOut)
  $proc = (Get-Process -Id $pidOut -ErrorAction SilentlyContinue).ProcessName
  if ($proc -match 'nsh') {
    $cn = New-Object System.Text.StringBuilder 256
    [void][ProbeWin]::GetClassName($hWnd, $cn, 256)
    if ($cn.ToString() -eq 'NshWindow') {
      $sb = New-Object System.Text.StringBuilder 512
      [void][ProbeWin]::GetWindowText($hWnd, $sb, 512)
      $r = New-Object ProbeWin+RECT; [void][ProbeWin]::GetWindowRect($hWnd, [ref]$r)
      [void]$windows.Add([pscustomobject]@{Handle=$hWnd; Title=$sb.ToString(); Left=$r.Left; Top=$r.Top; W=($r.Right-$r.Left); H=($r.Bottom-$r.Top)})
    }
  }
  return $true
}
[void][ProbeWin]::EnumWindows($cb, [IntPtr]::Zero)
$win = $windows | Sort-Object W -Descending | Select-Object -First 1
if (-not $win) { throw 'no NshWindow' }
[void][ProbeWin]::ShowWindow($win.Handle, 9)
[void][ProbeWin]::SetWindowPos($win.Handle, [IntPtr]::Zero, 60, 60, 1600, 1000, 0x0004)
[void][ProbeWin]::SetForegroundWindow($win.Handle)
Start-Sleep -Milliseconds 800
$r = New-Object ProbeWin+RECT; [void][ProbeWin]::GetWindowRect($win.Handle, [ref]$r)
if ($ClickX -ge 0) {
  [void][ProbeWin]::Click($r.Left + $ClickX, $r.Top + $ClickY)
  Start-Sleep -Milliseconds $SleepMs
}
$w = $r.Right - $r.Left; $h = $r.Bottom - $r.Top
$bmp = New-Object System.Drawing.Bitmap $w, $h
$g = [System.Drawing.Graphics]::FromImage($bmp)
$hdc = $g.GetHdc()
$ok = [ProbeWin]::PrintWindow($win.Handle, $hdc, 2)
$g.ReleaseHdc($hdc); $g.Dispose()
$bmp.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
"captured=$ok title=$($win.Title) size=${w}x${h} out=$Out"
