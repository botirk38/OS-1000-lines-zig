# <p align="center">🚀 OS-1000-lines-zig</p>

<p align="center">
    <em>An educational operating system written in Zig, within 1000 lines of code.</em>
</p>

<p align="center">
 <img src="https://img.shields.io/github/license/botirk38/OS-1000-lines-zig?style=default&logo=opensourceinitiative&logoColor=white&color=0080ff" alt="license">
 <img src="https://img.shields.io/github/last-commit/botirk38/OS-1000-lines-zig?style=default&logo=git&logoColor=white&color=0080ff" alt="last-commit">
 <img src="https://img.shields.io/github/languages/top/botirk38/OS-1000-lines-zig?style=default&color=0080ff" alt="repo-top-language">
 <img src="https://img.shields.io/github/languages/count/botirk38/OS-1000-lines-zig?style=default&color=0080ff" alt="repo-language-count">
</p>

## 🚧 Work in Progress 🚧
This project is still **a work in progress**! While the core components are in place, it is actively evolving. Contributions, feedback, and improvements are highly encouraged!

---

## Project Overview
### Introduction
**OS-1000-lines-zig** is an educational operating system implemented in Zig, inspired by the [Operating System in 1,000 Lines](https://operating-system-in-1000-lines.vercel.app/en) project. It serves as:
- A learning resource for **operating system development**, covering key low-level concepts.
- A hands-on guide for **Zig learners**, showcasing how to use Zig for OS development.

Currently, the project includes:
* **Basic Kernel**: Implemented in `src/kernel.zig`
* **Linker Script**: `src/kernel.ld` defining the memory layout
* **Build System**: `build.zig` to compile and link the kernel

As development continues, new features and refinements will be added!

## Who Is This For?
This project is designed for:
- **OS enthusiasts** exploring kernel development.
- **Zig learners** looking for real-world, low-level applications.
- **Students & developers** wanting to understand system internals.

## Quick Start
To try out **OS-1000-lines-zig**, follow these steps:
```sh
git clone https://github.com/botirk38/OS-1000-lines-zig.git
cd OS-1000-lines-zig
zig build
```
> ⚠ **Note:** Since this project is still under development, expect frequent updates and potential breaking changes.

## Installation
### Prerequisites
You'll need:
* **Zig Compiler**
* **Build Tools** (Zig build system)
* **Emulator** (QEMU recommended)
* **Linux** (or a Unix-based system)

### Setup Steps
1. Clone the repository:
   ```sh
   git clone https://github.com/botirk38/OS-1000-lines-zig.git
   ```
2. Navigate to the project directory:
   ```sh
   cd OS-1000-lines-zig
   ```
3. Build the project:
   ```sh
   zig build
   ```

## Running the OS
### In an Emulator (Recommended)
To boot the OS in **QEMU**, use:
```sh
zig build run
```
### On Real Hardware (Experimental)
1. Copy the kernel to a bootable USB/disk image.
2. Configure a bootloader (e.g., GRUB, Limine).
3. Boot from the disk and test!

> ⚠ **Warning:** Running on real hardware is **highly experimental** at this stage.

## Educational Breakdown
This project provides insight into essential OS components:

| Component | File | Purpose |
|-----------|------|---------|
| Kernel | `src/kernel.zig` | Handles initialization and main system loop |
| Linker Script | `src/kernel.ld` | Defines memory layout for the OS |
| Build System | `build.zig` | Manages compilation and linking |

More documentation will be added as the project progresses!

## Build & Deployment
### Building the Project
Compile the OS with:
```sh
zig build
```
### Running the OS
In an emulator:
```sh
zig run
```

## Contribution Guide
### How to Contribute
This project is in its **early stages**, and contributions are highly appreciated! To contribute:
1. Fork the repository:
   ```sh
   git fork https://github.com/botirk38/OS-1000-lines-zig.git
   ```
2. Create a new branch:
   ```sh
   git checkout -b feature-branch
   ```
3. Make your changes and commit:
   ```sh
   git commit -m "Add feature"
   ```
4. Push to your branch:
   ```sh
   git push origin feature-branch
   ```
5. Open a pull request.

### Code of Conduct
- Be respectful and supportive.
- Keep contributions educational and well-documented.
- Test changes before submitting PRs.

## License
This project is licensed under the [MIT License](https://github.com/botirk38/OS-1000-lines-zig/blob/main/LICENSE).

---

**Note:** This project is inspired by the [Operating System in 1,000 Lines](https://operating-system-in-1000-lines.vercel.app/en) initiative, which provides a structured approach to writing a simple OS. It is still evolving, so stay tuned for updates! 🚀
