<div align="center">

<img src="assets/icons/wanwan-256.png" width="112" alt="Wanwan icon">

# 晚晚 · 睡前陪伴关机助理

**一个会温柔催你睡觉的 Windows 桌面小伙伴。到点提醒、陪你收尾、帮你关机或睡眠。**

*Wanwan — a Windows desktop companion that turns “one more task” into a gentler end to the day.*

[![Download](https://img.shields.io/github/v/release/9OwO6/wanwan-shutdown-assistant?label=%E4%B8%8B%E8%BD%BD%20Download&color=A7778B)](https://github.com/9OwO6/wanwan-shutdown-assistant/releases/latest)
[![Windows](https://img.shields.io/badge/Windows-10%20%2F%2011-0078D4)](#30-秒上手)
[![Local](https://img.shields.io/badge/本地运行-不上传数据%20%2F%20无需%20API%20Key-7B8B74)](#隐私)
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
- 👀 **起夜监督**：关机后的几个小时里偷偷开机，晚晚会出来说“怎么又偷偷起来呀”，给你几分钟处理急事，然后再帮你关机；真有急事可以取消当晚监督
- ☆ **早睡打卡**：自动记录每晚有没有按时睡，显示连续早睡天数和最近 7 晚，早上见面时晚晚会告诉你昨晚的结果
- ⬆ **一键更新**：「检查更新」直接从 GitHub 下载新版并自动重启，设置和打卡记录都保留
- 💬 **两种晚晚可选：女友或姐姐**。女友爱撒娇，姐姐温柔又会管人，各有一套原创台词和离线 AI 配音；称呼可选（宝宝、亲爱的、小笨蛋），也可以不叫或用自己的名字
- 🧸 **会自己找事做的桌宠**：晚晚直接坐在你的桌面上（透明、无边框），隔一阵喝水、写字、伸懒腰，越接近睡觉时间越困。拖她移动，点她一下会回你，双击打开，右键有更多。打开「晚晚陪伴」后，你看视频她一起看、打游戏她也玩、离开电脑她就趴下睡（只在本机判断程序类型，默认关闭）
- 🛡 **安全感优先**：默认不开启关机；正常关机不强杀程序；每晚可延期一次；有急事可以紧急取消

![运行时录制的角色动画](docs/screenshots/companion-animation.gif)

### 30 秒上手

1. 在 [Releases](https://github.com/9OwO6/wanwan-shutdown-assistant/releases/latest) 下载 `Wanwan-…-windows.zip`，**解压**到任意文件夹（不要直接在压缩包里双击）。
2. 双击 **`启动晚晚.vbs`**。如果系统禁用了 VBScript，双击 **`启动晚晚.cmd`**。
3. 先点 **「体验睡前倒计时」**：35 秒完整演示，**绝不会关机**。
4. 点右上角 **「⚙ 设置」**：设好睡觉时间（周末可以单独设），选择到点后「正常关机」或「睡眠」，点 **「保存并开启守护」**。以后在主窗口点「暂停守护 / 开启到点守护」就能一键切换。

> 小技巧：右键右下角托盘图标 →「在桌面创建晚晚快捷方式」，以后双击桌面头像就能打开；在设置里勾选「开机自动启动」则每天登录后自动出现。

| 书桌前的晚晚（喝水 / 你离开时趴着睡） | 准点提醒气泡 | 睡前收尾倒计时 |
|:--:|:--:|:--:|
| <img src="docs/screenshots/desk-pet-drink.png" width="150" alt="桌宠在书桌前喝水"> <img src="docs/screenshots/desk-pet-nap.png" width="150" alt="桌宠趴着睡"> | <img src="docs/screenshots/reminder-bubble.png" width="270" alt="带报时的提醒气泡"> | <img src="docs/screenshots/bedtime-countdown.png" width="270" alt="收尾倒计时"> |

| 起夜监督：关机后又偷偷开机 | 早上的早睡打卡 |
|:--:|:--:|
| <img src="docs/screenshots/caught-watch.png" width="270" alt="起夜监督倒计时"> | <img src="docs/screenshots/streak-greeting.png" width="300" alt="早睡打卡问候"> |

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

<a id="隐私"></a>平时不需要。语音是提前生成好的音频，运行时不加载 AI 模型、不调用任何云端 API。唯一的联网是“检查更新”：每天最多一次读取本仓库在 GitHub 上的最新版本信息，你同意后才下载安装包（会校验 SHA-256）。设置、事件和打卡记录只保存在本机 `%LOCALAPPDATA%\WanwanShutdown`，不会上传。
</details>

<details>
<summary><b>怎么卸载？</b></summary>

右键托盘图标 →「退出助理」，在设置里取消勾选「开机陪伴」并保存（或删除 `shell:startup` 里的晚晚快捷方式），然后删除解压的文件夹即可。想清除设置，再删除 `%LOCALAPPDATA%\WanwanShutdown`。
</details>

<details>
<summary><b>系统要求？</b></summary>

Windows 10 / 11 自带的 Windows PowerShell 5.1 和 .NET Framework（WPF）即可，不需要安装 Python、Node.js、显卡或任何 SDK。开发和测试环境是 Windows 11。
</details>

### 这是一个 AI 辅助开发的作品

晚晚是我用 AI 做完整产品的一次实践：需求、WPF 界面、C# 系统调用、测试由 **Codex** 协助实现；角色形象和 N1 语音由生成式模型制作；v0.3 的产品评审、发布包瘦身（103 MB → 约 25 MB）、周末作息、睡眠模式、起夜监督、早睡打卡、一键更新和宣传片由 **Claude** 协助完成，Claude 还直接在 Codex 的线程里请它生成新台词的 N1 语音。AI 生成的代码和素材都被当作“需要验证的输入”：有调度边界测试、素材哈希校验、隔离的 WPF 运行测试和 CI。详见 [AI 工程案例](docs/AI_ENGINEERING.md)。

---

## English

Wanwan (晚晚, “evening”) is a **native Windows bedtime companion**: an animated character with an original, offline Mandarin AI voice reminds you 30 and 10 minutes before bedtime, gives you time to wrap up and save, then requests a **normal shutdown or sleep**. The interface and voice are Simplified Chinese.

It is a personal **AI-assisted product engineering portfolio project** — native desktop interaction, generative media pipelines, OS integration and testable behavior in one runnable application.

### Highlights

- **Staged bedtime flow** — reminders at −30 and −10 minutes, a wrap-up window, a final two-minute countdown and a goodnight before the power request. One deferral per night and a confirmed emergency cancel.
- **Shutdown or sleep** — normal `ExitWindowsEx` shutdown without force (apps can still block it to save work), or sleep via `SetSuspendState`. After waking, the countdown grants a fresh two-minute save window instead of immediately sleeping again.
- **Weekend bedtimes** — Friday and Saturday nights can use a later time; after-midnight bedtimes belong to the previous evening.
- **Sleep watch** — powering the computer back on within the sleep window (default 6 h after bedtime) after a guarded shutdown opens a “caught you” countdown with a configurable grace period (default 5 min) and a one-night emergency cancel.
- **Bedtime streak** — each night is recorded as slept / early / late / caught / cancelled from power requests and the last time the app saw the computer awake; the window shows the streak and the last seven nights, and a morning greeting reports the result.
- **One-click updates** — a background check of this repository's latest GitHub release, asset-origin and SHA-256 checks, and a detached installer that keeps settings and resumes an active countdown.
- **Two personas, offline AI voice** — a sweet girlfriend (N1) and a gentle older sister (V3), each with her own approved script and whole-sentence recordings per address (宝宝 / 亲爱的 / 小笨蛋, none, or a custom name shown in the bubble). Shipped as compact MP3s with hash-verified WAV masters in the repository.
- **A desk pet with a routine** — idle actions every few minutes, sleepier toward bedtime; the opt-in companion mode mirrors what you are doing (video, games, work) from the foreground process name only and naps when you step away.
- **Desktop companion** — draggable avatar with visible guard state, ten animated interactions (40 poses), reduced-motion option, tray icon, single-instance activation.
- **Video-ready transparent frames** — forty reviewed 640×640 PNGs in [`assets/frames/`](assets/frames/), with neighboring-sleeve artifacts removed; the app plays these same exports ([crop audit](docs/FRAME_REPAIR.md)).

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
| Validation | 26 schedule, 16 history and 16 update tests, isolated WPF test modes, asset audit, CI | Separating visible behavior from a successful build |

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\Schedule.Tests.ps1   # also tests\History.Tests.ps1, tests\Update.Tests.ps1
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File app\Main.ps1 -WatchTest      # also: -GuardTest -PetTest -PetControlsTest -DialogueTest -LifecycleTest -CountdownTest -VoiceTest
python tools\verify_release_assets.py
python tools\build_release.py v0.3.0
```

Test modes use isolated settings and simulated power requests; they never call the native shutdown or sleep operation. The published tests do **not** prove a completed OS shutdown or every third-party application's unsaved-work behavior — see [verification notes](docs/VERIFICATION.md) and [architecture](docs/ARCHITECTURE.md).

### Source map

```text
app/                  WPF UI, schedule, voice, desktop pet, power interop and WPF test modes
assets/               Character art, icons, dialogue catalogs, MP3 runtime clips and WAV masters
tests/                Deterministic schedule, history and update tests (run anywhere PowerShell runs)
tools/                Release build, asset audit, media generation and encoding
docs/                 Case study, architecture, verification, release notes, screenshots
```

Application code is MIT licensed; bundled artwork/audio have separate terms in [NOTICE](NOTICE.md) and [media provenance](docs/ASSETS.md). Created by [9OwO6](https://github.com/9OwO6) with AI-assisted development (Codex, Claude).
