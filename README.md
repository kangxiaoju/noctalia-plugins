# Noctalia Plugins

这是我的 Noctalia 插件仓库，目前包含两个插件。

所有插件均由 AI 辅助或直接编写，我本人并不懂 QML / Noctalia 插件开发这门语言与生态，主要是基于自己的需求提出想法，再由 AI 帮我实现、调整和补完。

## 当前包含

- `command-output-bar`
- `cava-visualizer`

## 插件说明

- `command-output-bar`
  用于在 Noctalia 栏中执行 shell 命令，并把标准输出直接显示在栏上。
- `cava-visualizer`
  基于 `cava` 的音频频谱栏插件。

## Cava 插件来源

`cava-visualizer` 来自这个项目：

`https://github.com/jialuo999/noctalia-cava-visualiser-plugin`

我在这个仓库里收录和整理它，方便和其它自用插件一起维护。

## Command Output Bar 工作原理

`command-output-bar` 的核心思路很简单：

1. 插件在任务栏里按配置生成多个 slot。
2. 每个 slot 都会读取自己的命令、刷新间隔、shell 路径、文本长度和颜色设置。
3. 插件通过 QML 里的 `Process` 调用对应 shell 执行命令。
4. 命令的 `stdout` 会被读取并显示到任务栏上。
5. 如果命令执行失败且有 `stderr` 输出，则优先显示错误内容。
6. 当文本过长时，插件会根据设置选择截断显示或跑马灯滚动。
7. 如果给 slot 配置了点击命令，点击对应文本区域时会额外执行一次该命令。

也就是说，这个插件本质上是一个“把 shell 命令结果实时映射到 Noctalia 栏”的外壳，适合显示时间、播放器状态、系统信息或任意自定义脚本输出。

## 仓库结构

为了让 Noctalia 识别这个仓库中的插件，根目录保留了如下结构：

```text
.
├── registry.json
├── command-output-bar/
└── cava-visualizer/
```
