# openspec-worktree-flow

[English](./README.md) | [简体中文](./README.zh-CN.md)

`openspec-worktree-flow` 现在对外提供的是 `owf` CLI。它专门服务 Codex，用来把已经批准的 OpenSpec change 平滑切换到独立 worktree 中实现。

它适合这样的团队：

- proposal / spec 仍然走 OpenSpec
- 但希望用一套独立、稳定的方式来完成“仓库初始化 + 实现切 worktree”这段流程

## 用户怎么用

用户只需要记住一个命令：

```bash
owf init
```

之后流程就是：

1. 正常走仓库里的 OpenSpec proposal 流程
2. proposal 批准
3. 用户让 Codex 开始实现
4. Codex 看到 `AGENTS.md` 里的 handoff 规则，主动问是否现在创建实现 worktree

## 安装

全局安装：

```bash
npm install -g openspec-worktree-flow
```

一次性使用：

```bash
npx openspec-worktree-flow init
```

如果是维护者，仍然可以把它安装成 Codex skill：

```bash
bash scripts/install_to_codex_home.sh --force
```

## 命令

- `owf init [repo-path]`：初始化仓库，更新 `AGENTS.md` 并创建 `.owf/migration_rules.sh`
- `owf status <change-id>`：查看 proposal / branch / worktree 状态
- `owf start <change-id>`：创建实现分支和同级 worktree
- `owf cleanup <change-id>`：清理 worktree，并可选删除分支
- `owf list`：查看当前仓库的 worktree

高级命令：

- `owf sync-agents [repo-path]`：只刷新 `AGENTS.md` 里的受管控区块
- `owf change-init <change-id> ...`：调用底层引擎创建 OpenSpec change 骨架

## 仓库初始化

每个仓库只需要跑一次：

```bash
owf init
```

它会做两件事：

- 注入或刷新 `AGENTS.md` 的 managed block，让 Codex 在实现开始前必须先处理 worktree handoff
- 创建 `.owf/migration_rules.sh`，作为仓库自己的迁移规则文件，控制哪些路径复制、哪些路径软链

默认迁移规则是：

- 复制 `openspec/`
- 软链 `node_modules/`

如果团队有自己的需要，直接修改仓库里的 `.owf/migration_rules.sh` 就行，不需要改全局安装包。

## 实现切换

当 proposal 已批准、用户开始要求实现时，Codex 应先确认是否创建 worktree。

如果当前意图是 merge、rebase、cherry-pick、cleanup、archive，或者其它收尾动作，就不要再问是否新开 worktree。

确认后执行：

```bash
owf start add-rrweb-recording
```

默认会生成：

- 分支：`codex/add-rrweb-recording`
- worktree：`../<repo>-add-rrweb-recording`

## 清理

合并完成后：

```bash
owf cleanup add-rrweb-recording --remove-branch
```

## 触发边界

只有当请求正在从 proposal 转向写代码时，才应该询问是否创建 worktree，例如：

- 开始实现这个需求
- 开始写代码
- 继续实现
- 这个已批准提案现在进入开发

如果当前请求是在做下面这些事，就不应该再询问是否新开 worktree：

- 合并实现分支
- rebase 或 cherry-pick
- 清理分支或 worktree
- 归档或关闭这个 change

## 发布

为了避免“发了 npm 但没打 git tag”，后续发布统一走内置脚本：

```bash
bash scripts/release.sh 0.1.4
```

或者：

```bash
npm run release:owf -- 0.1.4
```

这个脚本会自动完成：

- 更新 `package.json` 版本
- 执行 `npm pack --dry-run`
- 创建 release commit
- 创建 `v0.1.4` tag
- push `main` 和 tag
- 发布 npm

## 仓库结构

```text
.
├── bin/
│   └── owf.js
├── package.json
├── SKILL.md
├── agents/
│   └── openai.yaml
├── references/
│   └── workflow.md
├── templates/
│   └── agents_worktree_handoff.md
└── scripts/
    ├── install_to_codex_home.sh
    ├── migration_rules.sh
    └── openspec_worktree.sh
```

## License

MIT，见 [LICENSE](./LICENSE)。
