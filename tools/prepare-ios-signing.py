"""Validate an App Store profile and configure only the Runner target for CI."""
import datetime
import os
import pathlib
import plistlib
import re


def prepare(profile, team, project, export_path):
    bundle = "com.medyma.immortalwrtApp"
    entitlements = profile.get("Entitlements", {})
    if profile.get("TeamIdentifier") != [team]:
        raise ValueError("Provisioning profile team does not match IOS_TEAM_ID")
    if entitlements.get("application-identifier") != f"{team}.{bundle}":
        raise ValueError("Provisioning profile must match the app bundle ID exactly")
    if (entitlements.get("get-task-allow") is not False
            or "ProvisionedDevices" in profile or profile.get("ProvisionsAllDevices")):
        raise ValueError("An App Store distribution profile is required")
    expiry = profile.get("ExpirationDate")
    if not isinstance(expiry, datetime.datetime) or expiry <= datetime.datetime.now(datetime.timezone.utc).replace(tzinfo=None):
        raise ValueError("Provisioning profile has expired")
    uuid = profile.get("UUID", "")
    if not re.fullmatch(r"[A-Fa-f0-9-]{36}", uuid) or not re.fullmatch(r"[A-Z0-9]{10}", team):
        raise ValueError("Invalid profile UUID or team ID")
    source = project.read_text(encoding="utf-8")
    pattern = r"(\bbuildSettings = \{)([^{}]*?PRODUCT_BUNDLE_IDENTIFIER = " + re.escape(bundle) + r";[^{}]*?)(\};)"

    def replace(match):
        settings = re.sub(r"\n\s*(DEVELOPMENT_TEAM|CODE_SIGN_STYLE|CODE_SIGN_IDENTITY|PROVISIONING_PROFILE_SPECIFIER) = [^;]*;", "", match[2])
        return (match[1] + settings + f'\n\t\t\t\tDEVELOPMENT_TEAM = {team};\n'
                '\t\t\t\tCODE_SIGN_STYLE = Manual;\n'
                '\t\t\t\tCODE_SIGN_IDENTITY = "Apple Distribution";\n'
                f'\t\t\t\tPROVISIONING_PROFILE_SPECIFIER = "{uuid}";\n\t\t\t' + match[3])

    updated, count = re.subn(pattern, replace, source)
    if count != 3:
        raise ValueError("Expected exactly three Runner signing configurations")
    project.write_text(updated, encoding="utf-8")
    export_path.write_bytes(plistlib.dumps({
        "method": "app-store-connect", "teamID": team, "signingStyle": "manual",
        "signingCertificate": "Apple Distribution", "manageAppVersionAndBuildNumber": False,
        "provisioningProfiles": {bundle: uuid}, "uploadSymbols": True,
    }))


if __name__ == "__main__":
    prepare(plistlib.loads(pathlib.Path(os.environ["PROFILE_PLIST"]).read_bytes()),
            os.environ["IOS_TEAM_ID"], pathlib.Path("ios/Runner.xcodeproj/project.pbxproj"),
            pathlib.Path(os.environ["EXPORT_OPTIONS"]))
