#!/usr/bin/env node

const { spawnSync } = require("child_process");
const packageJson = require("../package.json");
const path = require("path");

const engineScript = path.join(__dirname, "..", "scripts", "openspec_worktree.sh");
const argv = process.argv.slice(2);

const usage = `Usage:
  owf init [repo-path] [--allow-missing-openspec] [--force-rules]
  owf status <change-id>
  owf start <change-id> [--base <branch-or-ref>] [--worktree-dir <path>] [--allow-missing-change] [--allow-linked-worktree] [--no-snapshot]
  owf cleanup <change-id> [--worktree-dir <path>] [--remove-branch] [--force]
  owf list

Advanced:
  owf sync-agents [repo-path] [--allow-missing-openspec]
  owf change-init <change-id> --capability <capability> [--title <title>] [--with-design] [--allow-linked-worktree]

Options:
  -h, --help      Show this help message
  -V, --version   Show the current owf version
`;

function printUsage(exitCode = 0) {
  process.stdout.write(`${usage}\n`);
  process.exit(exitCode);
}

function printVersion() {
  process.stdout.write(`${packageJson.version}\n`);
  process.exit(0);
}

function mapCommand(args) {
  if (args.length === 0) {
    printUsage(0);
  }

  const [command, ...rest] = args;

  switch (command) {
    case "init":
      return ["repo-init", ...rest];
    case "status":
    case "start":
    case "cleanup":
    case "list":
    case "sync-agents":
      return [command, ...rest];
    case "change-init":
      return ["init", ...rest];
    case "version":
    case "--version":
    case "-V":
      printVersion();
      break;
    case "help":
    case "--help":
    case "-h":
      printUsage(0);
      break;
    default:
      process.stderr.write(`Unknown command: ${command}\n\n`);
      printUsage(1);
  }
}

const mappedArgs = mapCommand(argv);
const result = spawnSync("bash", [engineScript, ...mappedArgs], {
  stdio: "inherit",
});

if (result.error) {
  process.stderr.write(`${result.error.message}\n`);
  process.exit(1);
}

process.exit(result.status === null ? 1 : result.status);
