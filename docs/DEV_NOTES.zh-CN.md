# 晚晚 · 关机助理

Windows WPF 桌面程序：十种透明角色互动、中文 AI 语音、分阶段睡前提醒、系统托盘和正常关机。

## 启动与体验

双击「晚晚 · 关机助理.lnk」可使用晚晚头像图标启动；原「启动晚晚.vbs」也可继续使用。无需安装开发 SDK，运行依赖 Windows PowerShell 5.1、WPF 和系统语音组件。

- 右上角「⚙ 设置」集中放所有约定：睡觉时间、周五六晚、收尾分钟、到点关机或睡眠、到点自动守护、起夜监督、声音（晚晚的声音 / 系统朗读）、称呼、桌面陪伴、减少动态、开机陪伴、自动检查更新。主窗口只保留今晚状态、快捷体验和「开启/暂停守护」。
- 声音只保留 N1（晚晚的声音）。v0.3.1 删除了有杂音的 A/B/C/D 试验音色和「音色试听」窗口；旧设置自动迁移到 N1，N1 没有录音的文字由系统朗读兜底。
- 「互动小剧场」可体验十种不同动作：探头、拍一拍、递水、伸懒腰、点头、比心、加油、挥手、打哈欠、贴脸晚安。每种动作有四个独立姿态，配合不同的节奏、身体位移和短淡化。点击主画面角色可轮换小回应。
- 「桌面陪伴」让晚晚平时缩成小头像。按住头像拖动可移动，位置会保存；轻点头像或点击「打开晚晚」找回主窗口。头像上的 × 或右键「隐藏桌宠」可隐藏，并保留后台守护；托盘「显示常驻桌宠」可恢复。头像直接显示自动关机是否开启。主窗口底部「桌宠提醒体验」或托盘「叫晚晚出来」可体验提醒。
- 自动提醒在主窗口可见、最小化或收起时均通过桌宠出现，不抢当前应用的键盘焦点。提前半小时、十分钟展示气泡；到点及最后两分钟展示右下角的桌宠收尾倒计时。位置避开任务栏。
- 语音使用当前小时，按凌晨、早上、中午、下午、晚上报时，例如「宝贝，已经晚上十一点啦。快到睡觉时间喽。」气泡标题显示提醒发生时的准确 HH:mm。N1 包覆盖 24 小时和四个提醒阶段，共 96 段；日常运行不加载 AI 模型、不需要联网。
- 设置里的「减少动态」保留静态姿态与文字，关闭帧切换和身体动作。关闭语音后，提醒和角色仍会显示。收起气泡后回到小头像；取消「桌面陪伴」后不常驻头像，定时提醒仍可出现。
- 「体验睡前倒计时」运行 35 秒模拟，绝不关机。

首次运行默认 N1 · 清甜温柔。v0.4.0 起新增分段声音包（见下方「声音包与称呼」）。AI 语音为本地预生成台词，N1 自然轮换“宝贝”“宝宝”“亲爱的”，偶尔使用“我的小可爱”；自定义称呼用于系统声音。十种互动分别配有专属台词和录音。

## 休息约定

设置睡觉时间和 2–30 分钟收尾时间后，点击「保存并开启关机」可一步保存并启用真实自动关机；也可勾选「到点自动关机」后点击「保存约定」。仅保存时间不等于开启自动关机，头像会持续显示当前守护状态。

提前半小时、十分钟提醒，到点打开收尾窗口，最后两分钟倒计时。每晚可延期一次，不能突破最晚关机时间。紧急取消需确认，当晚取消和延期状态重启后保留。截止后启动会给两分钟保存窗口；截止四小时后结束当晚区间。

点击「好啦宝宝，我收完尾就睡觉」会缩成晚晚＋实时倒计时的小面板。× 可隐藏，「展开倒计时」恢复完整面板，托盘「查看睡前倒计时」找回隐藏的倒计时。缩小、隐藏和展开都不延期、不取消，也不重置截止时间；最后准备关机时会恢复小面板并播报提醒。

正常关机调用不带 FORCE 的 Windows ExitWindowsEx API，允许应用因未保存内容阻止关机，三分钟后重试。助理不能替所有软件自动保存。超时启动先留两分钟保存文件，倒计时结束后先播放 N1 关机晚安提示，等提示播完再请求关机。

「开机陪伴」创建当前用户启动快捷方式，取消勾选并保存可移除。只有勾选「到点自动关机」并保存，才会开启自动关机；仅保存时间会显示「仅陪伴 · 不会自动关机」。关闭窗口收起到托盘，后台继续计时；点击右下角晚晚头像、双击托盘图标或再次打开桌面快捷方式都能找回主界面。右键托盘退出则停止自动守护。

## 本地数据与素材

做视频请使用 `assets/frames/` 内的 40 张独立透明 PNG（640×640），每个动作目录下为 `0.png`–`3.png`。已修正 7 帧因图集边界不规则而串入隔壁袖子的问题；程序也直接加载这些独立帧。`assets/interactions/` 保留原始图集供追溯，不要再次等分裁图。排查记录见 [FRAME_REPAIR.md](FRAME_REPAIR.md)。

设置及事件记录：`%LOCALAPPDATA%\WanwanShutdown`，不上传数据。

