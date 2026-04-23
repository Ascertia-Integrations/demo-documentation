#!/usr/bin/env bash

set -euo pipefail

LOG_LEVEL="${GITBOOK_IMPORT_LOG_LEVEL:-INFO}"
ASSET_PUBLIC_PREFIX="${GITBOOK_IMPORT_ASSET_PUBLIC_PREFIX:-/img/gitbook}"
SKIP_BRANCH_VERSION_MIGRATION="${GITBOOK_IMPORT_SKIP_BRANCH_VERSION_MIGRATION:-0}"
SUPPRESS_VERSION_WARNINGS="${GITBOOK_IMPORT_SUPPRESS_VERSION_WARNINGS:-0}"

log_level_rank() {
  case "$1" in
    DEBUG) echo 10 ;;
    INFO) echo 20 ;;
    WARN) echo 30 ;;
    ERROR) echo 40 ;;
    *) echo 20 ;;
  esac
}

log() {
  local level="$1"
  shift
  if [[ "$(log_level_rank "$level")" -lt "$(log_level_rank "$LOG_LEVEL")" ]]; then
    return
  fi
  printf '[gitbook-import][%s][%s] %s\n' "$level" "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$*"
}

usage() {
  cat <<'EOF'
Usage: ./scripts/import-gitbook.sh [--force-clean] [--reset-versioned-docs] [--verbose|--quiet] <gitbook-source-dir> [target-docs-dir]
       ./scripts/import-gitbook.sh [--force-clean] [--reset-versioned-docs] [--migrate-version-branches] [--verbose|--quiet] <gitbook-source-dir> [target-docs-dir]

Imports a GitBook-style Markdown tree into the Docusaurus docs architecture used by this repo.

What it understands:
- .gitbook.yaml root/readme/summary overrides
- README.md / README.mdx landing pages
- SUMMARY.md ordering and sidebar labels
- GitBook-managed images in .gitbook/assets/
- Relative Markdown links between imported docs

Logging:
- default: INFO, WARN, ERROR
- --verbose: include DEBUG logs
- --quiet: show only WARN and ERROR

Versioned docs:
- --reset-versioned-docs: remove versions.json, versioned_docs/, and versioned_sidebars/
- recommended for first-time migrations from a starter template repo
- --migrate-version-branches: mirror source git branches matching X.Y.Z into matching target repo branches, prune stale target release branches, import docs there, and create a local commit per branch

Examples:
  ./scripts/import-gitbook.sh ../legacy-gitbook
  ./scripts/import-gitbook.sh --verbose ../legacy-gitbook
  ./scripts/import-gitbook.sh --quiet ../legacy-gitbook
  ./scripts/import-gitbook.sh --force-clean ../legacy-gitbook ./docs
  ./scripts/import-gitbook.sh --force-clean --reset-versioned-docs ../legacy-gitbook ./docs
  ./scripts/import-gitbook.sh --force-clean --reset-versioned-docs --migrate-version-branches ../legacy-gitbook ./docs
EOF
}

force_clean=0
reset_versioned_docs=0
migrate_version_branches=0
source_dir=""
target_docs_dir=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --force-clean)
      force_clean=1
      shift
      ;;
    --reset-versioned-docs)
      reset_versioned_docs=1
      shift
      ;;
    --migrate-version-branches)
      migrate_version_branches=1
      shift
      ;;
    --verbose)
      LOG_LEVEL="DEBUG"
      shift
      ;;
    --quiet)
      LOG_LEVEL="WARN"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    -*)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
    *)
      if [[ -z "$source_dir" ]]; then
        source_dir="$1"
      elif [[ -z "$target_docs_dir" ]]; then
        target_docs_dir="$1"
      else
        echo "Too many positional arguments." >&2
        usage >&2
        exit 1
      fi
      shift
      ;;
  esac
done

if [[ -z "$source_dir" ]]; then
  usage >&2
  exit 1
fi

if [[ ! -d "$source_dir" ]]; then
  echo "Source directory does not exist: $source_dir" >&2
  exit 1
fi

source_dir="$(cd "$source_dir" && pwd)"
log INFO "Resolved source directory: $source_dir"

if [[ -z "$target_docs_dir" ]]; then
  target_docs_dir="$PWD/docs"
fi

mkdir -p "$target_docs_dir"
target_docs_dir="$(cd "$target_docs_dir" && pwd)"
target_site_root="$(cd "$target_docs_dir/.." && pwd)"
versions_file="$target_site_root/versions.json"
versioned_docs_dir="$target_site_root/versioned_docs"
versioned_sidebars_dir="$target_site_root/versioned_sidebars"
target_static_gitbook_dir="${GITBOOK_IMPORT_TARGET_STATIC_GITBOOK_DIR:-$target_site_root/static/img/gitbook}"
log INFO "Resolved target docs directory: $target_docs_dir"
log INFO "Resolved site root directory: $target_site_root"
log INFO "Using log level: $LOG_LEVEL"
log INFO "Using asset public prefix: $ASSET_PUBLIC_PREFIX"

if [[ "$target_docs_dir" == "/" ]]; then
  echo "Refusing to import into /" >&2
  exit 1
fi

