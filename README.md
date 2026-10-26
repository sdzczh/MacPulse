# MacPulse

macOS 菜单栏系统资源监控工具：CPU、内存、风扇、温度、GPU、网络、磁盘、电池与进程。

原生 Swift / AppKit + SwiftUI，零第三方依赖，零 root 权限，只读采样，中文界面。

当前状态：**v0.1.0 可运行**。设计取舍与探针数据见 [方案.md](方案.md)。

## 功能

**菜单栏**

- CPU 使用率、内存占用、CPU 温度、风扇转速、GPU、网络、磁盘、电池，可逐项开关
- 只显示数值，不使用图标；12px 中性色数字，无分隔线和菜单栏曲线；仅 CPU 读数加粗
- 每段使用固定宽度占位，数值跳动时不会引起菜单栏抖动
- 总宽超过 430pt 时自动折叠为 `+N`，避免挤压其他菜单栏图标
- 左键打开速览面板，面板右上角「详情」可打开独立详情窗口；右键菜单也可直接打开窗口、设置、关于与退出

**速览面板**

- CPU：总使用率、1/5/15 分钟负载、每个核心的占用柱状图
- 内存：已用/总量、App 内存、联动内存、压缩内存、缓存、空闲的分段条，内存压力与 Swap
- 散热：CPU/GPU 平均与峰值温度、热压力状态、风扇转速与调速区间
- GPU / 电池：GPU 利用率与显存；电池电量、充电状态、循环次数、健康度
- 网络 / 磁盘：实时上下行、会话累计流量、磁盘占用、读写速率
- 进程：按 CPU 排序的前 8 个进程及内存占用（仅面板或详情窗口打开时采集）

**详情窗口**

