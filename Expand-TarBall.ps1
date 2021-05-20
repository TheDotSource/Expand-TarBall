function Expand-TarBall {
    <#
    .SYNOPSIS
        Extract the specified tarball to a directory.

    .DESCRIPTION
        Extract the specified tarball to a directory.

        Using the following C# from ForeverZer0:
        https://gist.github.com/ForeverZer0/a2cd292bd2f3b5e114956c00bb6e872b

    .PARAMETER tarGz
        The source tarball archive to extract.

    .PARAMETER outputFolder
        The folder to extract the tarball contents to. Warning, this will overwrite anything in the output path.

    .INPUTS
        System.String. The archive to extract.

    .OUTPUTS
        None.

    .EXAMPLE
        Expand-TarBall -tarGz F:\example.tar.gz -outputFolder D:\extract

        Extract the contents of example.tar.gz to d:\extract

    .EXAMPLE
        Get-ChildItem -Path D:\archives | Expand-TarBall -outputFolder D:\expanded

        Extract the contents of all archives in d:\archives to d:\expanded. Warning, conflicting files and folders will be overwritten.

    .LINK

    .NOTES
        01           Alistair McNair          Initial version.

    #>

    Param
    (
        [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
        [string]$tarGz,
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [string]$outputFolder
    )

    begin {
        Write-Verbose ("Function start.")

        ## Add type definition
        $typeDefinition = @"
using System;
using System.IO;
using System.IO.Compression;
using System.Text;

    public class Tar
    {
        public static void ExtractTarGz(string filename, string outputDir)
        {
            using (var stream = File.OpenRead(filename))
                ExtractTarGz(stream, outputDir);
        }

        public static void ExtractTarGz(Stream stream, string outputDir)
        {
            // A GZipStream is not seekable, so copy it first to a MemoryStream
            using (var gzip = new GZipStream(stream, CompressionMode.Decompress))
            {
                const int chunk = 4096;
                using (var memStr = new MemoryStream())
                {
                    int read;
                    var buffer = new byte[chunk];
                    do
                    {
                        read = gzip.Read(buffer, 0, chunk);
                        memStr.Write(buffer, 0, read);
                    } while (read == chunk);

                    memStr.Seek(0, SeekOrigin.Begin);
                    ExtractTar(memStr, outputDir);
                }
            }
        }

        public static void ExtractTar(string filename, string outputDir)
        {
            using (var stream = File.OpenRead(filename))
                ExtractTar(stream, outputDir);
        }

        public static void ExtractTar(Stream stream, string outputDir)
        {
            var buffer = new byte[100];
            while (true)
            {
                stream.Read(buffer, 0, 100);
                var name = Encoding.ASCII.GetString(buffer).Trim('\0');
                if (String.IsNullOrWhiteSpace(name))
                    break;
                stream.Seek(24, SeekOrigin.Current);
                stream.Read(buffer, 0, 12);
                var size = Convert.ToInt64(Encoding.UTF8.GetString(buffer, 0, 12).Trim('\0').Trim(), 8);

                stream.Seek(376L, SeekOrigin.Current);

                var output = Path.Combine(outputDir, name);
                if (!Directory.Exists(Path.GetDirectoryName(output)))
                    Directory.CreateDirectory(Path.GetDirectoryName(output));
                if(!name.EndsWith("/"))
                {
                    using (var str = File.Open(output, FileMode.OpenOrCreate, FileAccess.Write))
                    {
                        var buf = new byte[size];
                        stream.Read(buf, 0, buf.Length);
                        str.Write(buf, 0, buf.Length);
                    }
                }

                var pos = stream.Position;

                var offset = 512 - (pos  % 512);
                if (offset == 512)
                    offset = 0;

                stream.Seek(offset, SeekOrigin.Current);
            }
        }
    }
"@

        ## Load assmebly if not already loaded.
        if (!("Tar" -as [type])) {

            Write-Verbose ("Loading assemblies.")

            try {
                Add-Type -TypeDefinition $typeDefinition -ReferencedAssemblies @("System.IO.FileSystem","System","System.IO","System.IO.Compression") -ErrorAction Stop
            } # try
            catch {
                throw ("Failed to load assembly. " + $_.exception.message)
            } # catch
        } # if

    } # begin


    process {

        Write-Verbose ("Processing file " + $tarGz)

        ## Check source file exists
        if (Test-Path -Path $tarGz) {

            ## Get file size
            $fileSize = [math]::Round(((Get-Item -Path $tarGz).length)/1MB,2)

            ## Perform extraction
            Write-Verbose ("Beginning extraction. Data size is " + $fileSize + " megabytes.")

            try {
                [tar]::ExtractTarGz($tarGz,$outputFolder) | Out-Null
                Write-Verbose ("Completed extraction.")
            } # try
            catch {
                throw ("Failed to extract tarball. " + $_.exception.message)
            } # catch
        } # if
        else {
            throw ("Source file was not found or is not accessible.")
        } # else

        Write-Verbose ("File complete.")

    } # process

    end {
        Write-Verbose ("Function complete.")
    } # end

} # function