require_clean_git_worktree() {
  local repo_path="$1"
  if [[ -n "$(git -C "$repo_path" status --porcelain)" ]]; then
    log ERROR "Target repository has uncommitted changes; branch migration requires a clean worktree"
    log ERROR "Commit or stash changes in $repo_path, then re-run with --migrate-version-branches"
    exit 1
  fi
}

commit_branch_import_if_needed() {
  local repo_path="$1"
  local version_branch="$2"
  git -C "$repo_path" add -A -- .

  if git -C "$repo_path" diff --cached --quiet --exit-code; then
    log INFO "No branch changes to commit for $version_branch"
    return
  fi

  git -C "$repo_path" commit -m "chore(docs): import GitBook branch $version_branch"
  log INFO "Committed imported docs on target branch $version_branch"
}

discover_version_source_refs() {
  git -C "$source_dir" for-each-ref --format='%(refname)' refs/heads refs/remotes \
    | awk -F/ '
        $1 == "refs" && $2 == "heads" && $3 ~ /^[0-9]+\.[0-9]+\.[0-9]+$/ {
          print $3 "\t" $0 "\t0";
          next;
        }
        $1 == "refs" && $2 == "remotes" && $NF ~ /^[0-9]+\.[0-9]+\.[0-9]+$/ {
          print $NF "\t" $0 "\t1";
        }
      ' \
    | sort -t "$(printf '\t')" -k1,1V -k3,3n \
    | awk -F '\t' '!seen[$1]++ { print $1 "\t" $2 }'
}

discover_target_version_branches() {
  git -C "$target_site_root" for-each-ref --format='%(refname)' refs/heads refs/remotes \
    | awk -F/ '
        $1 == "refs" && $2 == "heads" && $3 ~ /^[0-9]+\.[0-9]+\.[0-9]+$/ {
          print $3 "\tlocal";
          next;
        }
        $1 == "refs" && $2 == "remotes" && $NF ~ /^[0-9]+\.[0-9]+\.[0-9]+$/ {
          print $NF "\tremote";
        }
      ' \
    | sort -t "$(printf '\t')" -k1,1V -k2,2
}

array_contains() {
  local needle="$1"
  shift
  local candidate=""
  for candidate in "$@"; do
    if [[ "$candidate" == "$needle" ]]; then
      return 0
    fi
  done
  return 1
}

prune_stale_target_version_branches() {
  local original_ref="$1"
  local stale_branch=""
  local branch_kind=""

  while IFS=$'\t' read -r stale_branch branch_kind; do
    [[ -n "$stale_branch" ]] || continue
    if array_contains "$stale_branch" "${version_branches[@]}"; then
      continue
    fi

    if [[ "$branch_kind" == "local" ]]; then
      if [[ "$original_ref" == "$stale_branch" ]]; then
        log WARN "Skipping stale target branch deletion for currently checked out branch $stale_branch"
        continue
      fi
      log INFO "Deleting stale target release branch $stale_branch"
      git -C "$target_site_root" branch -D "$stale_branch"
      continue
    fi

    log INFO "Deleting stale target remote-tracking release branch origin/$stale_branch"
    git -C "$target_site_root" branch -dr "origin/$stale_branch" >/dev/null 2>&1 || true
  done < <(discover_target_version_branches)
}

run_import_in_isolated_worktree() {
  local worktree_path="$1"
  local source_path="$2"
  local docs_path="$3"
  shift 3
  local import_args=("$@")

  GITBOOK_IMPORT_SKIP_BRANCH_VERSION_MIGRATION=1 \
  GITBOOK_IMPORT_SUPPRESS_VERSION_WARNINGS=1 \
  GITBOOK_IMPORT_LOG_LEVEL="$LOG_LEVEL" \
  bash "$0" "${import_args[@]}" "$source_path" "$docs_path"
}

