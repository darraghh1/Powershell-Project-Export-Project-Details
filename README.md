# PowerShell Project Export Tool 🚀

> **Comprehensive project documentation generator optimized for AI assistance**

A powerful PowerShell script that generates detailed project documentation by exporting directory structures, file contents, Azure infrastructure details, and integration inventories. Perfect for sharing project context with AI assistants like Claude, ChatGPT, and others.

## ✨ Features

### 🗂️ **Feature 1: Enhanced Directory Structure**
- Hierarchical tree visualization with file statistics
- File type summaries and directory metrics  
- Size calculations and modification tracking
- Respects `.gitignore` and universal ignore patterns

### 📄 **Feature 2: Token-Aware File Contents Export**
- **Intelligent file splitting** for AI model compatibility
- Configurable token limits (200k default for Claude API)
- Complete file preservation (never splits individual files)
- Multi-part output with clear headers

### ☁️ **Feature 3: Azure Infrastructure Audit**
- Detects Azure services and configurations
- Finds Key Vault references and connection strings
- Identifies Terraform and ARM templates
- Scans for Azure-specific patterns in code

### 🔗 **Feature 4: Integration Inventory**
- Maps external API dependencies  
- Identifies authentication systems
- Detects database connections and message queues
- Catalogs package dependencies and development tools

## 🎯 Perfect for AI Assistance

This tool solves the common problem of AI context limits when working with large codebases:

- **Claude API**: Files split at 200k tokens (default)  
- **GPT-4**: Compatible with 128k token limits
- **GPT-3.5**: Works with 32k token constraints
- **Any AI**: Configurable token limits for maximum compatibility

## 📦 Installation

1. **Download the script:**
   ```powershell
   Invoke-WebRequest -Uri "https://raw.githubusercontent.com/your-username/project-export-tool/main/export-project.ps1" -OutFile "export-project.ps1"
   ```

2. **Or clone the repository:**
   ```bash
   git clone https://github.com/your-username/project-export-tool.git
   cd project-export-tool
   ```

3. **Ensure PowerShell execution policy allows scripts:**
   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```

## 🚀 Quick Start

### Basic Usage
```powershell
# Run with default settings (200k tokens per file)
.\export-project.ps1
```

### Common Scenarios
```powershell
# For Claude API (default - 200k tokens)
.\export-project.ps1

# For GPT-4 (128k token limit)
.\export-project.ps1 -TokenLimit 128000

# For GPT-3.5 (32k token limit)
.\export-project.ps1 -TokenLimit 32000

# Include protected files (like .env)
.\export-project.ps1 -IgnoreGitignoreForFiles

# Custom token limit for other AI models
.\export-project.ps1 -TokenLimit 50000

# Get help and see all options
.\export-project.ps1 -Help
```

## 📋 Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `-TokenLimit` | Token limit per output file | `200000` |
| `-IgnoreGitignoreForFiles` | Include gitignore files in export | `false` |
| `-Help` | Show detailed help information | `false` |

## 📁 Output Files

The script creates timestamped files in the `./exports/` directory:

```
exports/
├── structure-2024-01-15_14-30-25.txt          # Directory tree with stats
├── filecontents-2024-01-15_14-30-25-part1.txt # Code files (part 1)
├── filecontents-2024-01-15_14-30-25-part2.txt # Code files (part 2)
├── azure-audit-2024-01-15_14-30-25.txt        # Azure infrastructure
├── integrations-2024-01-15_14-30-25.txt       # External dependencies
└── export-2024-01-15_14-30-25-errors.txt      # Error log (if any)
```

## 🛡️ Smart Filtering

### Universal Ignore Patterns (Always Excluded)
```
node_modules/          # Package dependencies  
.git/                  # Git repository data
dist/, build/          # Build artifacts
.cache/, .tmp/         # Temporary files
package-lock.json      # Lock files
yarn.lock              # Yarn lock files
pnpm-lock.yaml         # pnpm lock files
*.log                  # Log files
vendor/                # Third-party code
__pycache__/           # Python cache
```

### Gitignore Respect
- **Feature 1** (Directory Structure): Always respects `.gitignore`
- **Feature 2** (File Contents): Respects `.gitignore` unless `-IgnoreGitignoreForFiles` is used
- **Universal patterns**: Always ignored regardless of gitignore settings

## 🔧 Configuration Examples

### For Different AI Models

```powershell
# Claude API (large context)
.\export-project.ps1 -TokenLimit 200000

# GPT-4 Turbo
.\export-project.ps1 -TokenLimit 128000

# GPT-3.5 Turbo
.\export-project.ps1 -TokenLimit 32000

# Conservative for session limits
.\export-project.ps1 -TokenLimit 50000
```

### For Different Project Types

```powershell
# Web application (include config files)
.\export-project.ps1 -IgnoreGitignoreForFiles

# Large enterprise project (smaller chunks)
.\export-project.ps1 -TokenLimit 50000

# Documentation-heavy project (default)
.\export-project.ps1
```

## 🎨 Sample Output

### Directory Structure Preview
```
. (Project Root - 847 files, 156 dirs, 45280.3 KB total)
├── README.md (12.4 KB)
├── package.json (2.1 KB)
├── src/ (324 files, 45 dirs, 8901.2 KB)
│   ├── components/ (89 files, 12 dirs, 2341.7 KB)
│   │   ├── Auth.tsx (4.2 KB)
│   │   └── Dashboard.tsx (6.8 KB)
│   └── utils/ (23 files, 3 dirs, 456.1 KB)
└── tests/ (134 files, 23 dirs, 1876.4 KB)
```

### Token-Aware Splitting Preview
```
=== FILE CONTENTS EXPORT SUMMARY ===
Total output files created: 3
Text files processed: 247
Binary files found: 89
Files with errors: 0
Token limit per file: 200000

