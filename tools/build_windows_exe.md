# Building the Windows .exe

**The result runs on any Windows PC with nothing installed** — no Flutter, no
Visual Studio, no VC++ redistributable, no runtime download. The Microsoft
runtime DLLs are copied in beside the program, which is what makes that true.

Two different machines, and only one of them needs anything:

| machine | needs |
|---|---|
| the one that **runs** RailSim | **nothing.** Double-click and it opens. |
| the one that **builds** the .exe | Visual Studio — or nobody's, if you use GitHub (below) |

The cloud build also *proves* the first row rather than assuming it: before
uploading, it reads every DLL the program imports and fails if even one is
neither a Windows system DLL nor shipped in the folder. That is the check that
catches "works on the build machine".

The *build* still has to happen on Windows. Flutter does not cross-compile to
Windows from Linux: `flutter build` on the Linux machine offers `apk`, `linux`
and `web` only, and there is no MSVC or mingw toolchain there. Nothing is
missing from the project — `windows/` is present and correct.

There are two ways to get the .exe. Pick one.

## 1. No Windows PC needed — build it in the cloud

`.github/workflows/windows-exe.yml` builds it on GitHub's own Windows machine.

1. Make this folder its own git repository and push it to GitHub.
   **Do not commit from `~/Desktop`** — that is one big repo holding personal
   documents; the first commit there would publish them.

   ```bash
   cd ~/Desktop/PROJECTS/demiryol/railsim_future
   git init
   printf 'build/\n.dart_tool/\ndist/\n' > .gitignore
   git add . && git commit -m "RailSim"
   git remote add origin <your github repo>
   git push -u origin main
   ```

2. Open the repository's **Actions** tab. The run starts on push, or press
   *Run workflow*.

3. Download the **RailSim-windows-x64** artifact. Unzip it anywhere and run
   `railsim.exe`.

The workflow runs `flutter analyze` and the whole test suite before building,
so a broken build never ships.

## 2. On a Windows PC — one command

Needs Flutter on PATH and **Visual Studio 2022** with the "Desktop development
with C++" workload (Community edition is free). `flutter doctor -v` should show
Visual Studio as installed.

```powershell
powershell -ExecutionPolicy Bypass -File tools\build_windows.ps1
```

It builds, copies the runtime DLLs in, and packs everything into one file with
**IExpress** — which has shipped inside Windows since XP, so the packing step
needs nothing installed either.

You get both:

| | |
|---|---|
| `build\windows\x64\runner\Release\` | the portable folder — zip it and it runs anywhere |
| `dist\RailSim-windows-x64.exe` | one file, double-click, nothing written to Program Files or the registry |

## Linux, already built

`tools/make_single_file.sh` does the same job for Linux and has been run:
`dist/RailSim-linux-x86_64.run`, one double-clickable file, verified working.