- `assets/interactions/`：十张透明 2×2 角色动作表，共 40 个独立姿态，通过 WPF 裁剪视图直接播放。
- `assets/interactions.json`：动作节奏、文案和姿态序列；`interaction-sources.json`：素材来源和生成提示。
- `assets/companion-lines.json`：N1 的 92 条原创台词、23 个场景，每个场景四种说法。
- `assets/icons/`：晚晚头像和小月亮图标，九种 ICO 分辨率；标题栏、托盘、启动快捷方式共用。
- `assets/clock-lines.json`、`assets/voices/N1-clock/`：24 小时、四阶段报时，固定 N1 参考声音；整句报时与整句提醒之间保留自然停顿。
- `app/DesktopPet.ps1`：常驻头像、气泡、当前时间语音路由、收起和打开入口。
- `app/Dialogue.ps1`：同场景轮换台词，一轮内覆盖所有说法，连续两句不重复。
- `assets/voices/`：N1 语音包（台词、报时、守护、起夜监督），附参数、时长和哈希清单。
- `output/animation/`：实际 WPF 动画抓帧和帧序号记录。
- `output/interaction-review/`：十种互动、托盘提醒及睡前窗口的实际 WPF 抓帧与验收记录。

角色动画采用关键帧序列及短淡化，目前没有骨骼动画或说话口型同步。

## 验证

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\Schedule.Tests.ps1
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File app\Main.ps1 -InteractionTest
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File app\Main.ps1 -AnimationTest
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File app\Main.ps1 -VoiceTest
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File app\Main.ps1 -CompanionTest
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File app\Main.ps1 -DialogueTest
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File app\Main.ps1 -PetTest
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File app\Main.ps1 -GuardTest
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File app\Main.ps1 -LifecycleTest
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File app\Main.ps1 -PetControlsTest
```

所有测试关闭守护，不调用关机 API。VoiceTest 验证全部台词路由、真实选择按钮、独立配置持久化及静音原生播放；不改变用户配置。AnimationTest 抓取运行中的人物动画，验证多个帧确实推进。

CompanionTest 在真实 WPF Dispatcher 中逐个点击小剧场按钮、验证十种动作各自四个姿态推进，并验证静音托盘提醒、静态模式、睡前窗口和窗口关闭后的资源清理。

PetTest 验证真实标题栏图标、托盘图标、不抢焦点的展开/收起、头像点击、打开入口、任务栏边界、午夜不向前取整、静音、静态动作、四个实际定时提醒分支、右下角最终倒计时及全部 96 段原生静音播放。测试读取真实设置后改用隔离配置，测试模式另外禁止请求关机 API。抓帧和结果保存在 `output/desktop-pet/`。

手动体验：启动后点击右下角头像，确认报时、气泡和声音；收起后在主窗口取消「桌面陪伴」，头像应消失；关闭语音再体验，文字和动作仍出现；开启「减少动态」后角色保持静态。仅在保存工作后勾选自动守护并保存，才进入真实关机流程。

真实系统关机及应用阻止关机未在开发中执行，需保存工作后验收。暂未提供周末独立计划、真人专业配音、签名安装包。

## N1 清甜温柔

用户已选定 N1。制作时固定使用同一段原创成年女性参考声音，再合成新台词。提醒、拍拍、比心、夸夸、喝水和晚安各有对应的录音；字幕显示实际播放的内容。N1 的预录称呼自然轮换“宝贝”“宝宝”“亲爱的”“我的小可爱”，自定义称呼用于系统声音。

92 条覆盖提前半小时、最后十分钟、到点、最后两分钟、收尾弹窗、演示、延期、取消、问候、约定保存、晚安及十种互动。演示台词明确说明不会关机；取消台词说明今晚已取消。

制作脚本：`tools/generate_n1_bank.py`，检测脚本：`tools/verify_n1_bank.py`；文字识别核对使用既有本地 ASR 模型。参考片段、模型 revision、实际文本、时长和文件校验值记录在 `assets/voices/N1/manifest.json`。技术检测不代表所有台词均已获得用户听审认可。

## 声音包与称呼（v0.4.0）

- `assets/voice-script.json` 由 `tools/write_voice_script.py` 从原 N1 台词生成：每句拆成「称呼」和「正文」，正文不带称呼也通顺；`addressed=true` 的 26 句在选了称呼时先播称呼。整点报时拆成称呼 + 「已经晚上十一点啦。」+ 提醒三段。
- 每个分段声音包 133 段：100 句正文、24 个整点、4 段提醒、5 个称呼。生成后用 `python tools/import_voice_bank.py V3 <生成目录>` 导入：逐条核对文字和哈希，复制 WAV 母带、编码 MP3、写 `assets/voices/V3/bank.json`。
- 运行时 `app/VoiceBank.ps1` 的 `Resolve-Speech` 按当前声音和称呼算出字幕和要播放的片段；`Say` 依次播放片段，中间停 100 ms。缺任何片段时整句交给系统朗读，绝不只播半句。
- 称呼选项：轮流叫（沿用原台词里的宝宝/宝贝/亲爱的）、五个固定称呼、不叫称呼、自定义名字。自定义名字只出现在气泡文字里；系统朗读会把名字读出来。
- N1 仍是整句录音，暂时只会按原台词轮流叫。以后可以按同样方式重录 N1。
- `tests/VoiceBank.Tests.ps1` 用假的声音包测试拼接逻辑；`-VoiceTest` 会在 Windows 上原生打开每个已安装声音包的全部片段，并检查称呼之后会接着播正文。
