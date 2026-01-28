# 🚀 DIVINETOOLS v2.0

Advanced Android Multi-Account Manager & Optimizer for Termux

## ✨ Features

- **Multi-Account Management**: Monitor multiple Roblox accounts simultaneously
- **Smart Window Layout**: Automatic window positioning based on screen resolution
- **Private Server Integration**: Support for same or per-account private servers
- **Webhook Notifications**: Discord integration for status updates
- **System Optimization**: Performance tuning and resource management
- **Auto-Script Injection**: Custom script execution per account
- **Real-time Dashboard**: Live monitoring with memory and time display

## 📋 Prerequisites

- Android 7.0 or higher
- Termux app (latest version)
- Root access (recommended for full features)
- Internet connection

## 🚀 Quick Installation

### Method 1: One-line install
```bash
pkg install git -y && cd $HOME && git clone https://github.com/gembil-moo/DIVINETOOLS.git && cd DIVINETOOLS && bash install.sh

Method 2: Manual install
Open Termux

Update packages:

bash
pkg update && pkg upgrade -y
Install Git and clone repository:

bash
pkg install git -y
git clone https://github.com/gembil-moo/DIVINETOOLS.git
cd DIVINETOOLS
Run installer:

bash
bash install.sh
⚙️ Configuration
First Time Setup
Run the program:

bash
./run.sh
Select [2] First Configuration from main menu

Follow the guided setup process

Manual Configuration
Edit config/config.json:

bash
nano config/config.json
Use config.example.json as reference.

🎮 Usage
Main Menu Options
text
[1] Start Monitoring     - Launch and monitor all configured accounts
[2] First Configuration  - Guided setup wizard
[3] Edit Configuration   - Advanced configuration editor
[4] Optimize Device      - Performance optimization tools
[5] Script Manager       - Manage auto-execute scripts
[6] Backup/Restore       - Backup and restore configurations
[7] Uninstall            - Remove DIVINETOOLS
[8] Exit                 - Exit program
Monitoring Controls
CTRL+C - Graceful shutdown

Dashboard updates every 0.5 seconds

Automatic restart on crash (configurable)

🔧 Optimization Features
God Mode (Extreme Performance)
Disables animations

Removes textures

Reduces resolution

Clears cache aggressively

Smart Window Management
Automatic layout based on screen size

Supports 1-12+ accounts

Cinema mode for single account

Grid mode for multiple accounts

📊 Dashboard Features
Real-time status per account

Memory usage display

Current time

Connection status

Username display (with masking option)

🔗 Webhook Integration
Configure Discord webhooks for:

Status updates

Error alerts

Connection changes

Custom notifications

🛠️ Troubleshooting
See docs/TROUBLESHOOTING.md for common issues and solutions.

Quick Fixes:
"Lua not found": Run bash install.sh again

"No packages detected": Install Roblox app first

"Root access required": Grant root permissions to Termux

"Webhook failed": Check URL and internet connection

📁 Project Structure
text
DIVINETOOLS/
├── src/                    # Source code
│   ├── main.lua           # Entry point
│   └── modules/           # Modular components
├── config/                # Configuration files
├── logs/                  # Log files
├── scripts/               # Auto-execute scripts
├── docs/                  # Documentation
├── install.sh            # Installation script
├── run.sh               # Launcher script
└── README.md            # This file
⚠️ Disclaimer
This tool is for educational purposes only. Use at your own risk. The developers are not responsible for any:

Account bans or suspensions

Device issues

Terms of Service violations

Any other consequences of use

🤝 Contributing
Fork the repository

Create a feature branch

Commit changes

Push to branch

Create Pull Request

📄 License
MIT License - See LICENSE file for details

🌟 Support
GitHub Issues: Report bugs

Discord: Join community

Made with ❤️ by Gembil Moo