if [[ "$migrate_version_branches" -eq 1 && "$SKIP_BRANCH_VERSION_MIGRATION" -eq 0 ]]; then
  if ! git -C "$source_dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    log ERROR "--migrate-version-branches requires the source directory to be a git repository"
    exit 1
  fi

  if ! git -C "$target_site_root" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    log ERROR "--migrate-version-branches requires the target site root to be a git repository"
    exit 1
  fi

  require_clean_git_worktree "$target_site_root"

  original_target_ref="$(git -C "$target_site_root" symbolic-ref --quiet --short HEAD || git -C "$target_site_root" rev-parse HEAD)"
  target_docs_rel_path="${target_docs_dir#"$target_site_root"/}"

  version_branches=()
  version_source_refs=()
  while IFS=$'\t' read -r version_branch version_source_ref; do
    [[ -n "$version_branch" ]] || continue
    version_branches+=("$version_branch")
    version_source_refs+=("$version_source_ref")
  done < <(discover_version_source_refs)

  if [[ "${#version_branches[@]}" -eq 0 ]]; then
    log WARN "No source branches matching X.Y.Z were found; skipping branch replication"
  else
    prune_stale_target_version_branches "$original_target_ref"
    log INFO "Replicating source version branches into target repository branches: ${version_branches[*]}"

    for index in "${!version_branches[@]}"; do
      version_branch="${version_branches[$index]}"
      version_source_ref="${version_source_refs[$index]}"
      log INFO "Processing source branch $version_branch from $version_source_ref"
      branch_export_dir="$(mktemp -d /tmp/gitbook-branch-export.XXXXXX)"
      branch_worktree_dir="$(mktemp -d /tmp/gitbook-target-worktree.XXXXXX)"

      git -C "$source_dir" archive "$version_source_ref" | tar -x -C "$branch_export_dir"

      if git -C "$target_site_root" show-ref --verify --quiet "refs/heads/$version_branch"; then
        git -C "$target_site_root" worktree add "$branch_worktree_dir" "$version_branch"
      else
        git -C "$target_site_root" worktree add -b "$version_branch" "$branch_worktree_dir" "$original_target_ref"
      fi

      import_branch_args=(--force-clean)
      if [[ "$reset_versioned_docs" -eq 1 ]]; then
        import_branch_args+=(--reset-versioned-docs)
      fi

      run_import_in_isolated_worktree \
        "$branch_worktree_dir" \
        "$branch_export_dir" \
        "$branch_worktree_dir/$target_docs_rel_path" \
        "${import_branch_args[@]}"

      commit_branch_import_if_needed \
        "$branch_worktree_dir" \
        "$version_branch"

      git -C "$target_site_root" worktree remove --force "$branch_worktree_dir"
      rm -rf "$branch_export_dir"
    done

    log INFO "Completed target branch replication for source version branches"
  fi

  current_import_worktree_dir="$(mktemp -d /tmp/gitbook-current-worktree.XXXXXX)"
  git -C "$target_site_root" worktree add --detach "$current_import_worktree_dir" "$original_target_ref"

  current_import_args=(--force-clean)
  if [[ "$reset_versioned_docs" -eq 1 ]]; then
    current_import_args+=(--reset-versioned-docs)
  fi

  run_import_in_isolated_worktree \
    "$current_import_worktree_dir" \
    "$source_dir" \
    "$current_import_worktree_dir/$target_docs_rel_path" \
    "${current_import_args[@]}"

  git -C "$target_site_root" worktree remove --force "$current_import_worktree_dir"
  log INFO "Imported current docs in an isolated worktree and discarded them, leaving the checked-out target branch clean"
  exit 0
fi

if find "$target_docs_dir" -mindepth 1 -maxdepth 1 | read -r _; then
  if [[ "$force_clean" -eq 1 ]]; then
    log INFO "Target docs directory is not empty; removing existing contents because --force-clean was provided"
    find "$target_docs_dir" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
  else
    echo "Target docs directory is not empty: $target_docs_dir" >&2
    echo "Re-run with --force-clean to replace its contents." >&2
    exit 1
  fi
fi

if [[ "$reset_versioned_docs" -eq 1 ]]; then
  log INFO "Removing versioned docs artifacts because --reset-versioned-docs was provided"
  rm -f "$versions_file"
  rm -rf "$versioned_docs_dir" "$versioned_sidebars_dir"
fi

if [[ -d "$target_static_gitbook_dir" ]]; then
  log INFO "Removing previously imported GitBook assets from static/img/gitbook"
  rm -rf "$target_static_gitbook_dir"
fi

log INFO "Starting GitBook import"

export GITBOOK_IMPORT_SOURCE_DIR="$source_dir"
export GITBOOK_IMPORT_TARGET_DOCS_DIR="$target_docs_dir"
export GITBOOK_IMPORT_TARGET_STATIC_GITBOOK_DIR="$target_static_gitbook_dir"
export GITBOOK_IMPORT_LOG_LEVEL="$LOG_LEVEL"
export GITBOOK_IMPORT_ASSET_PUBLIC_PREFIX="$ASSET_PUBLIC_PREFIX"

node <<'NODE'
const fs = require("fs");
const path = require("path");

const sourceDir = process.env.GITBOOK_IMPORT_SOURCE_DIR;
const targetDocsDir = process.env.GITBOOK_IMPORT_TARGET_DOCS_DIR;
const targetStaticGitbookDir = process.env.GITBOOK_IMPORT_TARGET_STATIC_GITBOOK_DIR;
const logLevel = process.env.GITBOOK_IMPORT_LOG_LEVEL || "INFO";
const assetPublicPrefix = (process.env.GITBOOK_IMPORT_ASSET_PUBLIC_PREFIX || "/img/gitbook").replace(/\/+$/, "");

if (!sourceDir || !targetDocsDir || !targetStaticGitbookDir) {
  throw new Error("Missing import environment variables.");
}

const logLevelRanks = {
  DEBUG: 10,
  INFO: 20,
  WARN: 30,
  ERROR: 40,
};

function log(level, message, details) {
  if ((logLevelRanks[level] || logLevelRanks.INFO) < (logLevelRanks[logLevel] || logLevelRanks.INFO)) {
    return;
  }
  const prefix = `[gitbook-import][${level}]`;
  if (details === undefined) {
    console.log(`${prefix} ${message}`);
    return;
  }
  console.log(`${prefix} ${message} ${JSON.stringify(details)}`);
}

function normalizePosix(value) {
  return value.split(path.sep).join("/");
}

