<#
.SYNOPSIS
    PowerShell Project Export Script - Comprehensive project documentation generator for AI assistance

.DESCRIPTION
    This script generates comprehensive project documentation by exporting directory structures, 
    file contents, Azure infrastructure details, and integration inventories. The output is 
    optimized for AI model consumption with intelligent token-aware file splitting.

.PARAMETER IgnoreGitignoreForFiles
    Override gitignore restrictions for file content scanning (Feature 2 only).
    Useful for scanning protected files like .env, but respects universal ignore patterns.

.PARAMETER TokenLimit
    Token limit per output file for AI model compatibility (default: 200,000).
    Files are intelligently split across multiple parts to stay within specified limits.
    Common values: 200k (Claude API), 128k (GPT-4), 32k (GPT-3.5)

.PARAMETER Help
    Display comprehensive help information including usage examples and token guidance.

.EXAMPLE
    .\export-project.ps1
    Exports project with default settings (200k token limit, respects gitignore)

.EXAMPLE
    .\export-project.ps1 -TokenLimit 128000
    Exports project with GPT-4 compatible token limits

.EXAMPLE
    .\export-project.ps1 -IgnoreGitignoreForFiles
    Includes normally ignored files like .env (universal patterns still respected)

.NOTES
    Author: Enhanced PowerShell Export Tool
    Version: 2.0
    Features: Directory structure, file contents, Azure audit, integration inventory
    Output: Multiple timestamped files in ./exports/ directory
    
    The script creates 4 main features:
    1. Enhanced directory structure with statistics
    2. Token-aware file contents export (multi-file support)
    3. Azure infrastructure audit and pattern detection
    4. Integration inventory and dependency mapping

.LINK
    https://github.com/your-username/project-export-tool
#>

# =============================================================================
# SCRIPT PARAMETERS AND CONFIGURATION
# =============================================================================

# Command line parameters
param(
    [switch]$IgnoreGitignoreForFiles = $false,
    [int]$TokenLimit = 200000,
    [switch]$Help = $false
)

# =============================================================================
# HELP SYSTEM
# =============================================================================

<#
.DESCRIPTION
    Display comprehensive help information when -Help parameter is used.
    Shows usage examples, parameter descriptions, and token limit guidelines.
#>
if ($Help) {
    Write-Host "PowerShell Project Export Script - Enhanced Version" -ForegroundColor Green
    Write-Host ""
    Write-Host "Usage: .\export-project.ps1 [-IgnoreGitignoreForFiles] [-TokenLimit <number>] [-Help]" -ForegroundColor White
    Write-Host ""
    Write-Host "Parameters:" -ForegroundColor Yellow
    Write-Host "  -IgnoreGitignoreForFiles    Override gitignore for file content scanning (Feature 2 only)" -ForegroundColor White
    Write-Host "                              Useful for scanning .env, config files normally excluded" -ForegroundColor Gray
    Write-Host "                              Note: Directory structure (Feature 1) always respects gitignore" -ForegroundColor Gray
    Write-Host "  -TokenLimit <number>        Token limit per file for AI compatibility (default: 200000)" -ForegroundColor White
    Write-Host "                              File contents will be split across multiple files to stay within limits" -ForegroundColor Gray
    Write-Host "                              Recommended: 200k (Claude API), 128k (GPT-4), 32k (GPT-3.5)" -ForegroundColor Gray
    Write-Host "  -Help                       Show this help message" -ForegroundColor White
    Write-Host ""
    Write-Host "Features:" -ForegroundColor Yellow
    Write-Host "  1. Directory Structure Scan (always respects gitignore)" -ForegroundColor White
    Write-Host "  2. File Contents Export (optional gitignore override)" -ForegroundColor White
    Write-Host "  3. Azure Infrastructure Audit" -ForegroundColor White
    Write-Host "  4. Integration Inventory" -ForegroundColor White
    Write-Host ""
    Write-Host "Plus: Colorized summary dashboard and comprehensive error reporting" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Token Limit Guide:" -ForegroundColor Yellow
    Write-Host "  Claude API:  200,000 tokens → Use default" -ForegroundColor White
    Write-Host "  GPT-4:       128,000 tokens → Use -TokenLimit 128000" -ForegroundColor White
    Write-Host "  GPT-3.5:      32,000 tokens → Use -TokenLimit 32000" -ForegroundColor White
    Write-Host ""
    exit 0
}

# =============================================================================
# GLOBAL VARIABLES AND INITIALIZATION
# =============================================================================

<#
.DESCRIPTION
    Initialize global variables, detect operating system, and set up error tracking.
    These variables are used throughout the script for consistent behavior.
#>

# Detect operating system for path handling compatibility
# This handles differences between Windows PowerShell and PowerShell Core
$IsWindowsOS = $PSVersionTable.PSVersion.Major -ge 6 -and $PSVersionTable.Platform -eq "Win32NT" -or $PSVersionTable.PSVersion.Major -lt 6

# Generate timestamp for unique file naming
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"

# Initialize error tracking and feature success flags
$errors = @()                    # Collect all errors for final report
$feature1Success = $true         # Directory structure scan status
$feature2Success = $true         # File contents export status  
$feature3Success = $true         # Azure infrastructure audit status
$feature4Success = $true         # Integration inventory status
$contentsFiles = @()             # Track multiple content files for token-aware splitting

# =============================================================================
# OUTPUT DIRECTORY AND FILE SETUP
# =============================================================================

<#
.DESCRIPTION
    Create the exports directory and define output file paths.
    All generated files use timestamps to prevent overwrites.
#>

# Ensure exports directory exists for output files
if (!(Test-Path -Path "./exports")) {
    try {
        New-Item -ItemType Directory -Path "./exports" -Force | Out-Null
        Write-Host "Created exports directory" -ForegroundColor Green
    }
    catch {
        $errors += "Failed to create exports directory: $($_.Exception.Message)"
        Write-Host "ERROR: Failed to create exports directory" -ForegroundColor Red
        exit 1
    }
}

# Define output file paths with timestamp for uniqueness
$structureFile = "./exports/structure-$timestamp.txt"           # Feature 1: Directory structure
$contentsFileBase = "./exports/filecontents-$timestamp"         # Feature 2: File contents (may have multiple parts)
$errorFile = "./exports/export-$timestamp-errors.txt"          # Error log if any issues occur
$azureFile = "./exports/azure-audit-$timestamp.txt"            # Feature 3: Azure infrastructure
$integrationFile = "./exports/integrations-$timestamp.txt"     # Feature 4: Integration inventory

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

