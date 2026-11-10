# PNG 素材工作流 v1

本轮已经实际执行「固定画风 → 描述 → 两张候选 → 视觉识别与文生图编辑 → 切片调用 → 运行验证」，并非将旧 SVG 转存为 PNG。

## 0. 固定画风

`assets/art/prompts/style.txt` 是所有后续素材共享的风格前缀：模拟像素、废土地铁、深蓝/青绿/赭黄限色、硬边轮廓、左上光源、透明背景。角色体积、装备、脚底基线与视角在动画帧间保持一致。运行时采用最近邻过滤，不把低分辨率 PNG 平滑放大。

## 1. 描述物品及功能

`assets/art/prompts/atlas_description.txt` 描述全部物品和动画组；`assets/art/manifest.json` 保存稳定 ID、语义描述、行列、帧数、锚点、尺寸、帧率和输出路径。`tools/prepare_art_manifest.py` 维护该表并生成 Godot 的资源清单。

四向角色各四帧，四种小怪与 Boss 各四帧。商品、双方子弹、宝箱、家具、车头、徽记、地板与合金各有独立槽位。总计 45 个逻辑资源、72 个运行 PNG 文件。

## 2. 文生图产生 2–3 个候选

为了同批风格一致，一张图集同时包含所有资源；**每个资源在 A、B 两张独立生成的图集中都有一个候选**，不是只生成两件物品。完整提示词保存在 `prompt_a.txt`、`prompt_b.txt`，对应原始候选为 `assets/art/candidates/atlas_a.png`、`atlas_b.png`。

图像生成使用会话中的 `image_gen` 文生图工具。CI 不联网生成新美术，也不假装可以通过本地脚本复现随机图像。后续新增素材时，先补语义描述，再复用风格前缀生成 2–3 张候选；可用已选图集作为风格参照。

## 3. 识别、编辑与功能导入

已逐张视觉检查两张候选。选择 B 的原因：角色四方向身份与背包更一致，物品之间轮廓差异更清楚，工业守卫与敌人色彩统一。A 保留用于对照。

使用图像编辑工具，以 B 为参考，修订透明边缘、槽位间距和姿态一致性。编辑提示词是 `prompt_edit.txt`；结果是 `assets/art/sources/subway_atlas_v1.png`。原图和候选不被切片工具覆盖。

`tools/import_art.gd` 只做技术导入：8×9 等分切片、清除低 alpha 杂边、同动画组统一缩放、脚底锚点归一，以及最近邻缩放至 64×64（Boss 96×96）。它不程序绘制替代文生图的角色。

```sh
python3 tools/prepare_art_manifest.py
godot --headless --path . --script tools/import_art.gd
godot --headless --editor --import --quit
```

游戏只通过 `scripts/art_library.gd` 获取 `Texture2D`，例如 `Art.texture("player/2", frame)`、`Art.texture("items/4_0")`。修改画风只需替换 PNG 或清单，战斗逻辑不依赖 `.svg`、原图尺寸或图集行列。静态物品沿用 `Catalog.item(id).icon` 接口，但路径由资源清单提供。

## 4. 验证

`tests/art_and_map_checks.gd` 检查 72 张 PNG 的导入、尺寸、透明边距、非空轮廓、帧独立性、脚底基线、动画计时和唯一文件映射；原流程测试验证移动、射击、主动道具、药物、背包及房间切换仍然可用。

```sh
bash tools/test.sh
```

原生 Godot 窗口还会通过 `tests/capture.gd` 检查基地、战斗、商品与地图的实际渲染。截图保存在 `docs/`，最终复查记录见 `assets/art/review.json`。

## 上海主地图

主地图采用真实线路拓扑的原创 PNG 重绘，不是战斗房间生成图。`assets/maps/shanghai_metro.json` 是可编辑数据源，覆盖 21 条运营线路、110 个主要站点，分支使用独立路径。官方地图、线路列表、客流报告与开通资料入口保存在 `assets/maps/sources.json`。官方图片直链曾返回 503，因此使用已发布地图与站序数据交叉核对后重绘，未将无法下载的图片冒称为已使用素材。

`tools/build_metro.py` 生成 PNG 与 Godot 常量表（重绘 PNG 需 Pillow，仅为开发依赖）。运行时支持筛线、选站、滚轮缩放、右键拖动、路径高亮和重置视图；原始小站被折叠，坐标为示意布局，并非导航比例尺。

客流、辐射、价格与产出仍是游戏值。区域经济与掉落的后续工作单独跟踪在 `docs/tasks/balance-and-regions.md`，不与素材验收混为一项。