✅ Created: filecontents-2024-01-15-part1.txt
✅ Created: filecontents-2024-01-15-part2.txt  
✅ Created: filecontents-2024-01-15-part3.txt
```

### Colorized Dashboard
```
🚀 EXPORT PROCESS COMPLETED
════════════════════════════

📊 FEATURE STATUS REPORT
─────────────────────────
✅ Feature 1: Directory Structure Scan
   📁 Enhanced tree view with file statistics
✅ Feature 2: File Contents Export (Token-Aware Multi-File)
   📄 Intelligent file splitting for AI model compatibility
✅ Feature 3: Azure Infrastructure Audit
   ☁️  Azure services and configuration analysis
✅ Feature 4: Integration Inventory
   🔗 External services and API dependency mapping
```

## 🔍 Troubleshooting

### Common Issues

**PowerShell Execution Policy Error**
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

**"Access Denied" Errors**
- Run PowerShell as Administrator, or
- Use `-IgnoreGitignoreForFiles` to bypass protected files

**Files Too Large for AI**
- Reduce token limit: `-TokenLimit 50000`
- Use universal ignore patterns (automatically applied)

**Missing Azure/Integration Data**
- Ensure you're running from project root directory
- Check that config files aren't in gitignore

### Windows Compatibility
- ✅ **Windows PowerShell 5.1**: Fully supported
- ✅ **PowerShell Core 6+**: Fully supported  
- ✅ **Windows bracket filenames**: Special handling for `[slug].astro` files
- ✅ **Cross-platform paths**: Automatic Windows/Linux path handling

## 🤖 AI Integration Tips

### Best Practices
1. **Start with directory structure** - Upload `structure-*.txt` first for context
2. **Upload file contents in order** - part1.txt, then part2.txt, etc.
3. **Include Azure/integration files** - Provides valuable architecture context
4. **Mention token limits** - "This is part 1 of 3 files, each under 200k tokens"

### Example AI Prompts
```
"I'm sharing my project documentation in multiple parts due to token limits. 
This is the directory structure and file contents (part 1 of 3). Please 
analyze the architecture and suggest improvements."
```

## 🛠️ Development

### Requirements
- PowerShell 5.1+ (Windows) or PowerShell Core 6+ (Cross-platform)
- No external dependencies required

### Contributing
1. Fork the repository
2. Create a feature branch  
3. Add tests for new functionality
4. Submit a pull request

### Testing
```powershell
# Test on sample project
git clone https://github.com/sample/project.git
cd project
..\export-project.ps1 -TokenLimit 50000
```

## 📈 Use Cases

### For Developers
- **Code reviews**: Share complete project context with AI
- **Documentation**: Generate comprehensive project overviews  
- **Onboarding**: Help new team members understand architecture
- **Debugging**: Provide full context when seeking AI assistance

### For AI Enthusiasts
- **Context sharing**: Overcome token limits with smart splitting
- **Project analysis**: Get AI insights on architecture and patterns
- **Code migration**: Share old codebases for modernization advice
- **Learning**: Understand how projects are structured

## 🎯 Features in Detail

### 🧠 Intelligent Token Splitting
- **Smart boundaries**: Never splits individual files in half
- **Conservative estimation**: 4:1 character-to-token ratio with 10% buffer
- **File integrity**: Each complete file stays together
- **Progress tracking**: Real-time token counting during processing

### 🔍 Pattern Detection
The script automatically detects and catalogs:
- **Azure services**: Key Vault, Storage, Service Bus, etc.
- **Databases**: PostgreSQL, MongoDB, MySQL connections
- **APIs**: REST endpoints, GraphQL schemas
- **Authentication**: OAuth, JWT, passport implementations
- **Package managers**: npm, yarn, composer, pip dependencies

### 🎨 Rich Output Format
- **Color-coded console**: Green for success, red for errors, yellow for warnings
- **Progress indicators**: Real-time file processing updates
- **Detailed summaries**: Comprehensive statistics and file counts
- **Error reporting**: Detailed logs when issues occur

## 🚧 Limitations

- **Token estimation**: Approximate (varies by AI model tokenizer)
- **Binary files**: Detected and excluded from content export
- **Large files**: No size limit per file, but token-aware splitting applied
- **Permissions**: Requires read access to project files

## 📄 License

MIT License - see [LICENSE](LICENSE) file for details.

## ⭐ Support

If this tool helps you work more effectively with AI assistants, please:
- ⭐ **Star this repository**
- 🐛 **Report issues** via GitHub Issues
- 💡 **Suggest improvements** via GitHub Discussions
- 🤝 **Contribute** via Pull Requests

## 🔄 Version History

- **v2.0**: Added token-aware file splitting, comprehensive documentation
- **v1.5**: Azure infrastructure audit, integration inventory
- **v1.0**: Basic directory structure and file contents export

---

**Made with ❤️ for the AI-assisted development community**

*Export your projects • Share with AI • Build better software*
