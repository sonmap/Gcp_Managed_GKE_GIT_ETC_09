#!/usr/bin/env python3
import json
import os
import sys

from google.oauth2 import service_account
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError

SCOPES = [
    "https://www.googleapis.com/auth/admin.directory.group",
    "https://www.googleapis.com/auth/admin.directory.group.member",
]


def main() -> int:
    if len(sys.argv) != 2:
        raise SystemExit("usage: group_upsert.py APPROVED_REQUEST_JSON")
    with open(sys.argv[1], encoding="utf-8") as stream:
        request = json.load(stream)

    credentials = service_account.Credentials.from_service_account_info(
        json.loads(os.environ["GOOGLE_WORKSPACE_DWD_KEY"]), scopes=SCOPES
    ).with_subject(os.environ["GOOGLE_WORKSPACE_ADMIN_SUBJECT"])
    directory = build("admin", "directory_v1", credentials=credentials, cache_discovery=False)
    group_email = request["identity"]["group_email"]
    approved_members = set(request["identity"]["members"])

    try:
        group = directory.groups().get(groupKey=group_email).execute()
    except HttpError as error:
        if error.resp.status != 404:
            raise
        group = directory.groups().insert(
            body={
                "email": group_email,
                "name": f"GCP DEV Sandbox {request['task']['name']}",
                "description": f"Managed sandbox group for {request['task']['display_name']}",
            }
        ).execute()

    existing = {}
    page_token = None
    while True:
        response = directory.members().list(groupKey=group["id"], pageToken=page_token).execute()
        for member in response.get("members", []):
            existing[member["email"].lower()] = member
        page_token = response.get("nextPageToken")
        if not page_token:
            break

    for email in sorted(approved_members):
        if email.lower() not in existing:
            directory.members().insert(
                groupKey=group["id"], body={"email": email, "role": "MEMBER"}
            ).execute()

    for email, member in existing.items():
        if member.get("role") == "MEMBER" and email not in {value.lower() for value in approved_members}:
            directory.members().delete(groupKey=group["id"], memberKey=member["id"]).execute()

    print(json.dumps({"group_id": group["id"], "group_email": group_email, "members": sorted(approved_members)}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
