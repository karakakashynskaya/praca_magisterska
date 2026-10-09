# ref country data
from client import get, save_json, already_fetched


def fetch_reference_data():
    for subdir, path in [
        ("reference", "/countries"),
        ("reference", "/court"),
        ("reference", "/round"),
        ("reference", "/ranking"),
    ]:
        name = path.strip("/")
        if already_fetched(subdir, name):
            print(f"skip (już jest): {subdir}/{name}")
            continue
        data = get(path)
        save_json(subdir, name, data)
        print(f"zapisano: {subdir}/{name}")


if __name__ == "__main__":
    fetch_reference_data()