- 独立窗口，默认 1200×840，最小 960×640，可自由缩放
- 「概览 / 进程」两个分页；概览为三列卡片栅格：CPU、内存、GPU、网络、存储、温度、风扇、电池与系统
- 270° 环形表、带刻度与渐变填充的趋势图；鼠标悬停可查看该采样的数值与时间
- 「详细 / 紧凑」两种密度：详细模式展开每核占用、负载、内存结构、读写与统计行；紧凑模式收起明细
- 进程页展示全部可见进程，支持按名称或 PID 筛选，按 CPU、内存或名称排序
- 卡片使用材质背景、状态色描边与正常/注意/偏高状态标记；关闭窗口即释放视图树
- 视觉语言参考 [mac-resource-monitor](https://github.com/mikejoseph23/mac-resource-monitor)，仅使用本项目已有的采集指标

**设置**

- 采样间隔：0.5 / 1 / 2 / 5 秒
- 摄氏 / 华氏切换
- 菜单栏显示项开关
- 开机启动（`SMAppService`）
- 恢复默认设置

## 环境

- macOS 14 及以上
- Apple Silicon（已在 MacBook Pro 18,2 / M1 Max / macOS 15.6.1 验证；Intel 未适配）
- Swift 5.9+ 与 Command Line Tools，无需完整 Xcode

## 构建与运行

```bash
./scripts/run.sh          # release 构建、组装 .app 并启动
./scripts/build-app.sh    # 只生成 dist/MacPulse.app
./scripts/install.sh      # 构建并安装到 /Applications，供启动台启动
./scripts/test.sh         # 85 项逻辑与硬件自检
```

文本采样诊断（约 3.4 秒，打印 CPU、内存、风扇、温度、GPU、网络、磁盘、电池、进程）：

```bash
swift run MacPulse --probe
```

产物为 `dist/MacPulse.app`，使用 ad-hoc 签名。首次打开如被 Gatekeeper 拦截，可在「系统设置 → 隐私与安全性」中放行。

## 安装到启动台

```bash
./scripts/install.sh
```

脚本会结束正在运行的实例，把 release 版本安装到 `/Applications/MacPulse.app` 并注册到 LaunchServices。之后按 F4 或触控板四指捏合打开启动台，点击 MacPulse 即可启动；也可以把它从「其它」文件夹拖到第一页。

App 使用 `LSUIElement`，启动后没有 Dock 图标，只出现在菜单栏右侧。安装到「应用程序」后，设置里的「开机启动」才能正常注册。卸载：退出菜单栏实例后执行 `rm -rf /Applications/MacPulse.app`。若启动台暂时没显示，执行 `killall Dock` 刷新即可（不会重置启动台布局）。

## 架构

```text
Sources/
├── CSMC/                 C 桥接层：打开 AppleSMC 用户客户端、枚举/读取键
├── MacPulseCore/
│   ├── SMC.swift         Swift 封装与 flt/sp78/fpe2/ui 解码
│   ├── SensorService.swift  风扇与温度键发现、过滤、聚合
│   ├── CPUMemorySampler.swift  CPU / 内存 / Swap / 硬件信息
│   ├── IOKitSamplers.swift     GPU / 网络 / 磁盘 / 电池
│   ├── ProcessSampler.swift    libproc 进程采样
│   ├── MetricsEngine.swift     定时采样、历史环形缓冲、发布状态
│   └── Models.swift / MetricFormat.swift
├── MacPulse/
│   ├── StatusItemController.swift  菜单栏、速览面板、右键菜单
│   ├── DashboardWindowController.swift  独立详情窗口、按需加载与释放
│   ├── StatusItemRenderer.swift    自绘菜单栏（纯数值、固定宽度）
│   ├── UI/                         速览面板、设置、设计系统
│   ├── UI/Details/                 详情窗口：卡片仪表盘、趋势图、进程视图
│   └── AppSettings.swift           偏好持久化、开机启动
├── Tests/MacPulseChecks/ 无 XCTest 依赖的断言式自检
└── scripts/              打包、运行、安装到 /Applications、测试、图标生成
```

采样节奏：

- CPU、内存、网络按设置的间隔刷新，历史缓冲保留最近 300 个采样并记录时间戳（1 秒间隔约 5 分钟）
- SMC 温度/风扇：面板与详情窗口都关闭时 5 秒，任一打开时 2 秒；GPU 与磁盘 2 秒
- 电池 10 秒；进程只在面板或详情窗口打开时约 3 秒采样一次。详情页保留全部可见进程，速览面板只取 CPU 前 8 个
- 速览面板与详情窗口均按需创建，关闭即释放各自的 SwiftUI 视图树，两者都关闭后不会跟随采样刷新
- 详情窗口的折线固定绘制最近 240 个采样；时间范围由缓冲容量决定，暂不提供手动时间窗切换
- 文字宽度缓存；菜单栏只绘制数值，每秒重绘一次

在本机空闲实测（M1 Max / 默认 4 个菜单栏段 / 1 秒间隔）：约 **1.0–1.3% CPU、13–14 MB 内存、12 线程**。开启全部菜单段或缩短间隔会略有上升。

## 数据来源

| 指标 | 来源 |
| --- | --- |
| CPU 使用率、每核占用 | `host_processor_info` |
| 内存、压力、Swap | `host_statistics64`、`vm.swapusage`、`sysctlbyname` |
| 风扇、温度 | AppleSMC（`F0Ac` / `F0Mn` / `F0Mx`、`Tp*` / `Te*` / `Ts*` / `Tg*`） |
| GPU 利用率、显存 | `IOAccelerator` 的 `PerformanceStatistics` |
| 网络速率与累计流量 | `getifaddrs` + `if_data` |
| 磁盘占用、读写速率 | `URLResourceValues`、`IOBlockStorageDriver` |
| 电池 | `IOPowerSources` / `AppleSmartBattery` |
| 进程 | `libproc`（`proc_listpids` / `proc_pidinfo`） |
| 芯片、核心数、系统版本 | `sysctl`、`ProcessInfo` |

## 权限与隐私

- 不需要 root，不安装后台守护进程，不修改风扇或系统设置
- SMC 仅调用读取接口，未实现写入
- 不联网、不上报遥测、不读取文件内容
- 开机启动使用系统 `SMAppService`；App 需放在「应用程序」文件夹。ad-hoc 签名下注册可能失败，届时设置页会显示原因
- 未启用 App Sandbox（访问 AppleSMC 用户客户端需要），因此不面向 App Store 分发

## 已知限制

- 首版不支持风扇手动调速，也不提供桌面小组件
- 未提供功耗、频率（IOReport）与每核频率；详情页因此未包含参考项目的功耗、频率与 AI 存储卡片
- Intel Mac 的风扇/温度键布局不同，尚未适配
- AppleSMC 键随机型变化；读取失败或超出 1–125°C 的值会被隐藏
- 菜单栏总宽上限 430pt，超出部分以 `+N` 折叠
- 详细密度下卡片总高度超过默认窗口，需要滚动；可切换紧凑模式或放大窗口
- 进程页只读展示，不提供结束进程、分组或用户列

## 后续方向

- 风扇曲线与手动控制（需单独评估风险与权限）
- 桌面小组件、功耗与频率（IOReport）
- Intel 机型传感器映射
- 详情页时间范围切换与进程分组、结束进程（需额外权限）
