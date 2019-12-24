# Source: http://www.powershellmagazine.com/2013/07/18/pstip-how-to-switch-off-display-with-powershell/

# Turn display off by calling WindowsAPI.

# SendMessage(HWND_BROADCAST, WM_SYSCOMMAND, SC_MONITORPOWER, POWER_OFF)
# HWND_BROADCAST Oxffff  If this parameter is HWND_BROADCAST ((HWND)0xffff), the message is sent to all top level windows in the system, including disabled or invisible unowned windows
# WM_SYSCOMMAND 0x0112   A window receives this message when the user chooses a command from the window menu (formerly know as the system or control menu) or when the user chooses the maximise button, minimise button, restore or close button.
# SC_MONITORPOWER 0xf170 Sets the state of the display. This command supports devices that have powersaving features, such as a battery powered personal computer. The IParam parameter can have the following values (-1 the display is powering on, 1 the display is going to low power and 2 the display is being switched off)
# POWER_OFF 0x0002


Add-Type -TypeDefinition '
using System;
using System.Runtime.InteropServices;

namespace Utilities {
   public static class Display 
   {
      [DllImport("user32.dll", CharSet = CharSet.Auto)]
      private static extern IntPtr SendMessage(
         IntPtr hWnd,
         UInt32 Msg,
         IntPtr wParam,
         IntPtr lParam
      );

      public static void PowerOff()
      {
         SendMessage(
            (IntPtr)0xffff, // HWND_BROADCAST
            0x0112,         // WM_SYSCOMMAND
            (IntPtr)0xf170, // SC_MONITORPOWER
            (IntPtr)0x0002  // POWER_OFF
         );
      }
   }
}
'

[Utilities.Display]::PowerOff()