function stripYamlScalar(value) {
  const trimmed = value.trim();
  if (
    (trimmed.startsWith('"') && trimmed.endsWith('"')) ||
    (trimmed.startsWith("'") && trimmed.endsWith("'"))
  ) {
    return trimmed.slice(1, -1);
  }
  return trimmed;
}

function parseGitBookConfig(rootDir) {
  const config = {
    root: ".",
    readme: "README.md",
    summary: "SUMMARY.md",
  };
  const configPath = path.join(rootDir, ".gitbook.yaml");
  if (!fs.existsSync(configPath)) {
    log("INFO", "No .gitbook.yaml found; using default GitBook paths", {rootDir, config});
    return config;
  }

  log("INFO", "Reading GitBook config", {configPath});
  const lines = fs.readFileSync(configPath, "utf8").split(/\r?\n/);
  let inStructure = false;
  let structureIndent = 0;

  for (const line of lines) {
    if (!line.trim() || /^\s*#/.test(line)) {
      continue;
    }

    const rootMatch = line.match(/^\s*root\s*:\s*(.+?)\s*$/);
    if (rootMatch) {
      config.root = stripYamlScalar(rootMatch[1]);
      continue;
    }

    const structureMatch = line.match(/^(\s*)structure\s*:\s*$/);
    if (structureMatch) {
      inStructure = true;
      structureIndent = structureMatch[1].length;
      continue;
    }

    if (inStructure) {
      const indent = (line.match(/^(\s*)/) || ["", ""])[1].length;
      if (indent <= structureIndent) {
        inStructure = false;
      }
    }

    if (inStructure) {
      const entryMatch = line.match(/^\s*(readme|summary)\s*:\s*(.+?)\s*$/);
      if (entryMatch) {
        config[entryMatch[1]] = stripYamlScalar(entryMatch[2]);
      }
    }
  }

  log("INFO", "Parsed GitBook config", {configPath, config});
  return config;
}

function ensureDir(dirPath) {
  fs.mkdirSync(dirPath, {recursive: true});
}

function walk(dirPath) {
  const results = [];
  for (const entry of fs.readdirSync(dirPath, {withFileTypes: true})) {
    const absolute = path.join(dirPath, entry.name);
    if (entry.isDirectory()) {
      results.push(...walk(absolute));
    } else {
      results.push(absolute);
    }
  }
  return results;
}

function isMarkdown(relPath) {
  return /\.(md|mdx|markdown)$/i.test(relPath);
}

function isExternalHref(href) {
  return /^(?:[a-z][a-z0-9+.-]*:|\/\/)/i.test(href);
}

function humanizeSlugName(name) {
  return name
    .replace(/[-_]+/g, " ")
    .replace(/\s+/g, " ")
    .trim()
    .replace(/\b\w/g, (char) => char.toUpperCase());
}

function parseFrontmatter(content) {
  if (!content.startsWith("---\n") && !content.startsWith("---\r\n")) {
    return {frontmatter: null, body: content};
  }

  const match = content.match(/^---\r?\n([\s\S]*?)\r?\n---\r?\n?/);
  if (!match) {
    return {frontmatter: null, body: content};
  }

  const frontmatter = {};
  for (const line of match[1].split(/\r?\n/)) {
    const entry = line.match(/^([A-Za-z0-9_]+):\s*(.+?)\s*$/);
    if (!entry) {
      continue;
    }
    frontmatter[entry[1]] = entry[2];
  }

  return {
    frontmatter,
    body: content.slice(match[0].length),
  };
}

function serializeFrontmatter(frontmatter, body) {
  const lines = Object.entries(frontmatter).map(([key, value]) => `${key}: ${value}`);
  return `---\n${lines.join("\n")}\n---\n\n${body.replace(/^\s+/, "")}`;
}

function quoteYamlString(value) {
  return JSON.stringify(value);
}

function renameDocRelativePath(relPath) {
  const posixPath = normalizePosix(relPath);
  const ext = path.posix.extname(posixPath);
  const dir = path.posix.dirname(posixPath);
  const base = path.posix.basename(posixPath, ext);

  if (/^README$/i.test(base)) {
    return dir === "." ? `index${ext}` : `${dir}/index${ext}`;
  }

  return posixPath;
}

function docKeyFromPath(relPath) {
  const renamed = renameDocRelativePath(relPath);
  return renamed.replace(/\.(md|mdx|markdown)$/i, "");
}

function parseMarkdownLinkTarget(rawTarget) {
  const trimmed = rawTarget.trim();
  if (!trimmed) {
    return {href: "", title: ""};
  }

  const angleMatch = trimmed.match(/^<([^>]+)>(?:\s+["']([^"']+)["'])?$/);
  if (angleMatch) {
    return {href: angleMatch[1], title: angleMatch[2] || ""};
  }

  const titleMatch = trimmed.match(/^(\S+)\s+["']([^"']+)["']$/);
  if (titleMatch) {
    return {href: titleMatch[1], title: titleMatch[2]};
  }

  return {href: trimmed, title: ""};
}

function formatDocHref(relPath) {
  const withoutExt = relPath.replace(/\.(md|mdx|markdown)$/i, "");
  if (withoutExt === "index") {
    return "./";
  }
  if (/\/index$/i.test(withoutExt)) {
    return `${withoutExt.slice(0, -"/index".length)}/`;
  }
  return withoutExt.startsWith(".") ? withoutExt : `./${withoutExt}`;
}

