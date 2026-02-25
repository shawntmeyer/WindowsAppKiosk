Function Remove-DefaultPasswordFromLSASecrets {

    Add-Type @"
using System;
using System.Runtime.InteropServices;

public class LSA {
    [DllImport("advapi32.dll", SetLastError = true)]
    public static extern uint LsaOpenPolicy(
        IntPtr SystemName,
        ref LSA_OBJECT_ATTRIBUTES ObjectAttributes,
        uint DesiredAccess,
        out IntPtr PolicyHandle
    );

    [DllImport("advapi32.dll", SetLastError = true)]
    public static extern uint LsaStorePrivateData(
        IntPtr PolicyHandle,
        ref LSA_UNICODE_STRING KeyName,
        IntPtr PrivateData
    );

    [DllImport("advapi32.dll")]
    public static extern uint LsaClose(IntPtr PolicyHandle);

    [StructLayout(LayoutKind.Sequential)]
    public struct LSA_OBJECT_ATTRIBUTES {
        public uint Length;
        public IntPtr RootDirectory;
        public IntPtr ObjectName;
        public uint Attributes;
        public IntPtr SecurityDescriptor;
        public IntPtr SecurityQualityOfService;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct LSA_UNICODE_STRING {
        public ushort Length;
        public ushort MaximumLength;
        public IntPtr Buffer;
    }
}
"@

    $attrs = New-Object LSA+LSA_OBJECT_ATTRIBUTES
    $policy = [IntPtr]::Zero
    $buffer = [IntPtr]::Zero

    Try {
        # Open LSA policy
        $result = [LSA]::LsaOpenPolicy(
            [IntPtr]::Zero,
            [ref]$attrs,
            0x00000002, # POLICY_CREATE_SECRET
            [ref]$policy
        )

        # STATUS_SUCCESS = 0
        If ($result -ne 0) {
            Throw "LsaOpenPolicy failed with status: 0x$($result.ToString('X8'))"
        }

        # Create Unicode string for secret name
        $secretName = "DefaultPassword"
        $unicode = New-Object LSA+LSA_UNICODE_STRING
        $buffer = [Runtime.InteropServices.Marshal]::StringToHGlobalUni($secretName)
        $unicode.Buffer = $buffer
        $unicode.Length = $secretName.Length * 2
        $unicode.MaximumLength = $unicode.Length + 2

        # Delete the secret (passing NULL as data)
        $result = [LSA]::LsaStorePrivateData($policy, [ref]$unicode, [IntPtr]::Zero)

        # STATUS_SUCCESS = 0x00000000
        # STATUS_OBJECT_NAME_NOT_FOUND = 0xC0000034
        If ($result -eq 0) {
            Write-Verbose "DefaultPassword secret deleted successfully from LSA secrets."
        }
        ElseIf ($result -eq 0xC0000034) {
            Write-Verbose "DefaultPassword secret not found in LSA secrets (already removed or never existed)."
        }
        Else {
            Throw "LsaStorePrivateData failed with status: 0x$($result.ToString('X8'))"
        }
    }
    Finally {
        # Clean up resources
        If ($buffer -ne [IntPtr]::Zero) {
            [Runtime.InteropServices.Marshal]::FreeHGlobal($buffer)
        }
        If ($policy -ne [IntPtr]::Zero) {
            [LSA]::LsaClose($policy) | Out-Null
        }
    }
}