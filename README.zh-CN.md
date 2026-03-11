# openspec-worktree-flow

[English](./README.md) | [简体中文](./README.zh-CN.md)

`openspec-worktree-flow` 是一个 Codex skill，用来运行一套“提案优先”的工作流，核心约束是：

- 一个需求对应一个 OpenSpec change
- 每个已批准的 change 对应一个 `codex/<change-id>` 分支
- 每个实现任务对应一个独立的同级 `git worktree`

它适合用于任何“提案先行”的开发流程。在 proposal 完成、准备进入实现的那个节点，assistant 应该主动提醒“是否现在创建 worktree”，由用户来确认是否切入。

## 它解决什么问题

团队经常会遇到这些问题：

- 多个需求共用一个分支
- proposal 还没稳定就开始写实现
- 主工作区堆积了多个需求的半成品改动
- 合并后遗留一堆 worktree 和本地分支没有清理

这个 skill 把流程统一成：

1. 在主工作区创建 proposal
2. proposal 批准后再开始实现
3. 在已批准的需求进入实现前，先确认是否迁入独立分支和 worktree
4. 合并后统一清理

## 命令

这个 skill 暴露的是一个脚本：

```bash
openspec_worktree.sh
```

支持的命令有：

- `init`：初始化一个 OpenSpec change
- `status`：查看某个 change 当前的 proposal / branch / worktree 状态
- `start`：创建实现分支和 worktree
- `list`：列出当前仓库的 worktree
- `cleanup`：清理 worktree，并可选删除分支

## 安装到 Codex

### 方式一：复制到 Codex skills 目录

把这个仓库安装到：

```bash
$HOME/.codex/skills/openspec-worktree-flow
```

如果仓库已经在本地，可以直接执行：

```bash
bash scripts/install_to_codex_home.sh
```

如果要覆盖已有安装：

```bash
bash scripts/install_to_codex_home.sh --force
```

安装或更新后，重启 Codex。

### 方式二：直接从本地仓库运行脚本

如果你只是想先试用工作流，而不想先安装到 Codex：

```bash
export OWF="$(pwd)/scripts/openspec_worktree.sh"
```

## 标准工作流

先设置脚本路径：

```bash
export CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
export OWF="$CODEX_HOME/skills/openspec-worktree-flow/scripts/openspec_worktree.sh"
```

### 1. 在主工作区创建 proposal

```bash
"$OWF" init add-rrweb-recording --capability recording --title "rrweb recording MVP" --with-design
```

这会创建：

- `openspec/changes/add-rrweb-recording/proposal.md`
- `openspec/changes/add-rrweb-recording/tasks.md`
- `openspec/changes/add-rrweb-recording/design.md`
- `openspec/changes/add-rrweb-recording/specs/recording/spec.md`

### 2. 查看状态

```bash
"$OWF" status add-rrweb-recording
```

如果你不确定 proposal 是否已经建好，或者 worktree 是否已经存在，先跑一次 `status`。

### 3. proposal 批准后先确认是否切入 worktree

当 proposal 已完成、代码实现即将开始时，应先做一次确认，而不是直接创建 worktree。

示例：

```text
提案已经准备好了。现在要为 add-rrweb-recording 创建实现用 worktree 吗？
```

### 4. 用户确认后开始实现

```bash
"$OWF" start add-rrweb-recording
```

默认会创建：

- 分支：`codex/add-rrweb-recording`
- worktree：`../<repo>-add-rrweb-recording`

### 5. 在 worktree 中开发

示例：

```bash
cd ../your-repo-add-rrweb-recording
```

如果用户确认切入 worktree，那么后续实现、验证和提交都应该在这个 worktree 里完成，而不是在主工作区里进行。

### 6. 合并后清理

```bash
"$OWF" cleanup add-rrweb-recording --remove-branch
```

## 保护规则

- `init` 和 `start` 默认要求在主工作区执行，而不是在已有 linked worktree 中执行
- proposal 准备转入实现时，应先提醒用户是否现在创建 worktree
- 如果用户确认切入 worktree，后续实现不应继续停留在主工作区
- `change-id` 和 capability 名称必须是 kebab-case
- 如果目标分支已经在别的 worktree 中检出，`start` 会直接失败
- `cleanup` 不允许删除当前所在工作区
- `init` 要求仓库中存在 `openspec/`
- 即使没有 `openspec/`，`start` 仍可工作，但除非显式允许，否则会发出警告

## 仓库结构

```text
.
├── SKILL.md
├── README.md
├── README.zh-CN.md
├── agents/
│   └── openai.yaml
├── references/
│   └── workflow.md
└── scripts/
    ├── install_to_codex_home.sh
    └── openspec_worktree.sh
```

## 版本管理

- 命令行为发生变化时打 tag 发布
- 脚本参数变化应视为一个需要版本管理的接口变化
- 拉取新版本后，记得更新本地安装到 Codex 的 skill

## License

MIT，见 [LICENSE](./LICENSE)。