function formatRelativeAssetHref(relPath) {
  const normalized = normalizePosix(relPath);
  if (!normalized || normalized === ".") {
    return "./";
  }
  return normalized.startsWith(".") ? normalized : `./${normalized}`;
}

function isWithinDir(parentDir, childPath) {
  const relative = path.relative(parentDir, childPath);
  return relative === "" || (!relative.startsWith("..") && !path.isAbsolute(relative));
}

function mapGitBookAssetAbsolutePath(assetAbsolutePath, gitBookAssetsDir) {
  const relativeAssetPath = normalizePosix(path.relative(gitBookAssetsDir, assetAbsolutePath));
  return `${assetPublicPrefix}/${relativeAssetPath}`;
}

function extractGitBookAssetRelativePath(rawPath) {
  const normalized = normalizePosix(rawPath);
  const marker = ".gitbook/assets/";
  const index = normalized.indexOf(marker);
  if (index === -1) {
    return null;
  }
  return normalized.slice(index + marker.length);
}

function shouldSkipSourcePath(relPath) {
  const normalized = normalizePosix(relPath);
  if (!normalized || normalized === ".") {
    return false;
  }

  const segments = normalized.split("/");
  for (const segment of segments) {
    if (!segment || segment === ".") {
      continue;
    }
    if (segment.startsWith(".")) {
      return true;
    }
  }

  return false;
}

function resolveSourceTargetAbsolute(rawPath, sourceAbsolutePath) {
  if (rawPath.startsWith("/")) {
    return path.resolve(sourceDir, `.${rawPath}`);
  }
  return path.resolve(path.dirname(sourceAbsolutePath), rawPath);
}

function rewriteMarkdownLinks(content, sourceRelPath, sourceAbsolutePath, destRelPath, gitBookAssetsDir) {
  const destDirPosix = path.posix.dirname(normalizePosix(destRelPath));
  const rewrites = [];

  const rewritten = content.replace(/(!?\[[^\]]*\]\()([^)]+)(\))/g, (full, prefix, rawTarget, suffix) => {
    const parsed = parseMarkdownLinkTarget(rawTarget);
    if (!parsed.href || isExternalHref(parsed.href) || parsed.href.startsWith("#")) {
      return full;
    }

    const [rawPath, rawHash = ""] = parsed.href.split("#", 2);
    if (!rawPath) {
      return full;
    }

    let nextHref = null;
    const gitBookAssetRelativePath = extractGitBookAssetRelativePath(rawPath);

    if (gitBookAssetRelativePath) {
      nextHref = `${assetPublicPrefix}/${gitBookAssetRelativePath}`;
    } else {
      const sourceTargetAbsolutePath = resolveSourceTargetAbsolute(rawPath, sourceAbsolutePath);
      if (isWithinDir(docsRoot, sourceTargetAbsolutePath) && /\.(md|mdx|markdown)$/i.test(rawPath)) {
        const resolvedSourceTarget = normalizePosix(path.relative(docsRoot, sourceTargetAbsolutePath));
        const resolvedDestTarget = renameDocRelativePath(resolvedSourceTarget);
        const relativeDestTarget = normalizePosix(path.posix.relative(destDirPosix === "." ? "" : destDirPosix, resolvedDestTarget));
        nextHref = formatDocHref(relativeDestTarget || "index.md");
      } else if (gitBookAssetsDir && isWithinDir(gitBookAssetsDir, sourceTargetAbsolutePath)) {
        nextHref = mapGitBookAssetAbsolutePath(sourceTargetAbsolutePath, gitBookAssetsDir);
      } else {
        return full;
      }
    }

    if (rawHash) {
      nextHref += `#${rawHash}`;
    }

    if (parsed.title) {
      nextHref += ` "${parsed.title}"`;
    }

    if (nextHref !== rawTarget.trim()) {
      rewrites.push({from: rawTarget.trim(), to: nextHref});
    }

    return `${prefix}${nextHref}${suffix}`;
  });

  return {content: rewritten, rewrites};
}