<#
.SYNOPSIS
    Parse .gitignore file and extract ignore patterns.

.DESCRIPTION
    Reads the .gitignore file in the current directory and extracts all
    non-comment, non-empty lines as ignore patterns. These patterns are
    used to exclude files and directories from processing.

.OUTPUTS
    Array of strings containing gitignore patterns.

.NOTES
    Handles missing .gitignore files gracefully and logs appropriate messages.
#>
function Get-GitignorePatterns {
    $gitignorePatterns = @()
    
    if (Test-Path ".gitignore") {
        try {
            $gitignoreContent = Get-Content ".gitignore" -ErrorAction Stop
            foreach ($line in $gitignoreContent) {
                $line = $line.Trim()
                # Skip empty lines and comments (lines starting with #)
                if ($line -and !$line.StartsWith("#")) {
                    $gitignorePatterns += $line
                }
            }
            Write-Host "Loaded $($gitignorePatterns.Count) patterns from .gitignore" -ForegroundColor Green
        }
        catch {
            $errors += "Failed to read .gitignore file: $($_.Exception.Message)"
            Write-Host "WARNING: Could not read .gitignore file" -ForegroundColor Yellow
        }
    }
    else {
        Write-Host "No .gitignore file found - proceeding without ignore patterns" -ForegroundColor Yellow
    }
    
    return $gitignorePatterns
}

<#
.SYNOPSIS
    Determine if a file or directory path should be ignored during processing.

.DESCRIPTION
    Checks if a given path matches any gitignore patterns or universal ignore patterns.
    Universal patterns (like node_modules) are always ignored regardless of gitignore override.
    Supports wildcard patterns, directory patterns (ending with /), and exact matches.

.PARAMETER Path
    The full file or directory path to check.

.PARAMETER IgnorePatterns
    Array of gitignore patterns to check against.

.PARAMETER UniversalIgnorePatterns
    Array of universal patterns that are always ignored (node_modules, .git, etc.).

.OUTPUTS
    Boolean - True if the path should be ignored, False otherwise.

.NOTES
    Universal ignore patterns take precedence to prevent processing massive directories
    that would make output files unusably large.
