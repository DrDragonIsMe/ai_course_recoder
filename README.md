# Record Courses — MacBook 录课工具

一款为 macOS 设计的桌面录课应用，支持屏幕录制、摄像头画中画、麦克风收音、实时标注与多种画面布局/叠加层，适合制作软件演示、在线课程与教程视频。

## 功能特性

- **屏幕录制**：基于 ScreenCaptureKit 捕获指定显示器内容。
- **摄像头画中画（PIP）**：可开关、调整位置与大小，支持多种布局预设。
- **麦克风收音**：可选是否录制系统麦克风。
- **实时标注**：录制时通过悬浮工具栏进行画笔、箭头、矩形、圆形、橡皮擦标注。
- **布局预设**：全屏、角落 PIP、主讲人居左/居右、软件演示等多种一键布局。
- **画面叠加层**：
  - 水印（Logo / 讲师名）
  - 光标高亮与点击涟漪
  - 按键显示
  - 放大镜
  - 步骤标注
  - 字幕（支持导入 SRT，含双语模式）
  - 章节进度条
- **快捷键**：开始/停止录制、切换标注工具与颜色等快捷操作。
- **输出格式**：支持 `.mov` / `.mp4`。

## 系统要求

- macOS 13.0+
- Apple Silicon 或 Intel Mac
- Xcode 16+（开发/构建）

## 权限说明

首次启动应用时会尝试申请以下权限。缺少任一权限时，主界面顶部会显示提示条并可直接跳转系统设置：

- **屏幕录制**：录制屏幕画面必需。
- **摄像头**：启用摄像头画中画时必需。
- **麦克风**：录制旁白/解说时必需。
- **辅助功能 / 按键监听**：按键叠加层需要监听全局键盘事件（系统会再次提示授权）。

> 若未开启对应权限，相关功能会被禁用或无法生效。

## 构建与运行

```bash
# 克隆仓库后，在项目根目录执行
xcodebuild -project RecordCourses.xcodeproj -scheme RecordCourses -destination 'platform=macOS' build

# 运行测试
xcodebuild -project RecordCourses.xcodeproj -scheme RecordCourses -destination 'platform=macOS' test
```

也可直接用 Xcode 打开 `RecordCourses.xcodeproj`，选择 `RecordCourses` scheme 后点击 Run。

## 项目结构

```
RecordCourses/
├── App/                # 应用入口
├── Core/               # 录制管线、视频合成、叠加层渲染器
├── Models/             # 布局、配置、标注模型
├── Services/           # 屏幕/摄像头/音频捕获、光标/按键追踪、字幕解析
├── UI/                 # SwiftUI 界面
├── Utilities/          # 颜色、像素缓冲区、CGContext 扩展等
├── ViewModels/         # 视图模型
└── Info.plist

RecordCoursesTests/     # Swift Testing 单元测试
```

## 常用快捷键

| 快捷键 | 作用 |
|--------|------|
| `⌘⇧A` | 切换标注绘制模式 |
| `⌘⇧S` | 停止录制 |
| `1 ~ 5` | 切换标注工具：画笔 / 箭头 / 矩形 / 圆形 / 橡皮擦 |
| `R/O/Y/G/B/P/W/K` | 切换标注颜色 |

> 标注快捷键仅在开始录制并进入标注模式后生效。

## 输出文件

录制完成后，视频默认保存到 `~/Movies/RecordCourse-YYYYMMDD-HHMMSS.<mov|mp4>`。保存目录与格式可在主界面「输出」区域设置。

## 详细操作说明

请参阅 [`docs/user-guide.md`](docs/user-guide.md)。

## 测试

项目使用 Swift Testing 编写测试，覆盖核心模块：

- 布局预设与区域计算
- SRT 字幕解析与时间选择
- 章节进度条渲染
- 放大镜渲染

运行测试：

```bash
xcodebuild -project RecordCourses.xcodeproj -scheme RecordCourses -destination 'platform=macOS' test
```

## 许可证

MIT