function rewriteHtmlAssetReferences(content, sourceAbsolutePath, destRelPath, gitBookAssetsDir) {
  const destDirPosix = path.posix.dirname(normalizePosix(destRelPath));
  const rewrites = [];

  const rewritten = content.replace(/(<(?:img|source)\b[^>]*\bsrc=)(["'])([^"']+)\2/gi, (full, prefix, quote, rawPath) => {
    if (!rawPath || isExternalHref(rawPath) || rawPath.startsWith("#")) {
      return full;
    }

    const [pathPart, rawHash = ""] = rawPath.split("#", 2);
    const gitBookAssetRelativePath = extractGitBookAssetRelativePath(pathPart);
    let nextHref = null;

    if (gitBookAssetRelativePath) {
      nextHref = `${assetPublicPrefix}/${gitBookAssetRelativePath}`;
    } else {
      const sourceTargetAbsolutePath = resolveSourceTargetAbsolute(pathPart, sourceAbsolutePath);
      if (!(gitBookAssetsDir && isWithinDir(gitBookAssetsDir, sourceTargetAbsolutePath))) {
        return full;
      }

      nextHref = mapGitBookAssetAbsolutePath(sourceTargetAbsolutePath, gitBookAssetsDir);
    }

    if (rawHash) {
      nextHref += `#${rawHash}`;
    }

    rewrites.push({from: rawPath, to: nextHref, kind: "html-asset"});
    return `${prefix}${quote}${nextHref}${quote}`;
  });

  return {content: rewritten, rewrites};
}

function normalizeMdxHtml(content) {
  const rewrites = [];
  const voidTags = ["img", "source", "br", "hr", "input", "meta", "link"];
  let rewritten = content;

  for (const tagName of voidTags) {
    const pattern = new RegExp(`<${tagName}(\\b[^>]*?)(?<!/)>(?!</${tagName}>)`, "gi");
    rewritten = rewritten.replace(pattern, (full, attributes) => {
      rewrites.push({kind: "void-tag", tag: tagName});
      return `<${tagName}${attributes} />`;
    });
  }

  return {content: rewritten, rewrites};
}

function rewriteStandaloneHref(rawPath, sourceAbsolutePath, destRelPath, gitBookAssetsDir) {
  const destDirPosix = path.posix.dirname(normalizePosix(destRelPath));
  const gitBookAssetRelativePath = extractGitBookAssetRelativePath(rawPath);

  if (gitBookAssetRelativePath) {
    return `${assetPublicPrefix}/${gitBookAssetRelativePath}`;
  }

  if (/\.(md|mdx|markdown)$/i.test(rawPath)) {
    const sourceTargetAbsolutePath = resolveSourceTargetAbsolute(rawPath, sourceAbsolutePath);
    if (!isWithinDir(docsRoot, sourceTargetAbsolutePath)) {
      return rawPath;
    }

    const resolvedSourceTarget = normalizePosix(path.relative(docsRoot, sourceTargetAbsolutePath));
    const resolvedDestTarget = renameDocRelativePath(resolvedSourceTarget);
    const relativeDestTarget = normalizePosix(
      path.posix.relative(destDirPosix === "." ? "" : destDirPosix, resolvedDestTarget),
    );
    return formatDocHref(relativeDestTarget || "index.md");
  }

  return rawPath;
}

function mapHintStyleToAdmonition(style) {
  switch ((style || "").toLowerCase()) {
    case "success":
      return "tip";
    case "danger":
      return "danger";
    case "warning":
      return "warning";
    case "info":
    default:
      return "info";
  }
}

function deriveContentRefLabel(body, url) {
  const linkMatch = body.match(/\[([^\]]+)\]\(([^)]+)\)/);
  if (linkMatch) {
    return linkMatch[1].trim();
  }

  const normalized = url.replace(/\/+$/, "");
  const lastSegment = normalized.split("/").filter(Boolean).pop() || normalized;
  return humanizeSlugName(lastSegment || "Link");
}

function rewriteGitBookBlocks(content, sourceAbsolutePath, destRelPath, gitBookAssetsDir) {
  const rewrites = [];

  let rewritten = content.replace(
    /\{\%\s*hint\s+style="([^"]+)"\s*\%\}\s*\n?([\s\S]*?)\n?\{\%\s*endhint\s*\%\}/g,
    (full, style, body) => {
      const admonition = mapHintStyleToAdmonition(style);
      rewrites.push({kind: "hint", from: style, to: admonition});
      return `:::${admonition}\n${body.trim()}\n:::`;
    },
  );

  rewritten = rewritten.replace(
    /\{\%\s*content-ref\s+url="([^"]+)"\s*\%\}\s*\n?([\s\S]*?)\n?\{\%\s*endcontent-ref\s*\%\}/g,
    (full, url, body) => {
      const trimmedUrl = url.trim();
      const label = deriveContentRefLabel(body.trim(), trimmedUrl);
      const nextHref = rewriteStandaloneHref(trimmedUrl, sourceAbsolutePath, destRelPath, gitBookAssetsDir);
      rewrites.push({kind: "content-ref", from: trimmedUrl, to: nextHref, label});
      return `[${label}](${nextHref})`;
    },
  );

  return {content: rewritten, rewrites};
}