#>
function Test-ShouldIgnore {
    param(
        [string]$Path,
        [array]$IgnorePatterns,
        [array]$UniversalIgnorePatterns
    )
    
    # Convert to relative path and normalize separators
    $relativePath = $Path -replace [regex]::Escape($PWD.Path), ""
    $relativePath = $relativePath.TrimStart("\", "/")
    $relativePath = $relativePath -replace "\\", "/"
    
    # Check universal ignore patterns first (always ignored regardless of gitignore override)
    foreach ($pattern in $UniversalIgnorePatterns) {
        if ($pattern.EndsWith("/")) {
            $dirPattern = $pattern.TrimEnd("/")
            if ($relativePath -like "*$dirPattern*") {
                return $true
            }
        }
        elseif ($pattern.Contains("*")) {
            if ($relativePath -like $pattern) {
                return $true
            }
        }
        else {
            # Enhanced pattern matching for nested directories
            # Check if the path contains the pattern as a directory name anywhere in the path
            $pathParts = $relativePath -split "/"
            foreach ($part in $pathParts) {
                if ($part -eq $pattern) {
                    return $true
                }
            }
            
            # Also check traditional patterns for backward compatibility
            if ($relativePath -eq $pattern -or $relativePath -like "*/$pattern" -or $relativePath -like "*/$pattern/*" -or $relativePath -like "$pattern/*") {
                return $true
            }
        }
    }
    
    # Then check gitignore patterns
    foreach ($pattern in $IgnorePatterns) {
        # Handle directory patterns (ending with /)
        if ($pattern.EndsWith("/")) {
            $dirPattern = $pattern.TrimEnd("/")
            if ($relativePath -like "*$dirPattern*") {
                return $true
            }
        }
        # Handle wildcard patterns
        elseif ($pattern.Contains("*")) {
            if ($relativePath -like $pattern) {
                return $true
            }
        }
        # Handle exact matches and path segments
        else {
            if ($relativePath -eq $pattern -or $relativePath -like "*/$pattern" -or $relativePath -like "*/$pattern/*" -or $relativePath -like "$pattern/*") {
                return $true
            }
        }
    }
    
    return $false
}

<#
.SYNOPSIS
    Check if a file is binary by scanning for null bytes.

.DESCRIPTION
    Reads the first 1KB of a file to detect null bytes, which indicate binary content.
    Uses cross-platform .NET methods for Windows path compatibility.

.PARAMETER FilePath
    Full path to the file to check.

.OUTPUTS
    Boolean - True if file appears to be binary, False if text.
#>
function Test-IsBinaryFile {
    param([string]$FilePath)
    
    try {
        # Use .NET method which handles Windows paths better than PowerShell cmdlets
        if (-not [System.IO.File]::Exists($FilePath)) {
            return $true  # Assume binary if file doesn't exist
        }
        
        # Read first 1KB to check for null bytes
        $bytes = [System.IO.File]::ReadAllBytes($FilePath)
        if ($bytes.Length -eq 0) {
            return $false
        }
        
        $sampleSize = [Math]::Min(1024, $bytes.Length)
        $sample = $bytes[0..($sampleSize - 1)]
        
        # Check for null bytes (indicator of binary file)
        return ($sample -contains 0)
    }
    catch {
        return $true # Assume binary if we can't read it
    }
}

<#
.SYNOPSIS
    Estimate token count for AI model compatibility.

.DESCRIPTION
    Provides approximate token count using 4:1 character-to-token ratio with 10% safety buffer.
    Used for intelligent file splitting to stay within AI model limits.

.PARAMETER Text
    The text content to analyze for token count.

.OUTPUTS
    Integer - Estimated token count with safety buffer included.
#>
function Get-TokenCount {
    param([string]$Text)
    
    if ([string]::IsNullOrEmpty($Text)) {
        return 0
    }
    
    # Rough approximation: 1 token ≈ 4 characters for English text
    # This varies by tokenizer but provides a conservative estimate
    # Adding 10% buffer for safety
    $charCount = $Text.Length
    $estimatedTokens = [Math]::Ceiling($charCount / 4 * 1.1)
    
    return $estimatedTokens
}

# =============================================================================
# MAIN EXECUTION START
# =============================================================================

Write-Host "Starting enhanced project export process..." -ForegroundColor Green
Write-Host "Timestamp: $timestamp"
Write-Host "Token Limit: $TokenLimit tokens per file (for AI model compatibility)" -ForegroundColor Cyan
if ($IgnoreGitignoreForFiles) {
    Write-Host "Override Mode: Will scan ALL files including those in .gitignore" -ForegroundColor Yellow
    Write-Host "Note: Directory structure will still respect .gitignore to avoid massive outputs" -ForegroundColor Gray
}

# Load gitignore patterns
$ignorePatterns = Get-GitignorePatterns

# Universal ignore patterns (always ignored, regardless of gitignore override)
$universalIgnorePatterns = @(
    'node_modules',
    '.git',
    'dist',
    'build',
    '.next',
    '.nuxt',
    'target',
    'bin',
    'obj',
    '.vercel',
    '.cache',
    '.tmp',
    'tmp',
    'temp',
    '.DS_Store',
    'Thumbs.db',
    '*.lock',
    'package-lock.json',
    'yarn.lock',
    'pnpm-lock.yaml',
    'npm-shrinkwrap.json',
    'composer.lock',
    'Pipfile.lock',
    'Gemfile.lock',
    'go.sum',
    'coverage',
    '.nyc_output',
    '.sass-cache',
    '.vscode',
    '.idea',
    '*.log',
    '.env.local',
    '.env.*.local',
    '.pnpm-store',
    'vendor',
    '__pycache__',
    '.pytest_cache'
)

Write-Host "Universal ignore patterns loaded: $($universalIgnorePatterns.Count) patterns"

# FEATURE 1: Directory Structure Scan
Write-Host "`n--- FEATURE 1: Directory Structure Scan ---" -ForegroundColor Cyan

try {
    $structureOutput = @()
    $structureOutput += "Enhanced Directory Structure Export"
    $structureOutput += "Generated: $(Get-Date)"
    $structureOutput += "Root: $($PWD.Path)"
    $structureOutput += "=" * 50
    $structureOutput += ""
    
    # Get all directories and files recursively, excluding gitignored and universally ignored ones
    $directories = Get-ChildItem -Path "." -Recurse -Directory -Force | Where-Object {
        -not (Test-ShouldIgnore -Path $_.FullName -IgnorePatterns $ignorePatterns -UniversalIgnorePatterns $universalIgnorePatterns)
    }
    
    $files = Get-ChildItem -Path "." -Recurse -File -Force | Where-Object {
        -not (Test-ShouldIgnore -Path $_.FullName -IgnorePatterns $ignorePatterns -UniversalIgnorePatterns $universalIgnorePatterns)
    }
    
    # Create a hierarchical structure
    $structure = @{}
    
    # Add root directory
    $structure["."] = @{
        'Type' = 'Directory'
        'Files' = @()
        'Size' = 0
        'Children' = @{}
    }
    
    # Process directories
    foreach ($dir in $directories) {
        $relativePath = ($dir.FullName -replace [regex]::Escape($PWD.Path), ".") -replace "\\", "/"
        $pathParts = $relativePath -split "/"
        
        $current = $structure["."]
        for ($i = 1; $i -lt $pathParts.Length; $i++) {
            $part = $pathParts[$i]
            if (-not $current.Children.ContainsKey($part)) {
                $current.Children[$part] = @{
                    'Type' = 'Directory'
                    'Files' = @()
                    'Size' = 0
                    'Children' = @{}
                }
            }
            $current = $current.Children[$part]
        }
    }
    
    # Process files and add to structure
    foreach ($file in $files) {
        $relativePath = ($file.FullName -replace [regex]::Escape($PWD.Path), ".") -replace "\\", "/"
        $pathParts = $relativePath -split "/"
        $fileName = $pathParts[-1]
        
        $current = $structure["."]
        for ($i = 1; $i -lt ($pathParts.Length - 1); $i++) {
            $part = $pathParts[$i]
            if ($current.Children.ContainsKey($part)) {
                $current = $current.Children[$part]
            }
        }
        
        $current.Files += @{
            'Name' = $fileName
            'Size' = $file.Length
            'Extension' = $file.Extension
            'Modified' = $file.LastWriteTime
        }
        $current.Size += $file.Length
    }
    
    # Function to render tree structure
    function Render-TreeStructure {
        param($node, $name, $prefix = "", $isLast = $true)
        
        if ($isLast) {
            $connector = "└── "
        } else {
            $connector = "├── "
        }
        $result = @()
        
        if ($name -ne ".") {
            $fileCount = $node.Files.Count
            $dirCount = $node.Children.Count
            $sizeKB = [Math]::Round($node.Size / 1024, 1)
            
            $result += "$prefix$connector$name/ ($fileCount files, $dirCount dirs, $sizeKB KB)"
        } else {
            $totalFiles = ($files | Measure-Object).Count
            $totalDirs = ($directories | Measure-Object).Count + 1
            $totalSizeKB = [Math]::Round(($files | Measure-Object -Property Length -Sum).Sum / 1024, 1)
            
            $result += "$name (Project Root - $totalFiles files, $totalDirs dirs, $totalSizeKB KB total)"
        }
        
        if ($name -eq ".") {
            $nextPrefix = ""
        } else {
            if ($isLast) {
                $nextPrefix = $prefix + "    "
            } else {
                $nextPrefix = $prefix + "│   "
            }
        }
        
        # Add files first
        $sortedFiles = $node.Files | Sort-Object Name
        for ($i = 0; $i -lt $sortedFiles.Count; $i++) {
            $file = $sortedFiles[$i]
            $isLastFile = ($i -eq ($sortedFiles.Count - 1)) -and ($node.Children.Count -eq 0)
            if ($isLastFile) {
                $fileConnector = "└── "
            } else {
                $fileConnector = "├── "
            }
            $fileSizeKB = [Math]::Round($file.Size / 1024, 1)
            $result += "$nextPrefix$fileConnector$($file.Name) ($fileSizeKB KB)"
        }
        
        # Add subdirectories
        $sortedChildren = $node.Children.GetEnumerator() | Sort-Object Name
        $childrenArray = @($sortedChildren)
        for ($i = 0; $i -lt $childrenArray.Count; $i++) {
            $child = $childrenArray[$i]
            $isLastChild = ($i -eq ($childrenArray.Count - 1))
            $result += Render-TreeStructure -node $child.Value -name $child.Key -prefix $nextPrefix -isLast $isLastChild
        }
        
        return $result
    }
    
    # Generate tree structure
    $treeOutput = Render-TreeStructure -node $structure["."] -name "."
    $structureOutput += $treeOutput
    $structureOutput += ""
    
    # Add file type summary
    $fileTypes = @{}
    foreach ($file in $files) {
        $ext = if ($file.Extension) { $file.Extension.ToLower() } else { '[no extension]' }
        if ($fileTypes.ContainsKey($ext)) {
            $fileTypes[$ext]++
        } else {
            $fileTypes[$ext] = 1
        }
    }
    
    $structureOutput += "FILE TYPE SUMMARY"
    $structureOutput += "=" * 17
    $sortedTypes = $fileTypes.GetEnumerator() | Sort-Object Value -Descending
    foreach ($type in $sortedTypes) {
        $structureOutput += "$($type.Key): $($type.Value) files"
    }
    $structureOutput += ""
    
    # Add directory statistics
    $structureOutput += "DIRECTORY STATISTICS"
    $structureOutput += "=" * 20
    
    function Get-DirectoryStats {
        param($node, $path)
        $stats = @()
        
        if ($path -ne ".") {
            $fileCount = $node.Files.Count
            $dirCount = $node.Children.Count
            $sizeKB = [Math]::Round($node.Size / 1024, 1)
            
            $stats += @{
                'Path' = $path
                'Files' = $fileCount
                'Directories' = $dirCount
                'SizeKB' = $sizeKB
            }
        }
        
        foreach ($child in $node.Children.GetEnumerator()) {
            if ($path -eq ".") {
                $childPath = $child.Key
            } else {
                $childPath = "$path/$($child.Key)"
            }
            $stats += Get-DirectoryStats -node $child.Value -path $childPath
        }
        
        return $stats
    }
    
    $dirStats = Get-DirectoryStats -node $structure["."] -path "."
    $topDirs = $dirStats | Sort-Object Files -Descending | Select-Object -First 10
    
    foreach ($dir in $topDirs) {
        $structureOutput += "$($dir.Path): $($dir.Files) files, $($dir.Directories) subdirs, $($dir.SizeKB) KB"
    }
    
    # Write structure to file
    $structureOutput | Out-File -FilePath $structureFile -Encoding UTF8
    Write-Host "Enhanced directory structure exported to: $structureFile" -ForegroundColor Green
    Write-Host "Processed $($directories.Count + 1) directories, $($files.Count) files"
    Write-Host "File types found: $($fileTypes.Count)"
}
catch {
    $feature1Success = $false
    $errorMsg = "Feature 1 error: $($_.Exception.Message)"
    $errors += $errorMsg
    Write-Host "ERROR: $errorMsg" -ForegroundColor Red
}

# FEATURE 2: File Contents Scan (Token-Aware Multi-File Export)
Write-Host "`n--- FEATURE 2: File Contents Scan ---" -ForegroundColor Cyan

try {
    # Get all files recursively - respect or ignore gitignore based on parameter
    # Universal ignore patterns are ALWAYS respected to prevent massive outputs
    if ($IgnoreGitignoreForFiles) {
        $allFiles = Get-ChildItem -Path "." -Recurse -File -Force | Where-Object {
            -not (Test-ShouldIgnore -Path $_.FullName -IgnorePatterns @() -UniversalIgnorePatterns $universalIgnorePatterns)
        }
        Write-Host "Scanning ALL files (gitignore override enabled, universal patterns still respected)" -ForegroundColor Yellow
    }
    else {
        $allFiles = Get-ChildItem -Path "." -Recurse -File -Force | Where-Object {
            -not (Test-ShouldIgnore -Path $_.FullName -IgnorePatterns $ignorePatterns -UniversalIgnorePatterns $universalIgnorePatterns)
        }
        Write-Host "Scanning files (respecting gitignore + universal patterns)" -ForegroundColor Green
    }
    
    Write-Host "Found $($allFiles.Count) files to process"
    Write-Host "Token limit: $TokenLimit tokens per output file" -ForegroundColor Cyan
    
    # Initialize tracking variables
    $processedCount = 0
    $binaryCount = 0
    $errorCount = 0
    $currentPartNumber = 1
    $currentTokenCount = 0
    $contentsOutput = @()
    
    # Create header for first file
    function New-FileHeader {
        param($partNumber, $totalParts = "TBD")
        $headerOutput = @()
        $headerOutput += "File Contents Export - Part $partNumber of $totalParts"
        $headerOutput += "Generated: $(Get-Date)"
        $headerOutput += "Root: $($PWD.Path)"
        $headerOutput += "Token Limit: $TokenLimit tokens per file"
        $headerOutput += "=" * 50
        $headerOutput += ""
        return $headerOutput
    }
    
    # Start first file
    $contentsOutput = New-FileHeader -partNumber $currentPartNumber
    $headerTokens = Get-TokenCount -Text ($contentsOutput -join "`n")
    $currentTokenCount = $headerTokens
    
    Write-Host "Processing files with intelligent token-aware splitting..." -ForegroundColor Green
    
    foreach ($file in $allFiles) {
        $relativePath = $file.FullName -replace [regex]::Escape($PWD.Path), "."
        $relativePath = $relativePath -replace "\\", "/"
        
        # Build file entry
        $fileEntry = @()
        $fileEntry += ""
        $fileEntry += "=" * 80
        $fileEntry += "FILE: $($file.Name)"
        $fileEntry += "PATH: $relativePath"
        $fileEntry += "SIZE: $($file.Length) bytes"
        $fileEntry += "MODIFIED: $($file.LastWriteTime)"
        $fileEntry += "=" * 80
        
        $fileContent = ""
        
        try {
            # Check if file exists and can be accessed
            # Use literal path to handle special characters like brackets on Windows
            $fileExists = $false
            try {
                $fileExists = Test-Path -LiteralPath $file.FullName -PathType Leaf
            }
            catch {
                # If LiteralPath fails, try alternative method for Windows
                $fileExists = [System.IO.File]::Exists($file.FullName)
            }
            
            if (-not $fileExists) {
                # Check if this is a Windows bracket filename issue
                if ($file.Name -match '\[.*\]' -and $IsWindowsOS) {
                    $fileContent = "[WINDOWS PATH ISSUE: File contains brackets - may not be accessible on Windows filesystem]`n[FILE PATH: $relativePath]"
                    Write-Host "Windows bracket path issue: $relativePath" -ForegroundColor Yellow
                } else {
                    $errorMsg = "File not found or inaccessible: $relativePath"
                    $errors += $errorMsg
                    $fileContent = "[ERROR: FILE NOT FOUND OR INACCESSIBLE]"
                    Write-Host "File not accessible: $relativePath" -ForegroundColor Red
                }
                $errorCount++
            }
            elseif (Test-IsBinaryFile -FilePath $file.FullName) {
                $fileContent = "[BINARY FILE - CONTENT NOT DISPLAYED]"
                $binaryCount++
                Write-Host "Binary file: $relativePath" -ForegroundColor Yellow
            }
            else {
                # Read text file content with better error handling and Windows compatibility
                try {
                    # Try LiteralPath first for Windows bracket compatibility
                    $content = $null
                    try {
                        $content = Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8 -ErrorAction Stop
                    }
                    catch {
                        # Fallback to regular Path parameter
                        $content = Get-Content -Path $file.FullName -Raw -Encoding UTF8 -ErrorAction Stop
                    }
                    
                    if ($null -eq $content -or $content.Length -eq 0) {
                        $fileContent = "[EMPTY FILE]"
                    }
                    else {
                        $fileContent = $content
                    }
                    $processedCount++
                }
                catch [System.UnauthorizedAccessException] {
                    $fileContent = "[ERROR: ACCESS DENIED]"
                    $errorCount++
                    Write-Host "Access denied: $relativePath" -ForegroundColor Red
                }
                catch [System.IO.FileNotFoundException] {
                    $fileContent = "[ERROR: FILE NOT FOUND]"
                    $errorCount++
                    Write-Host "File disappeared: $relativePath" -ForegroundColor Red
                }
                catch {
                    $fileContent = "[ERROR READING FILE: $($_.Exception.Message)]"
                    $errorCount++
                    Write-Host "Read error: $relativePath" -ForegroundColor Red
                }
            }
        }
        catch {
            $errorMsg = "Could not process file $relativePath`: $($_.Exception.Message)"
            $errors += $errorMsg
            $fileContent = "[ERROR PROCESSING FILE: $($_.Exception.Message)]"
            $errorCount++
            Write-Host "Processing error: $relativePath" -ForegroundColor Red
        }
        
        # Combine file entry with content
        $fullFileEntry = $fileEntry + @($fileContent)
        $fullFileEntryText = $fullFileEntry -join "`n"
        
        # Calculate tokens for this complete file entry
        $fileTokens = Get-TokenCount -Text $fullFileEntryText
        
        # Check if adding this file would exceed token limit
        # Leave 10% buffer for safety
        $bufferLimit = [Math]::Floor($TokenLimit * 0.9)
        
        if (($currentTokenCount + $fileTokens) -gt $bufferLimit -and $contentsOutput.Count -gt 6) {
            # Need to start a new file - but only if current file isn't mostly empty
            # Save current file
            $currentFileName = "$contentsFileBase-part$currentPartNumber.txt"
            $contentsOutput | Out-File -FilePath $currentFileName -Encoding UTF8
            $contentsFiles += $currentFileName
            
            Write-Host "Part $currentPartNumber completed: $currentTokenCount tokens → $currentFileName" -ForegroundColor Green
            
            # Start new file
            $currentPartNumber++
            $contentsOutput = New-FileHeader -partNumber $currentPartNumber
            $currentTokenCount = Get-TokenCount -Text ($contentsOutput -join "`n")
        }
        
        # Add file to current output
        $contentsOutput += $fullFileEntry
        $currentTokenCount += $fileTokens
        
        # Show progress every 10 files
        if (($processedCount + $binaryCount + $errorCount) % 10 -eq 0) {
            Write-Host "Processed: $($processedCount + $binaryCount + $errorCount)/$($allFiles.Count) | Current: $currentTokenCount tokens" -ForegroundColor Gray
        }
    }
    
    # Save final file
    if ($contentsOutput.Count -gt 6) {  # Only save if it has content beyond header
        $finalFileName = "$contentsFileBase-part$currentPartNumber.txt"
        $contentsOutput | Out-File -FilePath $finalFileName -Encoding UTF8
        $contentsFiles += $finalFileName
        Write-Host "Part $currentPartNumber completed: $currentTokenCount tokens → $finalFileName" -ForegroundColor Green
    }
    
    # Update all headers with correct total parts count
    for ($i = 0; $i -lt $contentsFiles.Count; $i++) {
        $partNum = $i + 1
        $totalParts = $contentsFiles.Count
        
        # Read file content
        $fileContent = Get-Content -Path $contentsFiles[$i] -Raw -Encoding UTF8
        
        # Replace the header line with total parts
        $updatedContent = $fileContent -replace "Part $partNum of TBD", "Part $partNum of $totalParts"
        
        # Write back
        $updatedContent | Out-File -FilePath $contentsFiles[$i] -Encoding UTF8
    }
    
    Write-Host "`n=== FILE CONTENTS EXPORT SUMMARY ===" -ForegroundColor Green
    Write-Host "Total output files created: $($contentsFiles.Count)" -ForegroundColor Cyan
    Write-Host "Text files processed: $processedCount" -ForegroundColor White
    Write-Host "Binary files found: $binaryCount" -ForegroundColor White
    Write-Host "Files with errors: $errorCount" -ForegroundColor White
    Write-Host "Token limit per file: $TokenLimit" -ForegroundColor White
    
    foreach ($file in $contentsFiles) {
        $partName = Split-Path $file -Leaf
        Write-Host "✅ Created: $partName" -ForegroundColor Green
    }
}
catch {
    $feature2Success = $false
    $errorMsg = "Feature 2 error: $($_.Exception.Message)"
    $errors += $errorMsg
    Write-Host "ERROR: $errorMsg" -ForegroundColor Red
}

# FEATURE 3: Azure Infrastructure Audit
Write-Host "`n--- FEATURE 3: Azure Infrastructure Audit ---" -ForegroundColor Cyan

try {
    $azureOutput = @()
    $azureOutput += "Azure Infrastructure Audit"
    $azureOutput += "Generated: $(Get-Date)"
    $azureOutput += "Root: $($PWD.Path)"
    $azureOutput += "=" * 50
    $azureOutput += ""
    
    # Azure-related file patterns to search for
    $azurePatterns = @{
        'Configuration Files' = @('*.config', 'appsettings*.json', 'azure-pipelines*.yml', 'azure-pipelines*.yaml', '*.arm', '*.template.json')
        'Environment Files' = @('.env*', '*.env', 'local.settings.json')
        'Docker Files' = @('Dockerfile*', 'docker-compose*.yml', 'docker-compose*.yaml')
        'Infrastructure as Code' = @('*.bicep', '*.arm', '*.tf', '*.terraform', '*.template.json', 'main.bicep', 'azuredeploy.json')
        'Azure Export Files' = @('*azure-export*', '*deployment-template*', '*parameters.json', '*azure-resources*')
        'Key Vault References' = @()
        'Connection Strings' = @()
        'Azure Services' = @()
        'Terraform Azure' = @()
    }
    
    $azureFindings = @{}
    
    # Search for Azure configuration files
    foreach ($category in $azurePatterns.Keys) {
        $azureFindings[$category] = @()
        
        if ($azurePatterns[$category].Count -gt 0) {
            foreach ($pattern in $azurePatterns[$category]) {
                $files = Get-ChildItem -Path "." -Recurse -Filter $pattern -File -ErrorAction SilentlyContinue
                foreach ($file in $files) {
                    $relativePath = $file.FullName -replace [regex]::Escape($PWD.Path), "."
                    $relativePath = $relativePath -replace "\\", "/"
                    $azureFindings[$category] += @{
                        'Path' = $relativePath
                        'Size' = $file.Length
                        'Modified' = $file.LastWriteTime
                    }
                }
            }
        }
    }
    
    # Search file contents for Azure-specific patterns
    $searchPatterns = @{
        'Key Vault References' = @('vault\.azure\.net', 'KeyVault', '@Microsoft\.KeyVault', 'vault\.azure\.cn', 'secrets\.', 'keyvault', 'vaultUri')
        'Connection Strings' = @('Server=.*\.database\.windows\.net', 'AccountName=.*\.blob\.core\.windows\.net', 'servicebus\.windows\.net', 'database\.windows\.net', 'blob\.core\.windows\.net', 'table\.core\.windows\.net', 'queue\.core\.windows\.net')
        'Azure Services' = @('\.azurewebsites\.net', '\.azure\.com', 'azure-api\.net', 'applicationinsights', 'ServiceBus', 'CosmosDB', 'BlobStorage', 'AppService', 'FunctionApp', 'LogicApp', 'EventHub', 'ServiceFabric')
        'Terraform Azure' = @('azurerm_', 'provider\s+"azurerm"', 'resource_group_name', 'location\s*=\s*".*azure.*"', 'subscription_id')
    }
    
    # Get a subset of files to search through for Azure patterns
    $searchFiles = Get-ChildItem -Path "." -Recurse -File -Force | Where-Object {
        $_.Extension -in @('.json', '.js', '.ts', '.cs', '.config', '.yml', '.yaml', '.env', '.ps1', '.md', '.txt', '.bicep', '.tf', '.arm') -and
        $_.Length -lt 5MB -and
        (-not (Test-ShouldIgnore -Path $_.FullName -IgnorePatterns $(if ($IgnoreGitignoreForFiles) { @() } else { $ignorePatterns }) -UniversalIgnorePatterns $universalIgnorePatterns))
    } | Select-Object -First 200  # Increased limit for better Azure detection
    
    foreach ($category in $searchPatterns.Keys) {
        foreach ($file in $searchFiles) {
            try {
                $content = Get-Content -Path $file.FullName -Raw -ErrorAction SilentlyContinue
                if ($content) {
                    foreach ($pattern in $searchPatterns[$category]) {
                        if ($content -match $pattern) {
                            $relativePath = $file.FullName -replace [regex]::Escape($PWD.Path), "."
                            $relativePath = $relativePath -replace "\\", "/"
                            
                            $existing = $azureFindings[$category] | Where-Object { $_.Path -eq $relativePath }
                            if (-not $existing) {
                                $azureFindings[$category] += @{
                                    'Path' = $relativePath
                                    'Pattern' = $pattern
                                    'Size' = $file.Length
                                    'Modified' = $file.LastWriteTime
                                }
                            }
                            break
                        }
                    }
                }
            }
            catch {
                # Silently continue if file can't be read
            }
        }
    }
    
    # Generate output
    $azureOutput += "AZURE INFRASTRUCTURE SUMMARY"
    $azureOutput += "=" * 30
    
    $totalFindings = 0
    foreach ($category in $azureFindings.Keys) {
        $count = $azureFindings[$category].Count
        $totalFindings += $count
        $azureOutput += "$category`: $count items found"
    }
    
    $azureOutput += ""
    $azureOutput += "Total Azure-related items: $totalFindings"
    $azureOutput += ""
    
    # Detailed findings
    foreach ($category in $azureFindings.Keys) {
        if ($azureFindings[$category].Count -gt 0) {
            $azureOutput += ""
            $azureOutput += "$category"
            $azureOutput += "-" * $category.Length
            
            foreach ($finding in $azureFindings[$category]) {
                $azureOutput += "  File: $($finding.Path)"
                if ($finding.Pattern) {
                    $azureOutput += "    Pattern: $($finding.Pattern)"
                }
                $azureOutput += "    Size: $($finding.Size) bytes | Modified: $($finding.Modified)"
                $azureOutput += ""
            }
        }
    }
    
    # Write Azure audit to file
    $azureOutput | Out-File -FilePath $azureFile -Encoding UTF8
    Write-Host "Azure infrastructure audit exported to: $azureFile" -ForegroundColor Green
    Write-Host "Azure-related items found: $totalFindings"
}
catch {
    $feature3Success = $false
    $errorMsg = "Feature 3 error: $($_.Exception.Message)"
    $errors += $errorMsg
    Write-Host "ERROR: $errorMsg" -ForegroundColor Red
}

# FEATURE 4: Integration Inventory
Write-Host "`n--- FEATURE 4: Integration Inventory ---" -ForegroundColor Cyan

try {
    $intOutput = @()
    $intOutput += "Integration Inventory"
    $intOutput += "Generated: $(Get-Date)"
    $intOutput += "Root: $($PWD.Path)"
    $intOutput += "=" * 50
    $intOutput += ""
    
    $integrations = @{
        'APIs & Endpoints' = @()
        'Database Connections' = @()
        'External Services' = @()
        'Authentication Systems' = @()
        'Message Queues' = @()
        'Storage Services' = @()
        'Development Tools' = @()
        'Package Dependencies' = @()
    }
    
    # Patterns to search for integrations
    $integrationPatterns = @{
        'APIs & Endpoints' = @('api\/', 'endpoint', 'localhost:\d+', 'https?:\/\/[a-zA-Z0-9.-]+', '\/api\/', 'REST', 'GraphQL')
        'Database Connections' = @('database\.windows\.net', 'mongodb:', 'postgresql:', 'mysql:', 'Server=', 'ConnectionString', 'DATABASE_URL')
        'External Services' = @('\.googleapis\.com', '\.amazonaws\.com', '\.azure\.com', 'stripe\.com', 'twilio\.com', 'sendgrid')
        'Authentication Systems' = @('oauth', 'jwt', 'auth0', 'passport', 'identity', 'login', 'authentication')
        'Message Queues' = @('servicebus', 'rabbitmq', 'kafka', 'redis', 'queue', 'pubsub')
        'Storage Services' = @('blob\.core\.windows\.net', 's3\.amazonaws\.com', 'storage\.googleapis\.com', 'firebase')
    }
    
    # Search through code files for integration patterns
    $codeFiles = Get-ChildItem -Path "." -Recurse -File -Force | Where-Object {
        $_.Extension -in @('.js', '.ts', '.cs', '.json', '.config', '.env', '.yml', '.yaml', '.py', '.java', '.php', '.go', '.rb', '.rs') -and
        $_.Length -lt 2MB -and
        (-not (Test-ShouldIgnore -Path $_.FullName -IgnorePatterns $(if ($IgnoreGitignoreForFiles) { @() } else { $ignorePatterns }) -UniversalIgnorePatterns $universalIgnorePatterns))
    } | Select-Object -First 150
    
    foreach ($category in $integrationPatterns.Keys) {
        foreach ($file in $codeFiles) {
            try {
                $content = Get-Content -Path $file.FullName -Raw -ErrorAction SilentlyContinue
                if ($content) {
                    foreach ($pattern in $integrationPatterns[$category]) {
                        $matches = [regex]::Matches($content, $pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
                        if ($matches.Count -gt 0) {
                            $relativePath = ($file.FullName -replace [regex]::Escape($PWD.Path), ".") -replace "\\", "/"
                            $uniqueMatches = $matches | Select-Object -ExpandProperty Value | Sort-Object -Unique
                            
                            $existing = $integrations[$category] | Where-Object { $_.File -eq $relativePath }
                            if (-not $existing) {
                                $integrations[$category] += @{
                                    'File' = $relativePath
                                    'Matches' = $uniqueMatches
                                    'Count' = $matches.Count
                                }
                            }
                        }
                    }
                }
            }
            catch {
                # Continue silently
            }
        }
    }
    
    # Check for development tools and dependencies
    $packageFiles = @('package.json', 'requirements.txt', '*.csproj', 'composer.json', 'go.mod', 'Cargo.toml')
    foreach ($pattern in $packageFiles) {
        $files = Get-ChildItem -Path "." -Recurse -Filter $pattern -File -ErrorAction SilentlyContinue
        foreach ($file in $files) {
            try {
                $content = Get-Content -Path $file.FullName -Raw -ErrorAction SilentlyContinue
                if ($content) {
                    $relativePath = ($file.FullName -replace [regex]::Escape($PWD.Path), ".") -replace "\\", "/"
                    $integrations['Package Dependencies'] += @{
                        'File' = $relativePath
                        'Type' = $file.Name
                        'Size' = $file.Length
                    }
                }
            }
            catch {
                # Continue silently
            }
        }
    }
    
    # Generate integration inventory output
    $intOutput += "INTEGRATION SUMMARY"
    $intOutput += "=" * 18
    
    $totalIntegrations = 0
    foreach ($category in $integrations.Keys) {
        $count = $integrations[$category].Count
        $totalIntegrations += $count
        $intOutput += "$category`: $count items"
    }
    
    $intOutput += ""
    $intOutput += "Total integration points: $totalIntegrations"
    $intOutput += ""
    
    # Detailed integration listings
    foreach ($category in $integrations.Keys) {
        if ($integrations[$category].Count -gt 0) {
            $intOutput += ""
            $intOutput += "$category"
            $intOutput += "-" * $category.Length
            
            foreach ($integration in $integrations[$category]) {
                $intOutput += "  File: $($integration.File)"
                if ($integration.Matches) {
                    $intOutput += "    Found: $($integration.Matches -join ', ')"
                    $intOutput += "    Occurrences: $($integration.Count)"
                }
                if ($integration.Type) {
                    $intOutput += "    Type: $($integration.Type)"
                }
                if ($integration.Size) {
                    $intOutput += "    Size: $($integration.Size) bytes"
                }
                $intOutput += ""
            }
        }
    }
    
    # Write integration inventory to file
    $intOutput | Out-File -FilePath $integrationFile -Encoding UTF8
    Write-Host "Integration inventory exported to: $integrationFile" -ForegroundColor Green
    Write-Host "Integration points found: $totalIntegrations"
}
catch {
    $feature4Success = $false
    $errorMsg = "Feature 4 error: $($_.Exception.Message)"
    $errors += $errorMsg
    Write-Host "ERROR: $errorMsg" -ForegroundColor Red
}

# COLORIZED SUMMARY DASHBOARD
Write-Host "`n" -NoNewline
Write-Host "════════════════════════════════════════════════════════════════════════" -ForegroundColor DarkCyan
Write-Host "                    🚀 EXPORT PROCESS COMPLETED                         " -ForegroundColor White -BackgroundColor DarkBlue
Write-Host "════════════════════════════════════════════════════════════════════════" -ForegroundColor DarkCyan
Write-Host ""

# Feature status summary with colors and icons
Write-Host "📊 FEATURE STATUS REPORT" -ForegroundColor Yellow
Write-Host "─────────────────────────" -ForegroundColor DarkGray

if ($feature1Success) {
    Write-Host "✅ Feature 1: Directory Structure Scan" -ForegroundColor Green
    Write-Host "   📁 Enhanced tree view with file statistics" -ForegroundColor DarkGreen
} else {
    Write-Host "❌ Feature 1: Directory Structure Scan" -ForegroundColor Red
    Write-Host "   ⚠️  Encountered errors during processing" -ForegroundColor DarkRed
}

if ($feature2Success) {
    Write-Host "✅ Feature 2: File Contents Export (Token-Aware Multi-File)" -ForegroundColor Green
    Write-Host "   📄 Intelligent file splitting for AI model compatibility" -ForegroundColor DarkGreen
} else {
    Write-Host "❌ Feature 2: File Contents Export (Token-Aware Multi-File)" -ForegroundColor Red
    Write-Host "   ⚠️  Encountered errors during processing" -ForegroundColor DarkRed
}

if ($feature3Success) {
    Write-Host "✅ Feature 3: Azure Infrastructure Audit" -ForegroundColor Green
    Write-Host "   ☁️  Azure services and configuration analysis" -ForegroundColor DarkGreen
} else {
    Write-Host "❌ Feature 3: Azure Infrastructure Audit" -ForegroundColor Red
    Write-Host "   ⚠️  Encountered errors during processing" -ForegroundColor DarkRed
}

if ($feature4Success) {
    Write-Host "✅ Feature 4: Integration Inventory" -ForegroundColor Green
    Write-Host "   🔗 External services and API dependency mapping" -ForegroundColor DarkGreen
} else {
    Write-Host "❌ Feature 4: Integration Inventory" -ForegroundColor Red
    Write-Host "   ⚠️  Encountered errors during processing" -ForegroundColor DarkRed
}

Write-Host ""

# Write errors to file if any occurred
if ($errors.Count -gt 0) {
    $errorOutput = @()
    $errorOutput += "Export Process Errors"
    $errorOutput += "Generated: $(Get-Date)"
    $errorOutput += "Total Errors: $($errors.Count)"
    $errorOutput += "=" * 50
    $errorOutput += ""
    
    for ($i = 0; $i -lt $errors.Count; $i++) {
        $errorOutput += "Error $($i + 1): $($errors[$i])"
        $errorOutput += ""
    }
    
    $errorOutput | Out-File -FilePath $errorFile -Encoding UTF8
    Write-Host "`nErrors logged to: $errorFile" -ForegroundColor Yellow
    Write-Host "Total errors encountered: $($errors.Count)" -ForegroundColor Yellow
}
else {
    Write-Host "`nNo errors encountered during export process" -ForegroundColor Green
}

# Output files summary with contextual naming
Write-Host "📂 OUTPUT FILES GENERATED" -ForegroundColor Yellow
Write-Host "──────────────────────────" -ForegroundColor DarkGray

Write-Host "📁 " -NoNewline -ForegroundColor Blue
Write-Host "structure-$timestamp.txt" -ForegroundColor White -NoNewline
Write-Host " (Feature 1: Directory Structure)" -ForegroundColor DarkGray

# Feature 2: Show multiple file parts if any were created
if ($feature2Success -and $contentsFiles.Count -gt 0) {
    if ($contentsFiles.Count -eq 1) {
        Write-Host "📄 " -NoNewline -ForegroundColor Green  
        $partName = Split-Path $contentsFiles[0] -Leaf
        Write-Host "$partName" -ForegroundColor White -NoNewline
        Write-Host " (Feature 2: File Contents - Single File)" -ForegroundColor DarkGray
    } else {
        Write-Host "📄 " -NoNewline -ForegroundColor Green  
        Write-Host "filecontents-$timestamp-part*.txt" -ForegroundColor White -NoNewline
        Write-Host " (Feature 2: File Contents - $($contentsFiles.Count) Parts)" -ForegroundColor DarkGray
        foreach ($file in $contentsFiles) {
            $partName = Split-Path $file -Leaf
            Write-Host "   └─ $partName" -ForegroundColor DarkGreen
        }
    }
} elseif ($feature2Success) {
    Write-Host "📄 " -NoNewline -ForegroundColor Green  
    Write-Host "filecontents-$timestamp.txt" -ForegroundColor White -NoNewline
    Write-Host " (Feature 2: File Contents)" -ForegroundColor DarkGray
}

if ($feature3Success) {
    Write-Host "☁️ " -NoNewline -ForegroundColor Cyan
    Write-Host "azure-audit-$timestamp.txt" -ForegroundColor White -NoNewline
    Write-Host " (Feature 3: Azure Infrastructure)" -ForegroundColor DarkGray
}

if ($feature4Success) {
    Write-Host "🔗 " -NoNewline -ForegroundColor Magenta
    Write-Host "integrations-$timestamp.txt" -ForegroundColor White -NoNewline
    Write-Host " (Feature 4: Integration Inventory)" -ForegroundColor DarkGray
}

if ($errors.Count -gt 0) {
    Write-Host "⚠️ " -NoNewline -ForegroundColor Red
    Write-Host "export-$timestamp-errors.txt" -ForegroundColor White -NoNewline
    Write-Host " (Error Log)" -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "💡 USAGE TIPS" -ForegroundColor Yellow
Write-Host "──────────────" -ForegroundColor DarkGray
Write-Host "• Use -IgnoreGitignoreForFiles to scan protected files like .env" -ForegroundColor White
Write-Host "• Use -TokenLimit <number> to customize AI model compatibility (200k default)" -ForegroundColor White
Write-Host "• Multiple file parts ensure compatibility with AI token limits" -ForegroundColor White
Write-Host "• Share exports with AI assistants for enhanced project context" -ForegroundColor White
Write-Host "• File naming includes timestamps for easy identification" -ForegroundColor White
Write-Host "• Universal ignore patterns prevent massive outputs (node_modules, etc.)" -ForegroundColor White
if ($IsWindowsOS) {
    Write-Host "• Windows OS detected - bracket files ([slug].astro) handled specially" -ForegroundColor Cyan
}

Write-Host ""
Write-Host "════════════════════════════════════════════════════════════════════════" -ForegroundColor DarkCyan
Write-Host "                      ✨ EXPORT PROCESS FINISHED ✨                     " -ForegroundColor White -BackgroundColor DarkGreen
Write-Host "════════════════════════════════════════════════════════════════════════" -ForegroundColor DarkCyan
