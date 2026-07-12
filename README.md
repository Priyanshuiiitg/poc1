we have done some tremendous job but found my life really tough integrating that in our edge device....so what I have been doing in moy office regarding this that we already have an C# application where third part polaris so files were used for document rendering now replacing that I have placed z2t-engine in the res/ folder of that C# application and created all other C# files for document rendering using our x2t binary...so been using test native script only in our cs files....but when I am packaging the tpk and installing it on my edge device it is not working since it gives some permission denied error when it access/executes the x2t binary and below that some error logs like Systsme Diagnostics process stuff is spilled so dont know what is going what has to be done to fix it and also when i run ldd for that res/x2t-engine....x2t it shows not a dynamic executable please help me 



This is a classic Tizen OS .tpk security and sandboxing issue! You have successfully deployed the ARM64 binaries, but the Tizen Linux kernel is blocking execution because of how the .tpk (Tizen Package) was structured.

Here is exactly what is going wrong and how to fix it in your C# code:

1. Why you are getting "Permission Denied" in C#
In Tizen OS, anything you place inside the res/ (resource) folder of a .tpk is strictly treated as a static asset (like images or XML files). When Tizen Studio packages your .tpk, it strips the executable permissions (+x) from all files in the res/ folder. Furthermore, the res/ folder itself is often mounted by Tizen's security layer (Smack) as non-executable.

When your C# System.Diagnostics.Process.Start() tries to execute res/x2t-engine/server/FileConverter/bin/x2t, the Linux kernel instantly blocks it with EACCES (Permission denied) because the file is not marked as an executable.

The Fix: You cannot execute binaries directly from the res/ folder. When your C# app starts up, you must programmatically copy the x2t binaries from your read-only res/ folder into your application's writable data/ folder, grant them execute permissions, and then run them.

Here is the C# code to do that before you call Process.Start():

csharp
using System.Diagnostics;
using System.IO;
using Tizen.Applications;
// 1. Get the path to your data folder (where execution is allowed)
string resPath = Application.Current.DirectoryInfo.Resource + "x2t-engine";
string dataPath = Application.Current.DirectoryInfo.Data + "x2t-engine";
// 2. Copy the binaries to the data folder if they aren't there yet
if (!Directory.Exists(dataPath)) {
    // Note: You will need to write a recursive directory copy function here
    CopyDirectory(resPath, dataPath); 
}
string x2tBinaryPath = Path.Combine(dataPath, "server/FileConverter/bin/x2t");
// 3. Grant Executable Permissions via a bash command
Process chmod = new Process();
chmod.StartInfo.FileName = "chmod";
chmod.StartInfo.Arguments = $"+x \"{x2tBinaryPath}\"";
chmod.StartInfo.UseShellExecute = false;
chmod.Start();
chmod.WaitForExit();
2. Why you must set LD_LIBRARY_PATH in C#
When you run test-native.sh via the terminal, the bash script automatically exports the LD_LIBRARY_PATH so x2t knows where to find its .so library dependencies. If you are skipping the bash script and invoking x2t directly via C# System.Diagnostics.Process, you must pass that environment variable in C#, otherwise x2t will instantly crash.

csharp
Process x2tProcess = new Process();
x2tProcess.StartInfo.FileName = x2tBinaryPath;
x2tProcess.StartInfo.Arguments = "\"/path/to/input.docx\" \"/path/to/output.pdf\" \"<TaskQueueDataConvert>...\"";
x2tProcess.StartInfo.UseShellExecute = false;
// CRITICAL: Tell x2t where its dynamic libraries are!
string binDir = Path.Combine(dataPath, "server/FileConverter/bin");
x2tProcess.StartInfo.EnvironmentVariables["LD_LIBRARY_PATH"] = binDir;
x2tProcess.Start();
x2tProcess.WaitForExit();
3. Why ldd said "not a dynamic executable" on the Edge device
Tizen's built-in ldd command is often just a fragile shell script that expects binaries to be compiled strictly with Tizen's specific library toolchain. Because our x2t binary was compiled on a standard Linux ARM64 environment (Ubuntu/Debian), Tizen's ldd script gets confused by the slightly different ELF headers and bails out with "not a dynamic executable."

This is completely harmless! As we proved yesterday with readelf -d and the QEMU emulator, it is a valid dynamic executable. Once you fix the permissions using chmod +x in your C# code and set the LD_LIBRARY_PATH, the Tizen kernel will load and execute it perfectly!

7:16 PM