function parseSummary(summaryPath) {
  const docs = new Map();
  const categories = new Map();
  if (!summaryPath || !fs.existsSync(summaryPath)) {
    log("WARN", "SUMMARY.md not found; sidebar metadata will be inferred from filenames only", {
      summaryPath,
    });
    return {docs, categories};
  }

  log("INFO", "Parsing SUMMARY.md for sidebar metadata", {summaryPath});
  const counters = new Map();
  const nextPosition = (container) => {
    const key = container || "";
    const next = (counters.get(key) || 0) + 1;
    counters.set(key, next);
    return next;
  };

  const lines = fs.readFileSync(summaryPath, "utf8").split(/\r?\n/);
  for (const line of lines) {
    const match = line.match(/^\s*[*+-]\s+\[([^\]]+)\]\((.+)\)\s*$/);
    if (!match) {
      continue;
    }

    const label = match[1].trim();
    const parsed = parseMarkdownLinkTarget(match[2]);
    const href = parsed.href.trim();
    if (!href || isExternalHref(href)) {
      if (href) {
        log("DEBUG", "Skipping external SUMMARY entry", {href, label});
      }
      continue;
    }

    const cleanHref = href.split("#", 1)[0].replace(/^\.\//, "");
    if (!/\.(md|mdx|markdown)$/i.test(cleanHref)) {
      log("DEBUG", "Skipping non-markdown SUMMARY entry", {href, label});
      continue;
    }

    const docKey = docKeyFromPath(cleanHref);
    const baseName = path.posix.basename(cleanHref);

    if (/^README\.(md|mdx|markdown)$/i.test(baseName)) {
      const categoryDir = path.posix.dirname(cleanHref);
      if (categoryDir !== ".") {
        const categoryKey = normalizePosix(categoryDir);
        const parentContainer = path.posix.dirname(categoryKey);
        categories.set(categoryKey, {
          label: parsed.title || label,
          position: nextPosition(parentContainer === "." ? "" : parentContainer),
        });
        log("DEBUG", "Registered category metadata from SUMMARY entry", {
          categoryKey,
          label: parsed.title || label,
        });
        docs.set(docKey, {
          sidebar_label: parsed.title || label,
          sidebar_position: nextPosition(categoryKey),
        });
      } else {
        docs.set(docKey, {
          sidebar_label: parsed.title || label,
          sidebar_position: nextPosition(""),
        });
      }
      continue;
    }

    const docContainer = path.posix.dirname(docKey);
    docs.set(docKey, {
      sidebar_label: parsed.title || label,
      sidebar_position: nextPosition(docContainer === "." ? "" : docContainer),
    });
    log("DEBUG", "Registered doc metadata from SUMMARY entry", {
      docKey,
      sidebar_label: parsed.title || label,
      sidebar_position: docs.get(docKey).sidebar_position,
    });
  }

  log("INFO", "Parsed SUMMARY metadata", {
    docs: docs.size,
    categories: categories.size,
  });
  return {docs, categories};
}

