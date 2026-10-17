# Font Playground · ArkTS / ArkUI 原生版

把文字变成画面的排版实验应用。界面为原生 ArkUI 声明式 UI，没有使用 WebView。

## 工程信息

| 项目 | 值 |
| --- | --- |
| 应用模型 | Stage 模型，单 `entry` 模块 |
| 语言 / UI | ArkTS + ArkUI（声明式） |
| 目标 SDK | HarmonyOS 26.0.0（`targetSdkVersion: 26.0.0`） |
| 兼容 SDK | 6.1.1（API 24） |
| 构建工具 | hvigor 6.26.8 / DevEco Studio 26.0.0 |
| Bundle | `com.experiencejourney.fontplayground` |

## 已实现的核心闭环

1. **Explore 首页**：品牌头部、三段式导航、留白式 Hero、蓝色海报预览、横向灵感卡片。
2. **Create 创作页**：实时画布 + 编辑面板。
   - 文字输入（最多 60 字）
   - 4 个排版预设（Brutalist / Editorial / Playful / Mono Grid）
   - 字体、字号、字间距、行间距、字形倾斜度
   - 左 / 中 / 右对齐
   - 文字色、背景色（预设色板 + HSV 调色盘：色相条、饱和度/明度取色区、HEX 输入、最近颜色）
   - 点击画布文字选中；拖动移动；拖动上方圆形手柄旋转
   - 「样式」工具顶部提供「＋ 存当前风格」按钮：把当前字体、字号、颜色、间距存进风格库，命名并逐个添加特点标签
3. **Gallery 作品 / 风格库**：双标签切换。
   - 我的作品：保存作品到本机、继续编辑、下载 PNG（通过系统相册保存确认框写入相册）、删除作品（卡片左上角按钮，二次确认后同步更新本地存储）
   - 风格库：自定义风格与预设风格使用同一套卡片排版（缩略图、标签行、标题、特点、底部信息与「使用这个风格」入口一致）；点按卡片即可套用；自定义卡片左上角 ✕ 删除（二次确认）、右上角「编辑」修改名称与标签；4 款内置预设风格常驻。风格库不再放保存入口，保存统一在创作页完成。

## 关键实现

- **页面状态**：`PageKind` 枚举 + `@State currentPage`，单 `@Component` 内切换 Explore / Create / Gallery。
- **文字变换**：`translate` 控制拖动位置，`rotate` 控制旋转，`matrix4.skew` 实现字形倾斜。
- **拖动边界**：通过画布 `onAreaChange` 取得实际尺寸，按画布 ±42% 限制，与网页原型一致。
- **输入时画布不重排**：画布逻辑尺寸只按舞台宽度计算（`canvasWidth()`），舞台高度不足时由 `canvasViewScale()` 对整块画布等比缩放。键盘弹出触发 `RESIZE` 时预览只会整体变小，换行、字距、角标位置和导出结果都保持同一套版式，不会再出现字号不变、画布被压扁后文字挤成四行压住 `01 — 03` 的情况。
- **旋转手感**：根据旋转手柄相对文字中心的角度位移计算角度增量，支持已旋转状态下继续旋转。
- **数据持久化**：`GalleryStore` 将 `WorkData[]` 序列化到 `context.filesDir/font_playground_gallery.json`；`StyleStore` 将 `SavedStyle[]` 序列化到 `font_playground_styles.json`。
- **风格库**：`SavedStyle` 只保存排版配方（预设、字体、字号、字间距、行间距、倾斜、对齐、文字色、背景色）与预览样例，不保存拖动位移和旋转；套用风格时保留正在编辑的文案，并复位位移与旋转，避免旧排版把文字推出画布。表单通过第二个 `bindSheet`（挂在页面 `Stack` 上）打开，`keyboardAvoidMode: RESIZE_ONLY` 与调色盘一致；命名 20 字上限。
- **特点标签**：创建 / 编辑风格时不再要求用户手写「简洁 · 美观」格式，而是逐个添加标签（单个 8 字、最多 6 个），`SavedStyle.note` 由 `tags.join(' · ')` 自动生成；旧数据读取时按中点拆回标签，保证历史风格可继续编辑。
- **风格卡片**：自定义风格与预设风格共用 `StyleLibraryCard`，缩略图统一走 `ArtworkPreview`，只有自定义卡片额外显示删除 / 编辑入口，避免两套卡片在字号、间距、底部操作位上不一致。
- **图片导出**：`UIContext.getComponentSnapshot()` 对 `artboard` 截图 → `ImagePacker` 编码 PNG → `photoAccessHelper.showAssetsCreationDialog()` 保存到相册。
- **数据兜底**：读取历史 JSON 时对颜色、对齐、字体、数值做校验与回退；风格库还会校验名称 / 特点长度与字号、间距、行距、倾斜范围，损坏或越界数据回退到预设值。
- **配对色板**：`Typography.COLOR_PAIRS` 把 6 组固定颜色按“文字色 / 背景色”成对排列，每一列是一组对比度足够的推荐配色（如纯白 + 电蓝、墨黑 + 米色）；两行数量与列位一致，同一列上下不再是同一个颜色，两行之间用浅色竖线连出配对，右侧 HEX 值也随之对齐。
- **调色盘**：`ColorUtils` 负责 HEX ↔ HSV 转换与合法性校验。面板里的渐变取色区、色相条用 `linearGradient` + `onTouch` 计算饱和度/明度/色相；同一 `bindSheet` 内可切换“文字 / 背景”目标，调色实时写回画布，支持 HEX 输入（含 `#abc` 简写）、最近颜色与取消回滚。画布选中框按背景感知亮度自动选白色或蓝色。
- **灵感页滚动**：用 `List` + `ListItem` 承载各区块。实测 `Scroll` + `Column` 会把固定高度的子组件按剩余视口高度压缩（风格卡被压扁、标签压到示例文字上，末尾区块直接被挤没），`List` 则按内容高度排布、正常滚动。
- **Stack 子组件定位**：实测 API 26 下 Stack 子组件的 `.align()` 不生效（子组件一律居中）。风格卡、封面角标、导航图标改用 `Row` / `Column` + `Blank()` + padding 定位。风格卡内层固定 `height(202)`，避免滚动到折叠处被压缩时内部文字重排。

