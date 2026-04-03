# Noctalia Plugins

这个仓库已经整理成可被 Noctalia 直接识别的第三方插件源。

## 当前包含

- `run-command-bar`
- `cava-visualizer`

## 发布到 Gitee 后如何导入

1. 先把这个仓库推送到你的 Gitee 仓库。
2. 在 Noctalia 打开「设置 -> 插件 -> Sources」。
3. 添加一个自定义插件源：
   - 名称：随便填，比如 `My Noctalia Plugins`
   - URL：你的 Gitee 仓库克隆地址，例如 `https://gitee.com/<your-name>/<repo-name>.git`
4. 回到「Available」页刷新插件列表。
5. 现在这两个插件就会像正常插件源一样被搜索、安装和导入，不需要手动 `git clone` 后再复制目录。

## 这个仓库为什么现在能直接导入

Noctalia 会先从仓库根目录读取 `registry.json`，再按里面登记的插件 ID 去稀疏拉取对应目录。

所以发布时请保持下面这个结构：

```text
.
├── registry.json
├── run-command-bar/
└── cava-visualizer/
```

## 维护提示

- 新增插件时，除了创建插件目录，还要把插件信息加入根目录 `registry.json`
- 更新插件版本时，建议同步更新对应目录里的 `manifest.json` 和根目录 `registry.json`
