<div align="center">

<img src="assets/icons/wanwan-256.png" width="112" alt="Wanwan icon">

# 晚晚 · 睡前陪伴关机助理

**一个会温柔催你睡觉的 Windows 桌面小伙伴。到点提醒、陪你收尾、帮你关机或睡眠。**

*Wanwan — a Windows desktop companion that turns “one more task” into a gentler end to the day.*

[![Download](https://img.shields.io/github/v/release/9OwO6/wanwan-shutdown-assistant?label=%E4%B8%8B%E8%BD%BD%20Download&color=A7778B)](https://github.com/9OwO6/wanwan-shutdown-assistant/releases/latest)
[![Windows](https://img.shields.io/badge/Windows-10%20%2F%2011-0078D4)](#30-秒上手)
[![Offline](https://img.shields.io/badge/离线运行-无需联网%20%2F%20API%20Key-7B8B74)](#隐私)
[![Checks](https://github.com/9OwO6/wanwan-shutdown-assistant/actions/workflows/verify.yml/badge.svg)](https://github.com/9OwO6/wanwan-shutdown-assistant/actions/workflows/verify.yml)

**[⬇ 下载最新版（约 25 MB，解压即用）](https://github.com/9OwO6/wanwan-shutdown-assistant/releases/latest)** · [中文](#中文) · [English](#english) · [AI 工程案例 / Case study](docs/AI_ENGINEERING.md)

![晚晚的真实运行画面](docs/screenshots/showcase.png)

</div>

## 中文

### 为什么做它

`shutdown -s -t 3600` 谁都会写，但冷冰冰的倒计时很容易被一句“再玩五分钟”打败。晚晚换了个思路：**不是强制关机，而是有人陪你把今天收个尾。**

- 🕥 **提前半小时、十分钟轻声提醒**，用当前时间报时：“宝贝，已经晚上十一点啦……”
- 💾 **到点先给你收尾时间**，最后两分钟倒计时，提醒保存文件
- 🌙 **到点自动关机或睡眠**——怕丢进度就选睡眠，窗口和文件都保留
- 📅 **周末作息**：周五、周六晚上可以单独设一个更晚的时间
- 🎙 **191 句离线 AI 语音**、10 种角色互动动画、可拖动的桌面小头像
- 🛡 **安全感优先**：默认不开启关机；正常关机不强杀程序；每晚可延期一次；有急事可以紧急取消

![运行时录制的角色动画](docs/screenshots/companion-animation.gif)

### 30 秒上手

1. 在 [Releases](https://github.com/9OwO6/wanwan-shutdown-assistant/releases/latest) 下载 `Wanwan-…-windows.zip`，**解压**到任意文件夹（不要直接在压缩包里双击）。
2. 双击 **`启动晚晚.vbs`**。如果系统禁用了 VBScript，双击 **`启动晚晚.cmd`**。
3. 先点 **「体验睡前倒计时」**：35 秒完整演示，**绝不会关机**。
4. 设好睡觉时间（周末可以单独设），选择到点后「正常关机」或「睡眠」，点 **「保存并开启守护」**。

> 小技巧：右键右下角托盘图标 →「在桌面创建晚晚快捷方式」，以后双击桌面头像就能打开；勾选「开机陪伴」则每天登录后自动出现。

| 桌面小头像 | 准点提醒气泡 | 睡前收尾倒计时 |
|:--:|:--:|:--:|
| <img src="docs/screenshots/desktop-pet.png" width="142" alt="可拖动的桌面头像"> | <img src="docs/screenshots/reminder-bubble.png" width="270" alt="带报时的提醒气泡"> | <img src="docs/screenshots/bedtime-countdown.png" width="270" alt="收尾倒计时"> |

### 常见问题

<details>
<summary><b>Windows 提示“已保护你的电脑”（SmartScreen）怎么办？</b></summary>

晚晚是开源的个人项目，没有购买代码签名证书，所以第一次运行时 Windows 可能提示未知发布者。点击「更多信息」→「仍要运行」即可。全部源码都在这个仓库里，可以自行审阅。
</details>

<details>
<summary><b>会不会突然关机、丢掉我没保存的东西？</b></summary>

不会强制关机。晚晚调用的是不带 FORCE 参数的正常关机，Word、记事本等程序弹出“是否保存”时，关机会停下来等你。到点前有提醒，到点后还有 2–30 分钟收尾时间和最后两分钟倒计时。如果仍然担心，把到点动作改成 **睡眠**：什么都不会关闭。
</details>

<details>
<summary><b>今晚真的有急事怎么办？</b></summary>

倒计时窗口里有「再给我一点收尾时间」（每晚一次）和「紧急取消今晚关机」（需二次确认，只影响今晚）。右键托盘 →「退出助理」会停止守护。
</details>

<details>
<summary><b>需要联网吗？会收集数据吗？</b></summary>

<a id="隐私"></a>不需要。语音是提前生成好的音频，运行时不加载 AI 模型、不调用任何云端 API。设置和事件记录只保存在本机 `%LOCALAPPDATA%\WanwanShutdown`。
</details>

<details>
<summary><b>怎么卸载？</b></summary>

右键托盘图标 →「退出助理」，取消勾选「开机陪伴」并保存（或删除 `shell:startup` 里的晚晚快捷方式），然后删除解压的文件夹即可。想清除设置，再删除 `%LOCALAPPDATA%\WanwanShutdown`。
</details>

<details>
<summary><b>系统要求？</b></summary>

Windows 10 / 11 自带的 Windows PowerShell 5.1 和 .NET Framework（WPF）即可，不需要安装 Python、Node.js、显卡或任何 SDK。开发和测试环境是 Windows 11。
</details>

### 这是一个 AI 辅助开发的作品

晚晚是我用 AI 做完整产品的一次实践：需求、WPF 界面、C# 系统调用、测试由 **Codex** 协助实现；角色形象和 N1 语音由生成式模型制作；v0.3 的产品评审、发布包瘦身（103 MB → 约 25 MB）、周末作息、睡眠模式和宣传片由 **Claude** 协助完成。AI 生成的代码和素材都被当作“需要验证的输入”：有调度边界测试、素材哈希校验、隔离的 WPF 运行测试和 CI。详见 [AI 工程案例](docs/AI_ENGINEERING.md)。

---

## English

Wanwan (晚晚, “evening”) is a **native Windows bedtime companion**: an animated character with an original, offline Mandarin AI voice reminds you 30 and 10 minutes before bedtime, gives you time to wrap up and save, then requests a **normal shutdown or sleep**. The interface and voice are Simplified Chinese.

It is a personal **AI-assisted product engineering portfolio project** — native desktop interaction, generative media pipelines, OS integration and testable behavior in one runnable application.

### Highlights

- **Staged bedtime flow** — reminders at −30 and −10 minutes, a wrap-up window, a final two-minute countdown and a goodnight before the power request. One deferral per night and a confirmed emergency cancel.
- **Shutdown or sleep** — normal `ExitWindowsEx` shutdown without force (apps can still block it to save work), or sleep via `SetSuspendState`. After waking, the countdown grants a fresh two-minute save window instead of immediately sleeping again.
- **Weekend bedtimes** — Friday and Saturday nights can use a later time; after-midnight bedtimes belong to the previous evening.
- **Offline AI voice** — 92 companion lines, 96 hour-aware reminders and 3 guard lines, shipped as compact MP3s with hash-verified WAV masters in the repository.
- **Desktop companion** — draggable avatar with visible guard state, ten animated interactions (40 poses), reduced-motion option, tray icon, single-instance activation.

### Quick start

Download the [latest release](https://github.com/9OwO6/wanwan-shutdown-assistant/releases/latest), extract it, and double-click `启动晚晚.vbs` (or `启动晚晚.cmd`), or run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Start-Wanwan.ps1
```

Try **体验睡前倒计时** (“try bedtime countdown”) first — a 35-second demo that never shuts down. Useful labels: 睡觉时间 bedtime · 周五六晚 Fri/Sat bedtime · 收尾分钟 wrap-up minutes · 到点后 正常关机 / 睡眠 at the deadline: shut down / sleep · 保存并开启守护 save & enable the guard.

### Engineering

| Area | Implementation | What it demonstrates |
|---|---|---|
| Desktop runtime | PowerShell 5.1 + WPF/XAML | Shipping a native prototype with built-in Windows components only |
| Scheduling | Pure `Get-NightState` / `Get-NightBedtime` + Dispatcher timer | Explicit phases, midnight and weekend boundaries, overdue and resume handling |
| Windows integration | C# P/Invoke, WinForms power API, mutex, named event, tray | Token privileges, normal shutdown, sleep, single-instance reopening |
| Media | Prepared audio catalogs, transcript routing, MP3 runtime + WAV masters | Consistent caption/voice pairing without live inference |
| Delivery | `tools/build_release.py` + tag-triggered GitHub Actions release | Reproducible 25 MB portable ZIP, audited before publishing |
| Validation | 21 schedule boundary tests, isolated WPF test modes, asset audit, CI | Separating visible behavior from a successful build |

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\Schedule.Tests.ps1
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File app\Main.ps1 -GuardTest      # also: -PetTest -PetControlsTest -DialogueTest -LifecycleTest -CountdownTest -VoiceTest
python tools\verify_release_assets.py
python tools\build_release.py v0.3.0
```

Test modes use isolated settings and simulated power requests; they never call the native shutdown or sleep operation. The published tests do **not** prove a completed OS shutdown or every third-party application's unsaved-work behavior — see [verification notes](docs/VERIFICATION.md) and [architecture](docs/ARCHITECTURE.md).

### Source map

```text
app/                  WPF UI, schedule, voice, desktop pet, power interop and WPF test modes
assets/               Character art, icons, dialogue catalogs, MP3 runtime clips and WAV masters
tests/                Deterministic schedule tests (run anywhere PowerShell runs)
tools/                Release build, asset audit, media generation and encoding
docs/                 Case study, architecture, verification, release notes, screenshots
```

Application code is MIT licensed; bundled artwork/audio have separate terms in [NOTICE](NOTICE.md) and [media provenance](docs/ASSETS.md). Created by [9OwO6](https://github.com/9OwO6) with AI-assisted development (Codex, Claude).