function mergeFrontmatter(content, fields) {
  const parsed = parseFrontmatter(content);
  const frontmatter = parsed.frontmatter || {};
  const applied = {};
  const skipped = {};

  for (const [key, value] of Object.entries(fields)) {
    if (value === undefined || value === null) {
      continue;
    }
    if (frontmatter[key] !== undefined) {
      skipped[key] = frontmatter[key];
      continue;
    }
    frontmatter[key] = typeof value === "string" && !/^["'].*["']$/.test(value) ? quoteYamlString(value) : value;
    applied[key] = frontmatter[key];
  }

  if (!Object.keys(frontmatter).length) {
    return {content, applied, skipped, hadFrontmatter: false};
  }

  return {
    content: serializeFrontmatter(frontmatter, parsed.body),
    applied,
    skipped,
    hadFrontmatter: Boolean(parsed.frontmatter),
  };
}

const gitBookConfig = parseGitBookConfig(sourceDir);
const docsRoot = path.resolve(sourceDir, gitBookConfig.root || ".");
const summaryAbsolute = path.resolve(docsRoot, gitBookConfig.summary || "SUMMARY.md");
const gitBookAssetsDir = path.resolve(sourceDir, ".gitbook/assets");

if (!fs.existsSync(docsRoot)) {
  throw new Error(`GitBook root does not exist: ${docsRoot}`);
}

log("INFO", "Resolved import inputs", {
  sourceDir,
  targetDocsDir,
  docsRoot,
  summaryAbsolute,
  gitBookAssetsDir,
  gitBookConfig,
});

const summaryMeta = parseSummary(summaryAbsolute);
const allFiles = walk(docsRoot);
const generatedCategories = new Set();

let importedDocs = 0;
let importedAssets = 0;
let skippedFiles = 0;
let totalLinkRewrites = 0;

log("INFO", "Discovered files under GitBook docs root", {
  docsRoot,
  files: allFiles.length,
});

for (const absolutePath of allFiles) {
  const relPath = normalizePosix(path.relative(docsRoot, absolutePath));
  if (!relPath || relPath === ".") {
    continue;
  }
  if (relPath === ".gitbook/assets" || relPath.startsWith(".gitbook/assets/")) {
    skippedFiles += 1;
    log("DEBUG", "Skipping GitBook-managed asset in main import pass", {relPath});
    continue;
  }
  if (shouldSkipSourcePath(relPath)) {
    skippedFiles += 1;
    log("DEBUG", "Skipping hidden or system path", {relPath});
    continue;
  }
  if (absolutePath === summaryAbsolute || path.basename(absolutePath) === "book.json") {
    skippedFiles += 1;
    log("DEBUG", "Skipping control file", {relPath});
    continue;
  }

  const destinationRelPath = isMarkdown(relPath) ? renameDocRelativePath(relPath) : relPath;
  const destinationAbsolutePath = path.join(targetDocsDir, destinationRelPath);
  ensureDir(path.dirname(destinationAbsolutePath));

  if (!isMarkdown(relPath)) {
    fs.copyFileSync(absolutePath, destinationAbsolutePath);
    importedAssets += 1;
    log("DEBUG", "Copied asset", {
      source: relPath,
      destination: destinationRelPath,
    });
    continue;
  }

  let content = fs.readFileSync(absolutePath, "utf8");
  const rewriteResult = rewriteMarkdownLinks(
    content,
    relPath,
    absolutePath,
    destinationRelPath,
    fs.existsSync(gitBookAssetsDir) ? gitBookAssetsDir : null,
  );
  content = rewriteResult.content;
  const htmlRewriteResult = rewriteHtmlAssetReferences(
    content,
    absolutePath,
    destinationRelPath,
    fs.existsSync(gitBookAssetsDir) ? gitBookAssetsDir : null,
  );
  content = htmlRewriteResult.content;
  const blockRewriteResult = rewriteGitBookBlocks(
    content,
    absolutePath,
    destinationRelPath,
    fs.existsSync(gitBookAssetsDir) ? gitBookAssetsDir : null,
  );
  content = blockRewriteResult.content;
  const mdxHtmlNormalizationResult = normalizeMdxHtml(content);
  content = mdxHtmlNormalizationResult.content;
  totalLinkRewrites +=
    rewriteResult.rewrites.length +
    htmlRewriteResult.rewrites.length +
    blockRewriteResult.rewrites.length +
    mdxHtmlNormalizationResult.rewrites.length;

  const docKey = docKeyFromPath(relPath);
  const fields = {...(summaryMeta.docs.get(docKey) || {})};
  if (destinationRelPath === "index.md" || destinationRelPath === "index.mdx" || destinationRelPath === "index.markdown") {
    fields.slug = "/";
  }
  const mergeResult = mergeFrontmatter(content, fields);
  content = mergeResult.content;
  fs.writeFileSync(destinationAbsolutePath, content);
  importedDocs += 1;
  log("INFO", "Imported document", {
    source: relPath,
    destination: destinationRelPath,
    docKey,
    rewrites: [
      ...rewriteResult.rewrites,
      ...htmlRewriteResult.rewrites,
      ...blockRewriteResult.rewrites,
      ...mdxHtmlNormalizationResult.rewrites,
    ],
    appliedFrontmatter: mergeResult.applied,
    skippedFrontmatter: mergeResult.skipped,
  });

  const directoryRelPath = normalizePosix(path.posix.dirname(destinationRelPath));
  if (directoryRelPath !== ".") {
    const categoryKey = directoryRelPath;
    if (!generatedCategories.has(categoryKey)) {
      const categoryMeta = summaryMeta.categories.get(categoryKey) || {};
      const categoryJson = {
        label: categoryMeta.label || humanizeSlugName(path.posix.basename(categoryKey)),
      };
      if (categoryMeta.position !== undefined) {
        categoryJson.position = categoryMeta.position;
      }
      fs.writeFileSync(
        path.join(targetDocsDir, categoryKey, "_category_.json"),
        `${JSON.stringify(categoryJson, null, 2)}\n`,
      );
      generatedCategories.add(categoryKey);
      log("INFO", "Generated category metadata", {
        categoryKey,
        categoryJson,
      });
    }
  }
}

if (fs.existsSync(gitBookAssetsDir)) {
  const gitBookAssetFiles = walk(gitBookAssetsDir);
  log("INFO", "Copying GitBook-managed assets", {
    gitBookAssetsDir,
    targetStaticGitbookDir,
    files: gitBookAssetFiles.length,
  });

  for (const absolutePath of gitBookAssetFiles) {
    const relativeAssetPath = normalizePosix(path.relative(gitBookAssetsDir, absolutePath));
    const destinationAbsolutePath = path.join(targetStaticGitbookDir, relativeAssetPath);
    ensureDir(path.dirname(destinationAbsolutePath));
    fs.copyFileSync(absolutePath, destinationAbsolutePath);
    importedAssets += 1;
    log("DEBUG", "Copied GitBook asset", {
      source: normalizePosix(path.relative(sourceDir, absolutePath)),
      destination: normalizePosix(path.relative(targetDocsDir, destinationAbsolutePath)),
    });
  }
} else {
  log("INFO", "No GitBook-managed asset directory found", {gitBookAssetsDir});
}

log("INFO", "Import complete", {
  importedDocs,
  importedAssets,
  skippedFiles,
  generatedCategories: generatedCategories.size,
  totalLinkRewrites,
  docsRoot,
  targetDocsDir,
});
NODE

if [[ "$reset_versioned_docs" -eq 0 && "$SUPPRESS_VERSION_WARNINGS" -eq 0 ]]; then
  lingering_versioned_artifacts=0
  if [[ -f "$versions_file" ]]; then
    lingering_versioned_artifacts=1
  elif [[ -d "$versioned_docs_dir" ]] && find "$versioned_docs_dir" -mindepth 1 -print -quit | grep -q .; then
    lingering_versioned_artifacts=1
  elif [[ -d "$versioned_sidebars_dir" ]] && find "$versioned_sidebars_dir" -mindepth 1 -print -quit | grep -q .; then
    lingering_versioned_artifacts=1
  fi

  if [[ "$lingering_versioned_artifacts" -eq 1 ]]; then
    log WARN "Versioned docs artifacts still exist. The site may continue to show stale starter or release content."
    log WARN "Re-run with --reset-versioned-docs to remove versions.json, versioned_docs/, and versioned_sidebars/ before importing."
  fi
fi
