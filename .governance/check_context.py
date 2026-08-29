import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

import session


def main() -> int:
    root = session.repo_root(Path.cwd())
    if root is None:
        print("Not inside a Git repository.")
        return 1

    try:
        session.validate_task_context(root)
    except session.GovernanceStateError as exc:
        print(f"GOVERNANCE ERROR: {exc}")
        return 2

    print("Governance context OK.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())