## 目录

```
entry/src/main/ets/
├── entryability/EntryAbility.ets      # 窗口、系统栏、浅色模式
├── model/Typography.ets               # 设计令牌、预设、字体、WorkData / SavedStyle、序列化校验
├── pages/Index.ets                    # Explore / Create / Gallery 及全部交互
└── services/
    ├── GalleryStore.ets               # 作品 JSON 读写
    ├── StyleStore.ets                 # 风格库 JSON 读写
    ├── ArtworkExporter.ets            # 截图 → PNG → 相册
    └── ColorUtils.ets                 # HEX/HSV 转换、颜色校验、亮度判断
```

## 运行

1. 用 DevEco Studio 打开本工程。
2. 连接 HarmonyOS 模拟器或真机。
3. `File > Project Structure > Signing Configs` 勾选 **Automatically generate signature**（需要登录华为账号）。
4. 运行 `entry`。

> 当前工程未配置签名。命令行构建产出的是 `entry/build/default/outputs/default/entry-default-unsigned.hap`。本机模拟器（`127.0.0.1:5555`）可用 `hdc install -r` 直接安装该未签名包；真机需要先在 DevEco 中完成自动签名。

## 验证状态

- `hvigor clean assembleHap` 构建通过（SDK 26.0.0，兼容 API 24）。
- 已在模拟器安装运行，并走查作品删除流程：角标位置、二次确认、取消不删、确认后列表即时刷新且重启后删除结果保持。
- 已在模拟器走查输入态排版：点进「文案」后画布由 1149×1437 等比缩放到 695×869，`MAKE IT DIFFERENT` 仍保持两行，未再压到底部 `01 — 03`；缩放后的拖动位移与手指一致，收起键盘后画布与文字位移都回到输入前比例。
- 已在模拟器走查调色盘：取色区点按/拖动、色相条、文字/背景目标切换、HEX 输入、最近颜色、取消回滚、完成写回画布均正常；键盘弹出时面板会收缩，取消/完成按钮保持可见。
- 已在模拟器走查风格库：创作页「存当前风格」可打开命名 / 标签表单；逐个添加标签后自动拼出「BOLD · BLUE」并在保存后显示为卡片特点；标签满 6 个自动换行、不再遮挡下方内容；保存后风格库即时出现自定义卡片。
- 已在模拟器走查风格编辑：点卡片右上角「编辑」打开同一套表单，名称与标签可改并即时刷新卡片；勾选「同时更新排版参数」后，表单预览与保存后的卡片配方（预设 / 字号 / 行距）切换为当前画布。
- 已在模拟器走查卡片与删除：自定义 / 预设卡片的关键文字与底部操作位对齐一致；删除仍走二次确认，删除后「N 个」计数与卡片列表即时刷新，删空后显示「去创作」空态并可跳回创作页；重启应用后保存、编辑与删除结果均保持。
- 旧数据兼容：删除 `tags` 字段、只保留「A · B」特点文案的历史风格，读取后会自动拆回标签并可继续编辑。
- 使用系统字体族：`serif` / `monospace` / `HarmonyOS Sans Condensed`（其中 `serif`、`monospace` 由 HarmonyOS 字体配置映射到 Noto Serif / Noto Sans Mono）。

## 后续阶段建议

- 阶段二：内置开源字体（Playfair Display / DM Mono / Archivo Black），让四种字体在任何设备上都有稳定差异；支持“更新已有作品”。
- 阶段三：导出固定 720×450 版式（`componentSnapshot.createFromBuilder`）、页面转场动画、无障碍标签完善、数据模型单元测试。
