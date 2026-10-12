#!/usr/bin/env python3
"""Validation script for custom Odoo addons in flexerp_addons.

Checks:
1. Manifest validity (__manifest__.py is a valid dict with required keys).
2. XML integrity (all XML views, data, and security files are well-formed).
3. Security access file integrity (ir.model.access.csv has valid columns).
"""

import ast
import csv
import os
import sys
import xml.etree.ElementTree as ET


def validate_addons(addons_dir: str = "flexerp_addons") -> int:
    if not os.path.exists(addons_dir):
        print(f"Directory '{addons_dir}' does not exist.")
        return 1

    errors = []
    checked_addons = 0

    for root, dirs, files in os.walk(addons_dir):
        # 1. Manifest Validation
        if "__manifest__.py" in files:
            checked_addons += 1
            manifest_path = os.path.join(root, "__manifest__.py")
            try:
                with open(manifest_path, "r", encoding="utf-8") as f:
                    manifest_data = ast.literal_eval(f.read())
                if not isinstance(manifest_data, dict):
                    errors.append(f"[MANIFEST] {manifest_path}: Manifest must be a dict")
                for key in ["name", "version", "depends"]:
                    if key not in manifest_data:
                        errors.append(f"[MANIFEST] {manifest_path}: Missing '{key}' key")
            except Exception as exc:
                errors.append(f"[MANIFEST] {manifest_path}: Parse error: {exc}")

        # 2. XML Validation
        for f in files:
            if f.endswith(".xml"):
                xml_path = os.path.join(root, f)
                try:
                    ET.parse(xml_path)
                except Exception as exc:
                    errors.append(f"[XML] {xml_path}: Invalid XML: {exc}")

        # 3. Security CSV Validation
        if "ir.model.access.csv" in files:
            csv_path = os.path.join(root, "ir.model.access.csv")
            try:
                with open(csv_path, "r", encoding="utf-8") as f:
                    reader = csv.reader(f)
                    header = next(reader, None)
                    expected_header = ["id", "name", "model_id:id", "group_id:id", "perm_read", "perm_write", "perm_create", "perm_unlink"]
                    if not header or header != expected_header:
                        errors.append(f"[CSV] {csv_path}: Header does not match standard ir.model.access.csv format: {header}")
            except Exception as exc:
                errors.append(f"[CSV] {csv_path}: CSV error: {exc}")

    if errors:
        print(f"Validation failed with {len(errors)} error(s):")
        for err in errors:
            print(f"  ✗ {err}")
        return 1

    print(f"✓ Successfully validated {checked_addons} addon module(s) and all XML/CSV resources in '{addons_dir}'.")
    return 0


if __name__ == "__main__":
    sys.exit(validate_addons())
