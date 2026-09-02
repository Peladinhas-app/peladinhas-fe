import importlib.util
import sys
from pathlib import Path


def load_session():
    """Load the governance session helper from this directory."""
    path = Path(__file__).with_name("session.py")
    specification = importlib.util.spec_from_file_location("governance_session", path)
    if specification is None or specification.loader is None:
        raise RuntimeError("Cannot load governance session helper")
    module = importlib.util.module_from_spec(specification)
    sys.modules[specification.name] = module
    specification.loader.exec_module(module)
    return module


def main() -> int:
    """Validate the current checkout and print a short result."""
    session = load_session()
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
